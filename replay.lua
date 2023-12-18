local logger = require("logger")
local fileUtils = require("FileUtils")
local GameModes = require("GameModes")
local ReplayV1 = require("replayV1")
local ReplayV2 = require("replayV2")

local REPLAY_VERSION = 2

-- A replay is a particular recording of a play of the game. Temporarily this is just helper methods.
Replay =
class(
    function(self)
    end
  )

function Replay.createNewReplay(match)
  local result = {}
  result.engineVersion = VERSION
  result.replayVersion = REPLAY_VERSION
  result.seed = match.seed
  result.ranked = match_type == "Ranked"
  result.stage = match.stageId
  result.gameMode = {
    stackInteraction = match.stackInteraction,
    winConditions = match.winConditions or {},
    gameOverConditions = match.gameOverConditions,
    timeLimit = match.timeLimit,
    doCountdown = match.doCountdown or true,
    puzzle = match.puzzle,
    attackEngineSettings = match.attackEngineSettings
  }

  result.players = {}
  for i = 1, #match.players do
    local player = match.players[i]
    result.players[i] = {
      name = player.name,
      wins = player.wins,
      publicId = player.publicId,
      settings = {
        characterId = player.stack.character,
        panelId = player.stack.panels_dir,
        levelData = player.stack.levelData,
        inputMethod = player.stack.inputMethod,
        allowAdjacentColors = player.stack.allowAdjacentColors
      }
    }
    if player.settings.style == GameModes.Styles.MODERN then
      result.players[i].settings.level = player.settings.level
    else
      result.players[i].settings.difficulty = player.settings.difficulty
    end
  end

  match.replay = replay

  return result
end

function Replay.replayCanBeViewed(replay)
  if replay.engineVersion > VERSION then
    -- replay is from a newer game version, we can't watch
    -- or maybe we can but there is no way to verify we can
    return false
  elseif replay.engineVersion < VERSION_MIN_VIEW then
    -- there were breaking changes since the version the replay was recorded on
    -- definitely can not watch
    return false
  else
    -- can view this one
    return true
  end
end

function Replay.loadFromPath(path)
  local replay = fileUtils.readJsonFile(path)

  if not replay then
    -- there was a problem reading the file
    return false, replay
  else
    replay.loadedFromFile = true
    if not replay.engineVersion then
      -- really really bold assumption LOL
      replay.engineVersion = "046"
    end
    if not replay.replayVersion then
      replay = ReplayV1.transform(replay)
    else
      replay = ReplayV2.transform(replay)
    end
  end

  return true, replay
end

local function addReplayStatisticsToReplay(match, replay)
  replay.duration = match:gameEndedClockTime()
  local winner = match:getWinner()
  if winner then
    replay.winner = winner.publicId or winner.playerNumber
  end

  for i = 1, #match.players do
    local stack = match.players[i].stack
    local playerTable = replay.players[i]
    playerTable.analytics = stack.analytic.data
    playerTable.analytics.score = stack.score
    if match.room_ratings and match.room_ratings[i] then
      playerTable.analytics.rating = match.room_ratings[i]
    end
  end

  return replay
end

function Replay.finalizeAndWriteReplay(extraPath, extraFilename, match, replay)
  Replay.finalizeReplay(match, replay)
  local path, filename = Replay.finalReplayFilename(extraPath, extraFilename)
  local replayJSON = json.encode(replay)
  Replay.writeReplayFile(path, filename, replayJSON)
end

function Replay.finalReplayFilename(extraPath, extraFilename)
  local now = os.date("*t", to_UTC(os.time()))
  local sep = "/"
  local path = "replays" .. sep .. "v" .. VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
  if extraPath then
    path = path .. sep .. extraPath
  end
  local filename = "v" .. VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
  if extraFilename then
    filename = filename .. "-" .. extraFilename
  end
  filename = filename .. ".json"
  logger.debug("saving replay as " .. path .. sep .. filename)
  return path, filename
end

function Replay.finalizeReplay(match, replay)
  replay = addReplayStatisticsToReplay(match, replay)
  replay.stage = current_stage
  for i = 1, #match.players do
    replay.players[i].settings.inputs = compress_input_string(table.concat(match.players[i].stack.confirmedInput))
  end
end

function Replay.finalizeAndWriteVsReplay(outcome_claim, incompleteGame, match, replay)

  incompleteGame = incompleteGame or false

  local extraPath, extraFilename = "", ""

  if match:warningOccurred() then
    extraFilename = extraFilename .. "-WARNING-OCCURRED"
  end

  if match.P2 then
    local rep_a_name, rep_b_name = match.players[1].name, match.players[2].name
    --sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
    if rep_b_name < rep_a_name then
      extraPath = rep_b_name .. "-vs-" .. rep_a_name
    else
      extraPath = rep_a_name .. "-vs-" .. rep_b_name
    end
    extraFilename = extraFilename .. rep_a_name .. "-L" .. match.P1.level .. "-vs-" .. rep_b_name .. "-L" .. match.P2.level
    if match_type and match_type ~= "" then
      extraFilename = extraFilename .. "-" .. match_type
    end
    if incompleteGame then
      extraFilename = extraFilename .. "-INCOMPLETE"
    else
      if outcome_claim == 1 or outcome_claim == 2 then
        extraFilename = extraFilename .. "-P" .. outcome_claim .. "wins"
      elseif outcome_claim == 0 then
        extraFilename = extraFilename .. "-draw"
      end
    end
  else -- vs Self
    extraPath = "Vs Self"
    extraFilename = extraFilename .. "vsSelf-" .. "L" .. match.P1.level
  end

  Replay.finalizeAndWriteReplay(extraPath, extraFilename, match, replay)
end

-- writes a replay file of the given path and filename
function Replay.writeReplayFile(path, filename, replayJSON)
  assert(path ~= nil)
  assert(filename ~= nil)
  assert(replayJSON ~= nil)
  Replay.lastPath = path
  pcall(
    function()
      love.filesystem.createDirectory(path)
      local file = love.filesystem.newFile(path .. "/" .. filename)
      file:open("w")
      file:write(replayJSON)
      file:close()
    end
  )
end

return Replay
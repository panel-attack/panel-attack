local utf8 = require("utf8Additions")
local logger = require("logger")
local GameModes = require("GameModes")
local ReplayV1 = require("replayV1")
local ReplayV2 = require("replayV2")
local Player = require("Player")

local REPLAY_VERSION = 2
local tableUtils = require("tableUtils")
local levelPresets = require("LevelPresets")
local consts = require("consts")

-- A replay is a particular recording of a play of the game. Temporarily this is just helper methods.
Replay =
class(
    function(self)
    end
  )

function Replay.createNewReplay(match)
  local battleRoom = match.battleRoom
  local result = {}
  result.engineVersion = VERSION
  result.replayVersion = REPLAY_VERSION
  result.seed = match.seed
  result.ranked = match_type == "Ranked"
  result.stage = match.stageId
  result.gameMode = {
    stackInteraction = battleRoom.mode.stackInteraction,
    winConditions = battleRoom.mode.winConditions or {},
    timeLimit = battleRoom.mode.timeLimit,
    doCountdown = battleRoom.mode.doCountdown or true
  }

  result.players = {}
  for i = 1, #battleRoom.players do
    local player = battleRoom.players[i]
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
      result.players[i].settings.speed = player.settings.speed
    end
  end

  match.replay = replay

  return result
end

function Replay.replayCanBeViewed(replay)
  if replay.engineVersion >= VERSION_MIN_VIEW and replay.engineVersion <= VERSION then
    if replay.engineVersion < consts.ENGINE_VERSIONS.LEVELDATA then
      if replay.vs then
        -- before v048 there were no non-vs replays with level recorded
        if replay.vs.P1_level == 11 or (replay.vs.P2_level and replay.vs.P2_level == 11) then
          -- if one of the players is playing on level 11, we can't view the replay
          return false
        end
      end
    end
  end

  if not replay.puzzle then
    return true
  end

  return false
end

function Replay.loadFromPath(path)
    local file, error_msg = love.filesystem.read(path)

    if file == nil then
        --print(loc("rp_browser_error_loading", error_msg))
        return false
    end

    replay = {}
    replay = json.decode(file)
    if not replay.engineVersion then
        replay.engineVersion = "046"
    end

    return true
end

local function createMatchFromReplay(replay)
  GAME.battleRoom = BattleRoom.createFromReplay(replay)
  local match = GAME.battleRoom:createMatch()

  match.isFromReplay = true
  match:setSeed(replay.seed)
  match:setStage(replay.stageId)
  match.engineVersion = replay.engineVersion
  match.replay = replay

  match:start()

  return match
end

function Replay.loadFromFile(replay)
  assert(replay ~= nil)
  if not replay.replayVersion then
    replay = ReplayV1.loadFromFile(replay)
  else
    replay = ReplayV2.loadFromFile(replay)
  end
  return createMatchFromReplay(replay)
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

function Replay.finalizeAndWriteVsReplay(battleRoom, outcome_claim, incompleteGame, match, replay)

  incompleteGame = incompleteGame or false

  local extraPath, extraFilename = "", ""

  if match:warningOccurred() then
    extraFilename = extraFilename .. "-WARNING-OCCURRED"
  end

  if battleRoom.match.P2 then
    local rep_a_name, rep_b_name = battleRoom.playerNames[1], battleRoom.playerNames[2]
    --sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
    if rep_b_name < rep_a_name then
      extraPath = rep_b_name .. "-vs-" .. rep_a_name
    else
      extraPath = rep_a_name .. "-vs-" .. rep_b_name
    end
    extraFilename = extraFilename .. rep_a_name .. "-L" .. battleRoom.match.P1.level .. "-vs-" .. rep_b_name .. "-L" .. battleRoom.match.P2.level
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
    extraFilename = extraFilename .. "vsSelf-" .. "L" .. battleRoom.match.P1.level
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
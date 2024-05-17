local logger = require("common.lib.logger")
local GameModes = require("common.engine.GameModes")
local consts = require("common.engine.consts")
require("common.lib.timezones")

-- TODO: cut down replay to the definition of the replay spec and the legacy loading
-- the legacy loaders should probably move to common
local fileUtils = require("client.src.FileUtils")
local ReplayV1 = require("client.src.replayV1")
local ReplayV2 = require("client.src.replayV2")

local REPLAY_VERSION = 2

-- A replay is a particular recording of a play of the game. Temporarily this is just helper methods.
Replay =
class(
    function(self)
    end
  )

function Replay.createNewReplay(match)
  local result = {}
  result.timestamp = to_UTC(os.time())
  result.engineVersion = match.engineVersion
  result.replayVersion = REPLAY_VERSION
  result.seed = match.seed
  result.ranked = match.ranked
  result.stageId = match.stageId
  result.gameMode = {
    stackInteraction = match.stackInteraction,
    winConditions = match.winConditions or {},
    gameOverConditions = match.gameOverConditions,
    timeLimit = match.timeLimit,
    doCountdown = match.doCountdown or true,
    puzzle = match.puzzle
  }

  result.players = {}
  for i = 1, #match.players do
    local player = match.players[i]
    result.players[i] = {
      name = player.name,
      wins = player.wins,
      publicId = player.publicId,
      settings = {
        characterId = player.settings.characterId,
        panelId = player.settings.panelId,
        levelData = player.settings.levelData,
        inputMethod = player.settings.inputMethod,
        allowAdjacentColors = player.stack.allowAdjacentColors,
        attackEngineSettings = player.settings.attackEngineSettings,
        healthSettings = player.settings.healthSettings,
      },
      human = player.human
    }
    if player.settings.style == GameModes.Styles.MODERN then
      result.players[i].settings.level = player.settings.level
    else
      result.players[i].settings.difficulty = player.settings.difficulty
    end
  end

  match.replay = result

  return result
end

function Replay.replayCanBeViewed(replay)
  if replay.engineVersion > consts.ENGINE_VERSION then
    -- replay is from a newer game version, we can't watch
    -- or maybe we can but there is no way to verify we can
    return false
  elseif replay.engineVersion < consts.VERSION_MIN_VIEW then
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
    if not replay.engineVersion then
      -- really really bold assumption; serverside replays haven't been tracking engineVersion ever
      replay.engineVersion = "046"
    end
    if not replay.replayVersion then
      replay = ReplayV1.transform(replay)
    else
      replay = ReplayV2.transform(replay)
    end
    replay.loadedFromFile = true
  end

  return true, replay
end

function Replay.addAnalyticsDataToReplay(match, replay)
  replay.duration = match.gameOverClock

  for i = 1, #match.players do
    if match.players[i].human then
      local stack = match.players[i].stack
      local playerTable = replay.players[i]
      playerTable.analytics = stack.analytic.data
      playerTable.analytics.score = stack.score
      if match.room_ratings and match.room_ratings[i] then
        playerTable.analytics.rating = match.room_ratings[i]
      end
    end
  end

  return replay
end

function Replay.finalizeAndWriteReplay(extraPath, extraFilename, replay)
  if replay.incomplete then
    extraFilename = extraFilename .. "-INCOMPLETE"
  end
  local path, filename = Replay.finalReplayFilename(extraPath, extraFilename)
  local replayJSON = json.encode(replay)
  Replay.writeReplayFile(path, filename, replayJSON)
end

function Replay.finalReplayFilename(extraPath, extraFilename)
  local now = os.date("*t", to_UTC(os.time()))
  local sep = "/"
  local path = "replays" .. sep .. "v" .. consts.ENGINE_VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
  if extraPath then
    path = path .. sep .. extraPath
  end
  local filename = "v" .. consts.ENGINE_VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
  if extraFilename then
    filename = filename .. "-" .. extraFilename
  end
  filename = filename .. ".json"
  logger.debug("saving replay as " .. path .. sep .. filename)
  return path, filename
end

function Replay.finalizeReplay(match, replay)
  replay = Replay.addAnalyticsDataToReplay(match, replay)
  replay.stageId = match.stageId
  for i = 1, #match.players do
    if match.players[i].stack.confirmedInput then
      replay.players[i].settings.inputs = compress_input_string(table.concat(match.players[i].stack.confirmedInput))
    end
  end
  replay.incomplete = match.aborted
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
      love.filesystem.write(path .. "/" .. filename, replayJSON)
    end
  )
end

return Replay
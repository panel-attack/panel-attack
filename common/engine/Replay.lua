local logger = require("common.lib.logger")
local GameModes = require("common.engine.GameModes")
local consts = require("common.engine.consts")
local utf8 = require("common.lib.utf8Additions")
local class = require("common.lib.class")
require("common.lib.timezones")
local tableUtils = require("common.lib.tableUtils")

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

function Replay.load(jsonData)
  local replay
  if not jsonData then
    -- there was a problem reading the file
    return false, nil
  else
    if not jsonData.engineVersion then
      -- really really bold assumption; serverside replays haven't been tracking engineVersion ever
      jsonData.engineVersion = "046"
    end
    if not jsonData.replayVersion then
      replay = require("common.engine.replayV1").transform(jsonData)
    else
      replay = require("common.engine.replayV2").transform(jsonData)
    end
    replay.loadedFromFile = true
  end

  return true, replay
end

function Replay.addAnalyticsDataToReplay(match, replay)
  replay.duration = match.clock

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
  if not replay.loadedFromFile then
    replay = Replay.addAnalyticsDataToReplay(match, replay)
    replay.stageId = match.stageId
    for i = 1, #match.players do
      if match.players[i].stack.confirmedInput then
        replay.players[i].settings.inputs = Replay.compressInputString(table.concat(match.players[i].stack.confirmedInput))
      end
    end
    replay.incomplete = match.aborted

    if #match.winners == 1 then
      -- ideally this would be public player id
      replay.winnerIndex = tableUtils.indexOf(match.players, match.winners[1])
    end
  end
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

-- Returns if the unicode codepoint (representative number) is either the left or right parenthesis
local function codePointIsParenthesis(codePoint)
  if codePoint >= 40 and codePoint <= 41 then
    return true
  end
  return false
end

-- Returns if the unicode codepoint (representative number) is a digit from 0-9
local function codePointIsDigit(codePoint)
  if codePoint >= 48 and codePoint <= 57 then
    return true
  end
  return false
end

function Replay.compressInputString(inputs)
  assert(inputs ~= nil, "string must be provided for compression")
  assert(type(inputs) == "string", "input to be compressed must be a string")
  if string.len(inputs) == 0 then
    return inputs
  end
  
  local compressedTable = {}
  local function addToTable(codePoint, repeatCount)
    local currentInput = utf8.char(codePoint)
    -- write the input
    if tonumber(currentInput) == nil then
      compressedTable[#compressedTable+1] = currentInput .. repeatCount
    else
      local completeInput = "(" .. currentInput
      for j = 2, repeatCount do
        completeInput = completeInput .. currentInput
      end
      compressedTable[#compressedTable+1] = completeInput .. ")"
    end
  end

  local previousCodePoint = nil
  local repeatCount = 1
  for p, codePoint in utf8.codes(inputs) do
    if codePointIsDigit(codePoint) and codePointIsParenthesis(previousCodePoint) == true then
      -- Detected a digit enclosed in parentheses in the inputs, the inputs are already compressed.
      return inputs
    end
    if p > 1 then
      if previousCodePoint ~= codePoint then
        addToTable(previousCodePoint, repeatCount)
        repeatCount = 1
      else
        repeatCount = repeatCount + 1
      end
    end
    previousCodePoint = codePoint
  end
  -- add the final entry without having to check for table length in every iteration
  addToTable(previousCodePoint, repeatCount)

  return table.concat(compressedTable)
end

function Replay.decompressInputString(inputs)
  local previousCodePoint = nil
  local inputChunks = {}
  local numberString = nil
  local characterCodePoint = nil
  -- Go through the characters one by one, saving character and then the number sequence and after passing it writing out that many characters
  for p, codePoint in utf8.codes(inputs) do
    if p > 1 then
      if codePointIsDigit(codePoint) then 
        local number = utf8.char(codePoint)
        if numberString == nil then
          characterCodePoint = previousCodePoint
          numberString = ""
        end
        numberString = numberString .. number
      else
        if numberString ~= nil then
          if codePointIsParenthesis(characterCodePoint) then
            inputChunks[#inputChunks+1] = numberString
          else
            local character = utf8.char(characterCodePoint)
            local repeatCount = tonumber(numberString)
            inputChunks[#inputChunks+1] = string.rep(character, repeatCount)
          end
          numberString = nil
        end
        if previousCodePoint == codePoint then
          -- Detected two consecutive letters or symbols in the inputs, the inputs are not compressed.
          return inputs
        else
          -- Nothing to do yet
        end
      end
    end
    previousCodePoint = codePoint
  end

  local result
  if numberString ~= nil then
    local character = utf8.char(characterCodePoint)
    local repeatCount = tonumber(numberString)
    inputChunks[#inputChunks+1] = string.rep(character, repeatCount)
    result = table.concat(inputChunks)
  else
    -- We never encountered a single number, this string wasn't compressed
    result = inputs
  end
  return result
end

return Replay
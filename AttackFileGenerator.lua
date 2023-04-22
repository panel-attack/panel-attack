local logger = require("logger")
local separator = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

-- Helper debug functions for analyzing a set of replays and outputting attack files from them.

local function finishedMatchForPath(path)
  logger.info("Processing " .. path)
  pcall(
    function()
      io.stdout:flush()
    end
  )

  GAME.muteSoundEffects = true

  Replay.loadFromPath(path)
  Replay.loadFromFile(replay)

  assert(GAME ~= nil)
  assert(GAME.match ~= nil)

  if GAME.match.P1 and GAME.match.P2 then
    local match = GAME.match
    local matchOutcome = match.battleRoom:matchOutcome()
    local lastClock = -1
    while matchOutcome == nil and lastClock ~= match.P1.clock do
      lastClock = match.P1.clock
      match:run()
      matchOutcome = match.battleRoom:matchOutcome()
    end

    reset_filters()
    stop_the_music()
    replay = {}
    GAME:clearMatch()
    return match
  end
end

local function saveStack(stack, match)
  local data, state = stack:getAttackPatternData()
  local level = stack.level
  local savePath = "dumpedAttackPatterns/" ..
      data.extraInfo.gpm ..
      "GPM" .. "-Level" .. level .. "-" .. data.extraInfo.matchLength .. "-" .. data.extraInfo.playerName .. ".json"
  savePath = savePath:gsub(":", "-"):gsub("%.", "-")
  love.filesystem.createDirectory("dumpedAttackPatterns")
  saveJSONToPath(data, state, savePath)
  --logger.info("Saved " .. savePath)
end

local function analyzeReplayPath(path)
  local match = finishedMatchForPath(path)
  if match then
    saveStack(match.P1, match)
    saveStack(match.P2, match)
  end
end

local function analyzePathRecursive(path)
  local pathContents = FileUtil.getFilteredDirectoryItems(path)

  for key, currentPath in pairs(pathContents) do
    local fullPath = path .. separator .. currentPath
    local file_info = love.filesystem.getInfo(fullPath)
    if file_info then
      if file_info.type == "file" then
        local fileExtension = FileUtil.getFileExtension(currentPath)
        if fileExtension == ".json" or fileExtension == ".txt" then
          analyzeReplayPath(fullPath)
        end
      elseif file_info.type == "directory" then
        if string.find(currentPath, "Vs Self") then
          logger.info("Skipping " .. fullPath)
        elseif string.find(currentPath, "Time Attack") then
          logger.info("Skipping " .. fullPath)
        elseif string.find(currentPath, "Endless") then
          logger.info("Skipping " .. fullPath)
        else
          logger.info("Folder " .. fullPath)
          analyzePathRecursive(fullPath)
        end
      end
    end
  end
end

analyzePathRecursive("replays/v046/2022/10")

local logger = require("common.lib.logger")
local separator = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")
local fileUtils = require("client.src.FileUtils")

-- Helper debug functions for analyzing a set of replays and outputting attack files from them.

local function finishedMatchForPath(path)
  logger.info("Processing " .. path)
  pcall(
    function()
      io.stdout:flush()
    end
  )

  GAME.muteSound = true

  local replay = Replay.load(fileUtils.readJsonFile(path))
  local match = Match.createFromReplay(replay)

  assert(match ~= nil)
  assert(match.players ~= nil)

  if #match.players > 1 then
    local lastClock = -1
    while not match:hasEnded() and lastClock ~= match.P1.clock do
      lastClock = match.P1.clock
      match:run()
    end

    SoundController:stopMusic()
    match:deinit()
    return match
  end
end

local function saveStack(stack, match)
  local data, state = stack:getAttackPatternData()
  local level = stack.level
  local savePath = "dumpedAttackPatterns/" ..
      data.extraInfo.gpm ..
      "GPM" .. "-Level" .. level .. "-" .. data.extraInfo.matchLength .. "-" .. data.extraInfo.playerName
  savePath = savePath:gsub(":", "-"):gsub("%.", "-")
  savePath = savePath .. ".json"
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
  local pathContents = fileUtils.getFilteredDirectoryItems(path)

  for key, currentPath in pairs(pathContents) do
    local fullPath = path .. separator .. currentPath
    local file_info = love.filesystem.getInfo(fullPath)
    if file_info then
      if file_info.type == "file" then
        local fileExtension = fileUtils.getFileExtension(currentPath)
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

analyzePathRecursive("replays/v047/2023/12/27")

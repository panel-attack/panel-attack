require("game_updater")
local DefaultLoveRunFunctions = require("DefaultLoveRunFunctions")

love.pa_runInternal = DefaultLoveRunFunctions.innerRun
love.run = DefaultLoveRunFunctions.run

-- CONSTANTS
local UPDATER_NAME = "panel-beta" -- you should name the distributed auto updater zip the same as this
-- use a different name for the different versions of the updater
-- ex: "panel" for the release, "panel-beta" for the main beta, "panel-exmode" for testing the EX Mode
local MAX_REQ_SIZE = 100000 -- 100kB

-- GLOBALS
GAME_UPDATER = nil
GAME_UPDATER_VERSION = 1.1 -- nil was prior to Jan 15, 2023 where we added version
GAME_UPDATER_GAME_VERSION = nil
-- determines whether the maingame should check for updates on startup separately
GAME_UPDATER_CHECK_UPDATE_INGAME = nil
-- coroutine used to keep the updater responsive
UPDATER_COROUTINE = nil

-- VARS
-- the directory in the saveDirectory where the updater with the specific UPDATER_NAME saves its version files
local updaterDirectory = nil
-- the string saved inside of /updater/UPDATER_NAME/.version
local local_version = nil
-- local variable used to hold all list of versions available on the server for UPDATER_NAME
local all_versions = nil
local gameStartVersion = nil
local updateLog = {}
local debugMode = false
local updateString = "Checking for updates"

local function logMessage(txt)
  if not love.window.isOpen() then love.window.setMode(800, 600) end
  updateLog[#updateLog+1] = txt
end

local time = nil
local announcedStart = false
local function start_game(file)
  local currentTime = love.timer.getTime()
  -- for debugging purposes
  if time == nil then
    time = currentTime
  end
  -- this delays the startup so you can actually read the messages logged by the auto updater
  if debugMode and announcedStart == false and currentTime > (time + 3) and currentTime <= (time + 5) then
    logMessage("Starting game version " .. file)
    announcedStart = true
  else
    --nothing
    if not love.filesystem.mount(updaterDirectory..file, '') then error("Could not mount game file: "..file) end
    GAME_UPDATER_GAME_VERSION = file:gsub("^panel%-", ""):gsub("%.love", "")
    package.loaded.main = nil
    package.loaded.conf = nil
    love.conf = nil
    love.init()
    love.load(args)
  end
end

local function get_embedded_version()
  for i, v in ipairs(love.filesystem.getDirectoryItems("")) do
    if v:match('%.love$') then return v end
  end
  return nil
end

local function correctAndroidStartupConfig()
  local function hasLocalInstallation()
    local saveDirectory = love.filesystem.getSaveDirectory()
    for i, v in ipairs(love.filesystem.getDirectoryItems("")) do
      -- the config file itself might still live in internal storage as that is the default setting for love
      if love.filesystem.getRealDirectory(v) == saveDirectory and v ~= "UseAndroidExternalStorage" then
        logMessage("Installation detected in " .. saveDirectory)
        logMessage("Installation indicated by file " .. v)
        return true
      end
    end
    return false
  end

  if love.system.getOS() == "Android" then
    local storageChanged = false
    if hasLocalInstallation() then
      if UseAndroidExternalStorage == true then
        logMessage("Installation in external storage detected...")
      else
        logMessage("Installation in internal storage detected...")
      -- legacy support, using the internal storage until user actively migrates
      end
    else
      if UseAndroidExternalStorage == true then
        logMessage("No installation detected, creating fresh install in external storage...")
      else
        logMessage("No internal install present, restarting in external storage")
        storageChanged = true
        UseAndroidExternalStorage = true
      end
    end
    
    pcall(
      function()
        local file = love.filesystem.newFile("UseAndroidExternalStorage")
        file:open("w")
        file:write(tostring(UseAndroidExternalStorage))
        file:close()
      end
    )

    if storageChanged == true then
      package.loaded.main = nil
      package.loaded.conf = nil
      love.conf = nil
      love.init()
      love.load()
    end
  end
end

local function cleanUpOldVersions()
  for i, v in ipairs(love.filesystem.getDirectoryItems(updaterDirectory)) do
    if v ~= local_version and v:match('%.love$') then
      love.filesystem.remove(updaterDirectory..v)
    end
  end
end

local function shouldCheckForUpdate()
  if gameStartVersion ~= nil then
    -- we already have the version we want (forcedVersion), no point in checking
    return false
  end

  if local_version == nil and get_embedded_version() == nil then
    -- if there is no local version available at all, try to fetch an update, even if auto_update is off
    return true
  end

  -- go with the auto_updater config setting
  return GAME_UPDATER.config.auto_update
end

local function getAvailableVersions()
  local downloadThread = GAME_UPDATER:async_download_available_versions(MAX_REQ_SIZE)
  logMessage("Downloading list of versions...")
  local versions = nil
  -- the download thread is guaranteed to at least return an empty table when finished
  while versions == nil do
    versions = downloadThread:pop()
    coroutine.yield()
  end

  return versions
end

local function containsForcedVersion(versions)
  if versions == nil or type(versions) ~= "table" then
    return false
  end

  for _, v in pairs(versions) do
    if GAME_UPDATER.config.force_version == v then
      return true
    end
  end

  return false
end

local function setGameStartVersion(version)
  GAME_UPDATER:change_version(version)
  gameStartVersion = version
end

local function setEmbeddedAsGameStartVersion()
  local embeddedVersion = get_embedded_version()
  love.filesystem.write(updaterDirectory..embeddedVersion, love.filesystem.read(embeddedVersion))
  setGameStartVersion(embeddedVersion)
end

local function awaitGameDownload(version)
  local downloadThread = GAME_UPDATER:async_download_file(version)
  updateString = "Downloading new version\n" .. version
  logMessage("Downloading new version " .. version .. "...")
  local channelMessage = nil
  while channelMessage == nil do
    channelMessage = downloadThread:pop()
    coroutine.yield()
  end

  return channelMessage
end

local function setFallbackVersion()
  if local_version then
    logMessage("Falling back to local version")
    setGameStartVersion(local_version)
  else
    -- there is no recent version 
    logMessage("Falling back to embedded version")
    if get_embedded_version() == nil then
      error('Could not find an embedded version of the game\nPlease connect to the internet and restart the game.')
    end
    setEmbeddedAsGameStartVersion()
  end
end

local function run()

  logMessage("Checking for versions online...")
  all_versions = getAvailableVersions()

  if GAME_UPDATER.config.force_version ~= "" then
    if containsForcedVersion(all_versions) then
      awaitGameDownload(GAME_UPDATER.config.force_version)
      setGameStartVersion(GAME_UPDATER.config.force_version)
    else
      local err = 'Could not find online version: "'..GAME_UPDATER.config.force_version..'" (force_version)\nAvailable versions are:\n'
        for _, v in pairs(all_versions) do err = err..v.."\n" end
        error(err)
    end
    -- no point looking for updates with a forced version - var is already initialized like that
    -- GAME_UPDATER_CHECK_UPDATE_INGAME = false

  else
    -- all_versions returns an empty table at minimum so no need to nil check
    if #all_versions > 0 then
      if all_versions[1] == local_version then
        logMessage("Your game is already up to date!")
        setGameStartVersion(local_version)
      elseif all_versions[1] == get_embedded_version() then
        logMessage("Your game is already up to date!")
        setEmbeddedAsGameStartVersion()
      else
        logMessage("A new version of the game has been found!")
        awaitGameDownload(all_versions[1])
        setGameStartVersion(all_versions[1])
      end
    else
      logMessage("No online version found for " .. UPDATER_NAME)
    end
    coroutine.yield()
  end
end

local function setDebugFlag(args)
  for i = 1, #args do
    if tostring(args[i]):lower() == "debug" then
      debugMode = true
    end
  end
end

function love.load(args)

  setDebugFlag(args)
  logMessage("Starting auto updater...")
  correctAndroidStartupConfig()

  -- delayed initialisation as GameUpdater already writes into storage which ruins the function above
  GAME_UPDATER = GameUpdater(UPDATER_NAME)
  GAME_UPDATER_CHECK_UPDATE_INGAME = (GAME_UPDATER.config.force_version == "")
  updaterDirectory = GAME_UPDATER.path
  local_version = GAME_UPDATER:get_version()

  cleanUpOldVersions()

  if GAME_UPDATER.config.force_version ~= "" then
    if GAME_UPDATER.config.force_version == local_version then
      -- no point updating when we already have exactly the version we want
      setGameStartVersion(local_version)
    elseif GAME_UPDATER_GAME_VERSION.config.force_version == get_embedded_version() then
      setEmbeddedAsGameStartVersion()
    end
  end

  if shouldCheckForUpdate() then
    UPDATER_COROUTINE = coroutine.create(run)
  else
    logMessage("Not checking online versions as either a forced version is used or auto_update is disabled")
  end
end

function love.update(dt)
  if UPDATER_COROUTINE ~= nil and coroutine.status(UPDATER_COROUTINE) ~= "dead" then
    local status, err = coroutine.resume(UPDATER_COROUTINE)
    if not status then
      error(err .. "\n\n" .. debug.traceback(UPDATER_COROUTINE))
    end
  else
    if gameStartVersion == nil then
      setFallbackVersion()
    end
    start_game(gameStartVersion)
  end
end

local indicatorTimer = 0
local indicator = { false, false, false }
local width, height = love.graphics.getDimensions()
local font = love.graphics.newFont(24)
function love.draw()
  if debugMode then
    love.graphics.print("Your save directory is: " .. love.filesystem.getSaveDirectory(), 10, 10)
    for i = 1, #updateLog do
      if updateLog[i] then
        love.graphics.print(updateLog[i], 30, 60 + i * 15)
        i = i + 1
      end
    end
  else
    love.graphics.printf(updateString, font, 0, height / 2 - 12, width, "center")
  end

  -- draw an indicator to indicate that the window is alive and kicking even during a download
  indicatorTimer = indicatorTimer + 1
  if indicatorTimer % 60 == 20 then
    indicator[1] = not indicator[1]
  elseif indicatorTimer % 60 == 40 then
    indicator[2] = not indicator[2]
  elseif indicatorTimer % 60 == 0 then
    indicator[3] = not indicator[3]
  end

  if indicator[1] then
    love.graphics.print(".", font, width / 2 - 15, height * 0.75)
  end
  if indicator[2] then
    love.graphics.print(".", font, width / 2     , height * 0.75)
  end
  if indicator[3] then
    love.graphics.print(".", font, width / 2 + 15, height * 0.75)
  end
end
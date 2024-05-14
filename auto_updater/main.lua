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
-- the string saved inside of /updater/UPDATER_NAME/.version
local local_version = nil
-- local variable used to hold all list of versions available on the server for UPDATER_NAME
local all_versions = nil
local gameStartVersion = nil
local updateLog = {}
local debugMode = false
local updateString = "Checking for updates"

local loadingIndicator = require("loadingIndicator")
local bigFont = love.graphics.newFont(24)

local function logMessage(txt)
  if not love.window.isOpen() then
    love.window.setMode(800, 600)
  end
  updateLog[#updateLog+1] = txt
end

local function get_embedded_version()
  for i, v in ipairs(love.filesystem.getDirectoryItems("")) do
    if v:match('%.love$') then return v end
  end
  return nil
end

local embeddedVersion = get_embedded_version()

local function delayGameStart()
  local startTime = love.timer.getTime()
  local currentTime = startTime
  local dt = 0
  local announcedStart = false

  while currentTime - startTime < 5 do
    local loopDt = love.timer.getTime() - currentTime
    dt = dt + loopDt
    currentTime = currentTime + loopDt

    -- bit dirty but as we can't be inside of a coroutine for reboot, make our own drawloop here
    if dt >= (1/60) then
      dt = 0
      love.graphics.clear()
      love.draw()
      love.graphics.present()
      love.timer.sleep(0.01)
    end
    if not announcedStart and currentTime - startTime >= 3 then
      logMessage("Starting game version " .. gameStartVersion)
      announcedStart = true
    end
  end
end

local function reinitLove()
  if debugMode then
    delayGameStart()
  end
  package.loaded.main = nil
  package.loaded.conf = nil
  love.conf = nil
  love.init()
  -- command line args for love automatically are saved inside a global args table
  love.load(args)
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

    love.filesystem.write("UseAndroidExternalStorage", tostring(UseAndroidExternalStorage))

    if storageChanged == true then
      reinitLove()
    end
  end
end

local function cleanUpOldVersions()
  for i, v in ipairs(love.filesystem.getDirectoryItems(GAME_UPDATER.path)) do
    if v ~= local_version and v:match('%.love$') then
      love.filesystem.remove(GAME_UPDATER.path .. v)
    end
  end
end

local function shouldCheckForUpdate()
  if gameStartVersion ~= nil then
    -- we already have the version we want (forcedVersion), no point in checking
    return false
  end

  if local_version == nil and embeddedVersion == nil then
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
  gameStartVersion = version
end

local function setEmbeddedAsGameStartVersion()
  love.filesystem.write(GAME_UPDATER.path..embeddedVersion, love.filesystem.read(embeddedVersion))
  setGameStartVersion(embeddedVersion)
  return true
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
      elseif all_versions[1] == embeddedVersion then
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
  -- on android, args seems to be nil so we need to sanity check
  if args then
    for i = 1, #args do
      if tostring(args[i]):lower() == "debug" then
        debugMode = true
      end
    end
  end
end

-- mounts the game file
-- if successful it will return true and update the game version on GAME_UPDATER
-- it will also set gameStartVersion to itself
-- if unsuccessful it will return false and do nothing more
local function tryMountGame(version)
  if love.filesystem.mount(GAME_UPDATER.path .. version, '') then
    GAME_UPDATER:change_version(version)
    GAME_UPDATER_GAME_VERSION = version:gsub("^panel%-", ""):gsub("%.love", "")
    -- for logging
    gameStartVersion = version
    return true
  end
  return false
end

local function startGame()
  -- it may happen that a version cannot be mounted
  -- reason will usually be an interrupted download of a new game version,
  -- leaving the user with a bricked game file
  if gameStartVersion and tryMountGame(gameStartVersion) then
    reinitLove()
  elseif local_version and tryMountGame(local_version) then
    logMessage("Falling back to local version")
    reinitLove()
  elseif embeddedVersion and setEmbeddedAsGameStartVersion() and tryMountGame(embeddedVersion) then
    logMessage("Falling back to embedded version")
    reinitLove()
  else
    -- everything failed, there is no game file to boot with
    -- make sure to clean up all left-over bricked versions
    -- if any client could be mounted, bricked versions will get cleaned up in `load` on next startup
    -- but if nothing can get mounted, a bricked versions might remain and prevent a redownload
    local_version = nil
    cleanUpOldVersions()
    error("Could not mount a game file in the " .. UPDATER_NAME .. " auto_updater.\n" ..
          "Please try redownloading the game.")
  end
end

function love.load(args)
  loadingIndicator:setDrawPosition(love.graphics:getDimensions())
  loadingIndicator:setFont(bigFont)
  setDebugFlag(args)
  logMessage("Starting auto updater...")
  correctAndroidStartupConfig()

  -- delayed initialisation as GameUpdater already writes into storage which ruins the function above
  GAME_UPDATER = GameUpdater(UPDATER_NAME)
  GAME_UPDATER_CHECK_UPDATE_INGAME = (GAME_UPDATER.config.force_version == "")
  local_version = GAME_UPDATER:get_version()

  cleanUpOldVersions()

  if GAME_UPDATER.config.force_version ~= "" then
    if GAME_UPDATER.config.force_version == local_version then
      -- no point updating when we already have exactly the version we want
      setGameStartVersion(local_version)
    elseif GAME_UPDATER_GAME_VERSION.config.force_version == embeddedVersion then
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
    -- we cannot reboot the game proper while inside the coroutine
    startGame()
  end
end

local width, height = love.graphics.getDimensions()
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
    love.graphics.printf(updateString, bigFont, 0, height / 2 - 12, width, "center")
  end

  loadingIndicator:draw()
end
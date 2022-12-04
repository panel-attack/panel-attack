require("game_updater")

-- CONSTANTS
local UPDATER_NAME = "panel-test" -- you should name the distributed auto updater zip the same as this
-- use a different name for the different versions of the updater
-- ex: "panel" for the release, "panel-beta" for the main beta, "panel-exmode" for testing the EX Mode
local MAX_REQ_SIZE = 100000 -- 100kB

-- GLOBALS
GAME_UPDATER = nil
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
local updateLog = {}

local function logMessage(txt)
  if not love.window.isOpen() then love.window.setMode(800, 600) end
  updateLog[#updateLog+1] = txt
end

local function start_game(file)
  if not love.filesystem.mount(updaterDirectory..file, '') then error("Could not mount game file: "..file) end
  GAME_UPDATER_GAME_VERSION = file:gsub("^panel%-", ""):gsub("%.love", "")
  logMessage("Starting game version " .. file)
  for i = 1, 500 do
    coroutine.yield()
  end
  package.loaded.main = nil
  package.loaded.conf = nil
  love.conf = nil
  love.init()
  love.load(args)
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
      if love.filesystem.getRealDirectory(v) == saveDirectory and v.name ~= "UseAndroidExternalStorage" then
        return true
      end
    end
    return false
  end

  if love.system.getOS() == "Android" then
    if UseAndroidExternalStorage == false and not hasLocalInstallation() then
      logMessage("No internal install present, change to external storage")
      UseAndroidExternalStorage = true
    elseif UseAndroidExternalStorage == true and not hasLocalInstallation() then
      logMessage("No installation detected, creating fresh install in external storage...")
    elseif UseAndroidExternalStorage == true and hasLocalInstallation() then
      logMessage("Installation in external storage detected...")
    elseif UseAndroidExternalStorage == false and hasLocalInstallation() then
      logMessage("Installation in internal storage detected...")
      -- legacy support, using the internal storage until user actively migrates
    end
    
    pcall(
      function()
        local file = love.filesystem.newFile("UseAndroidExternalStorage")
        file:open("w")
        file:write(tostring(UseAndroidExternalStorage))
        file:close()
      end
    )

    if UseAndroidExternalStorage == true then
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
  return GAME_UPDATER.config.auto_update and not (
    GAME_UPDATER.check_timestamp ~= nil 
    and os.time() < GAME_UPDATER.check_timestamp + GAME_UPDATER.config.launch_check_interval 
    and local_version
    and (GAME_UPDATER.config.force_version == "" or GAME_UPDATER.config.force_version == local_version))
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

local function startEmbeddedVersion()
  local embeddedVersion = get_embedded_version()
  love.filesystem.write(updaterDirectory..embeddedVersion, love.filesystem.read(embeddedVersion))
  GAME_UPDATER:change_version(embeddedVersion)
  start_game(embeddedVersion)
end

local function awaitGameDownload(version)
  local downloadThread = GAME_UPDATER:async_download_file(version)
  logMessage("Downloading new version " .. version .. "...")
  local channelMessage = nil
  while channelMessage == nil do
    channelMessage = downloadThread:pop()
    coroutine.yield()
  end

  return channelMessage
end

local function run()
  logMessage("Starting auto updater...")
  correctAndroidStartupConfig()

  -- delayed initialisation as GameUpdater already writes into storage which ruins the function above
  GAME_UPDATER = GameUpdater(UPDATER_NAME)
  GAME_UPDATER_CHECK_UPDATE_INGAME = (GAME_UPDATER.config.force_version == "")
  updaterDirectory = GAME_UPDATER.path
  local_version = GAME_UPDATER:get_version()

  cleanUpOldVersions()

  coroutine.yield()

  if shouldCheckForUpdate() then
    logMessage("Checking for versions online...")
    all_versions = getAvailableVersions()
  end

  if GAME_UPDATER.config.force_version ~= "" then
    logMessage("You're using a special version of the auto-updater")
    logMessage("The game version is locked to " .. GAME_UPDATER.config.force_version)
    -- directly check local version as there is little point to DL if it is already present
    if GAME_UPDATER.config.force_version == local_version then
      logMessage("Correct version is already installed!")
      start_game(local_version)
    elseif GAME_UPDATER.config.force_version == get_embedded_version() then
      logMessage("Correct version is already installed!")
      startEmbeddedVersion()
    else
      if containsForcedVersion(all_versions) then
        awaitGameDownload(GAME_UPDATER.config.force_version)
        GAME_UPDATER:change_version(GAME_UPDATER.config.force_version)
        start_game(GAME_UPDATER.config.force_version)
      else
        local err = 'Could not find online version: "'..GAME_UPDATER.config.force_version..'" (force_version)\nAvailable versions are:\n'
          for _, v in pairs(all_versions) do err = err..v.."\n" end
          error(err)
      end
    end
    -- no point looking for updates with a forced version - var is already initialized like that
    -- GAME_UPDATER_CHECK_UPDATE_INGAME = false
  else
    if all_versions ~= nil and #all_versions > 0 then
      -- we already checked for updates, don't check again on main game start
      GAME_UPDATER_CHECK_UPDATE_INGAME = false
      if all_versions[1] == local_version then
        logMessage("Your game is already up to date!")
        start_game(local_version)
      elseif all_versions[1] == get_embedded_version() then
        logMessage("Your game is already up to date!")
        startEmbeddedVersion()
      else
        logMessage("A new version of the game has been found!")
        awaitGameDownload(all_versions[1])
        GAME_UPDATER:change_version(all_versions[1])
        start_game(all_versions[1])
      end
    elseif local_version then
      logMessage("Did not check or find online versions, starting the local version")
      start_game(local_version)
    else
      -- there is no recent version 
      logMessage("No online or local version found, trying to launch embedded version...")
      if get_embedded_version() == nil then
        error('Could not find an embedded version of the game\nPlease connect to the internet and restart the game.')
      end
      startEmbeddedVersion()
    end
  end
end

function love.load()
  UPDATER_COROUTINE = coroutine.create(run)
end

function love.update(dt)
  if UPDATER_COROUTINE ~= nil and coroutine.status(UPDATER_COROUTINE) ~= "dead" then
    local status, err = coroutine.resume(UPDATER_COROUTINE)
    if not status then
      error(err .. "\n\n" .. debug.traceback(UPDATER_COROUTINE))
    end
  end
end

function love.draw()
  love.graphics.print("Your save directory is: " .. love.filesystem.getSaveDirectory(), 10, 10)

  for i = 1, #updateLog do
    if updateLog[i] then
      love.graphics.print(updateLog[i], 30, 60 + i * 15)
      i = i + 1
    end
  end
end
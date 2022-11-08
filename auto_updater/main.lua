require("game_updater")

-- CONSTANTS
local UPDATER_NAME = "panel-beta" -- you should name the distributed auto updater zip the same as this
-- use a different name for the different versions of the updater
-- ex: "panel" for the release, "panel-beta" for the main beta, "panel-exmode" for testing the EX Mode
local MAX_REQ_SIZE = 100000 -- 100kB

-- GLOBALS
GAME_UPDATER = nil
GAME_UPDATER_GAME_VERSION = nil
GAME_UPDATER_CHECK_UPDATE_INGAME = nil

-- VARS
local path = nil
local local_version = nil
local top_version = nil
local messages = ""
local wait_messages = 0
local next_step = ""
local wait_all_versions = nil
local wait_download = nil

local function start_game(file)
  if not love.filesystem.mount(path..file, '') then error("Could not mount game file: "..file) end
  GAME_UPDATER_GAME_VERSION = file:gsub("^panel%-", ""):gsub("%.love", "")
  package.loaded.main = nil
  package.loaded.conf = nil
  love.conf = nil
  love.init()
  love.load(args)
end

local function display_message(txt)
  if not love.window.isOpen() then love.window.setMode(800, 600) end
  messages = messages..txt
  wait_messages = 10
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
      if love.filesystem.getRealDirectory(v) == saveDirectory then
        return true
      end
    end
    return false
  end

  if love.system.getOS() == "Android" and UseAndroidExternalStorage == false then
    if not hasLocalInstallation() then
      UseAndroidExternalStorage = true
    end
    
    pcall(
      function()
        local file = love.filesystem.newFile("UseAndroidExternalStorage")
        file:open("w")
        file:write(tostring(UseAndroidExternalStorage))
        file:close()
      end
    )

    if UseAndroidExternalStorage then
      package.loaded.conf = nil
      love.conf = nil
      love.init()
      love.load()
    end
  end
end

function love.load()
  correctAndroidStartupConfig()

  -- delayed initialisation as GameUpdater already writes into storage which ruins the function above
  GAME_UPDATER = GameUpdater(UPDATER_NAME)
  GAME_UPDATER_CHECK_UPDATE_INGAME = (GAME_UPDATER.config.force_version == "")
  path = GAME_UPDATER.path
  local_version = GAME_UPDATER:get_version()

  -- Cleanup old love files
  for i, v in ipairs(love.filesystem.getDirectoryItems(path)) do
    if v ~= local_version and v:match('%.love$') then
      love.filesystem.remove(path..v)
    end
  end
  -- should we check for an update?
  if GAME_UPDATER.config.auto_update and not (
    GAME_UPDATER.check_timestamp ~= nil 
    and os.time() < GAME_UPDATER.check_timestamp + GAME_UPDATER.config.launch_check_interval 
    and local_version
    and (GAME_UPDATER.config.force_version == "" or GAME_UPDATER.config.force_version == local_version)) then

    -- Check for a version online
    wait_all_versions = GAME_UPDATER:async_download_available_versions(MAX_REQ_SIZE)
  end

  next_step = "check_versions"
end

function love.update(dt)
  if wait_messages > 0 then
    wait_messages = wait_messages - 1
    return
  end

  local all_versions = nil
  if wait_all_versions ~= nil then
    all_versions = wait_all_versions:pop()
  end

  if next_step == "check_versions" and wait_all_versions == nil or all_versions ~= nil then
    if all_versions and #all_versions > 0 then
      top_version = nil
      if GAME_UPDATER.config.force_version ~= "" then
        for i, v in ipairs(all_versions) do
          if GAME_UPDATER.config.force_version == v then
            top_version = v
            break
          end
        end
        if top_version == nil then
          local err = 'Could not find online version: "'..GAME_UPDATER.config.force_version..'" (force_version)\nAvailable versions are:\n'
          for i, v in ipairs(all_versions) do err = err..v.."\n" end
          error(err)
        end

      else
        top_version = all_versions[1]
      end

      GAME_UPDATER_CHECK_UPDATE_INGAME = false

      if top_version == local_version then
        start_game(local_version)
      elseif local_version == nil and top_version == get_embedded_version() then
        display_message("Copying embedded version...\n")
        next_step = "copy_embedded"
      else
        display_message("A new version of the game has been found:\n"..top_version.."\nDownloading...\n")
        wait_download = GAME_UPDATER:async_download_file(top_version)
        next_step = "download_game"
      end

    -- Check for a version locally
    elseif local_version then
      if GAME_UPDATER.config.force_version ~= "" and GAME_UPDATER.config.force_version ~= local_version then
          error('Could not find local version: "'..GAME_UPDATER.config.force_version..'" (force_version)\nPlease connect to the internet and restart the game.')
      end
      start_game(local_version)

    -- Fallback use embedded version
    else
      display_message("Could not connect to the internet.\nCopying embedded version...\n")
      next_step = "copy_embedded"
      top_version = get_embedded_version()
      
      if top_version == nil then
        error('Could not find an embedded version of the game\nPlease connect to the internet and restart the game.')
      end
    end

  elseif next_step == "copy_embedded" then
    love.filesystem.write(path..top_version, love.filesystem.read(top_version))
    GAME_UPDATER:change_version(top_version)
    start_game(top_version)

  elseif next_step == "download_game" then
    local ret = wait_download:pop()
    if ret ~= nil then
      if not ret then error("Could not download and save: "..top_version) end
      GAME_UPDATER:change_version(top_version)
      start_game(top_version)
    end
  end
end

function love.draw()
  love.graphics.print(messages, 10, 10)
end
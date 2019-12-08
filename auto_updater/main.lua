local http = require("socket.http")

-- CONSTANTS
http.TIMEOUT = 1
local CHECK_INTERVAL = 0 * 60 -- * 60 to convert seconds to minutes
local UPDATER_NAME = "panel-beta" -- you should name the distributed zip the same as this 
-- use a different name for the different versions of the updater
-- ex: "panel" for the release, "panel-beta" for the main beta, "panel-exmode" for testing the EX Mode

-- PATHS
local PATH = "updater/"..UPDATER_NAME.."/"
local TIMESTAMP_FILE = PATH..".timestamp"
local VERSION_FILE = PATH..".version"

-- GLOBALS
UPDATER_GAME_VERSION = nil
local local_version = love.filesystem.read(VERSION_FILE)
local last_timestamp = love.filesystem.read(TIMESTAMP_FILE)
local top_version = nil
local copy_embedded = false
local download_game = false
local messages = ""
local wait_messages = 0
local update_steps = 1
local body

-- configure folders
if not love.filesystem.getInfo(PATH) then love.filesystem.createDirectory(PATH) end
if not love.filesystem.getInfo(PATH.."config.lua") then love.filesystem.write(PATH.."config.lua", love.filesystem.read("updater_config.lua")) end
  
-- load conf
require("updater_config")
local config = updater_config
package.loaded["updater_config"] = nil
require("updater."..UPDATER_NAME..".config")
if type(updater_config) == "table" then
	for k,v in pairs(updater_config) do
	  if type(v) == type(config[k]) then
	    config[k] = v
	  end
	end
end

function love.load()
  body = nil

  -- should we check for an update?
  if config.auto_update and not (
    last_timestamp ~= nil 
    and os.time() < last_timestamp + CHECK_INTERVAL 
    and local_version and love.filesystem.getInfo(PATH..local_version)
    and (config.force_version == "" or config.force_version == local_version)) then

    body = http.request(config.server_url)
  end

  -- Check for a version online
  if body then
    local all_versions = {}

    for w in body:gmatch('<a href="([/%w_-]+)%.love">') do
      all_versions[#all_versions+1] = w:gsub("^/[/%w_-]+/", "")
    end

    sort_versions(all_versions)
    for i=1,#all_versions do
      all_versions[i] = all_versions[i]..'.love'
    end

    top_version = nil
    if config.force_version ~= "" then
      for i, v in ipairs(all_versions) do
        if config.force_version == v then
          top_version = v
          break
        end
      end

      if top_version == nil then
        local err = 'Could not find online version: "'..config.force_version..'" (force_version)\nAvailable versions are:\n'
        for i, v in ipairs(all_versions) do err = err..v.."\n" end
        error(err)
      end

    else
      top_version = all_versions[1]
    end

    love.filesystem.write(TIMESTAMP_FILE, os.time())

    if top_version == local_version and love.filesystem.getInfo(PATH..local_version) then
      start_game(local_version)
    else
      display_message("A new version of the game has been found:\n"..top_version.."\nDowloading...\n")
      download_game = true
    end

  -- Check for a version locally
  elseif local_version and love.filesystem.getInfo(PATH..local_version) then
    if config.force_version ~= "" and config.force_version ~= local_version then
        error('Could not find local version: "'..config.force_version..'" (force_version)\nPlease connect to the internet to download it.')
    end
    start_game(local_version)

  -- Fallback use embedded version
  else
    display_message("Could not connect to the internet.\nCopying embedded version...\n")
    copy_embedded = true
    top_version = "panel.love"
  end
end


function love.update(dt)
  if wait_messages > 0 then
    wait_messages = wait_messages - 1
    return
  end

  if copy_embedded then
    love.filesystem.write(PATH..top_version, love.filesystem.read(PATH.."embedded.love"))
    change_current_version(top_version, local_version)
    start_game(top_version)

  elseif download_game then
    if update_steps == 1 then
      body = http.request(config.server_url.."/"..top_version)
      display_message("Writing to disk...\n")
      update_steps = 2
    elseif update_steps == 2 then
      love.filesystem.write(PATH..top_version, body)
      change_current_version(top_version, local_version)
      start_game(top_version)
    end
  end
end

function love.draw()
  love.graphics.print(messages, 10, 10)
end

function start_game(file)
  if not love.filesystem.mount(PATH..file, '') then error("Could not mount game file: "..file) end
  UPDATER_GAME_VERSION = file:gsub("^panel%-", ""):gsub("%.love", "")
  package.loaded.main = nil
  package.loaded.conf = nil
  love.conf = nil
  love.init()
  love.load(args)
end

function sort_versions(arr)
  table.sort(arr, function(a,b) return a>b end)
end

function change_current_version(file)
  love.filesystem.write(VERSION_FILE, file)
  if local_version and local_version ~= file and love.filesystem.getInfo(PATH..local_version) then
    love.filesystem.remove(PATH..local_version)
  end
end

function display_message(txt)
  if not love.window.isOpen() then love.window.setMode(800, 600) end
  messages = messages..txt
  wait_messages = 10
end

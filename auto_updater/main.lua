local http = require("socket.http")
http.TIMEOUT = 1
local CHECK_INTERVAL = 0 * 60 * 60 -- seconds
local PATH = "updater/"

local local_version = love.filesystem.read(PATH..".version")
local last_timestamp = love.filesystem.read(PATH..'.timestamp')
local top_version = nil
local copy_embedded = false
local downstart_game = false
local messages = ""
local wait_messages = 0
local update_steps = 1
local body

if not love.filesystem.getInfo(PATH) then love.filesystem.createDirectory(PATH) end
if not love.filesystem.getInfo(PATH.."config.lua") then love.filesystem.write(PATH.."config.lua", love.filesystem.read("updater_config.lua")) end
  
require("updater_config")
local updater_config = config
package.loaded["updater_config"] = nil
require("updater.config")

function love.load()

  if type(config) == "table" then
    for k,v in pairs(config) do
      if type(v) == type(updater_config[k]) then
        updater_config[k] = v
      end
    end
  end

  if last_timestamp ~= nil 
    and os.time() < last_timestamp + CHECK_INTERVAL 
    and local_version and love.filesystem.getInfo(PATH..local_version) 
    and updater_config.force_version ~= "" then
    start_game(local_version)
  end

  body = nil

  if updater_config.auto_update then
    body = http.request(updater_config.server_url)
  end

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
    if updater_config.force_version ~= "" then
      for i, v in ipairs(all_versions) do
        if updater_config.force_version == v then
          top_version = v
          break
        end
      end

      if top_version == nil then
        local err = "Could not find force_version on the server: '"..updater_config.force_version.."'\nAvailable versions are:\n"
        for i, v in ipairs(all_versions) do err = err..v.."\n" end
        error(err)
      end

    else
      top_version = all_versions[1]
    end

    if top_version == local_version and love.filesystem.getInfo(PATH..local_version) then
      love.filesystem.write(PATH..'.timestamp', os.time())
      start_game(local_version)
    else
      create_window()
      display_message("A new version of the game has been found:\n"..top_version.."\nDowloading...\n")
      downstart_game = true
    end

  elseif local_version and love.filesystem.getInfo(PATH..local_version) then
    if updater_config.force_version ~= "" and updater_config.force_version ~= local_version then
        error("Could not find force_version locally: '"..updater_config.force_version.."'. Please connect to the internet to download it.")
    end
    start_game(local_version)

  else
    create_window()
    display_message("Could not connect to the internet.\nCopying embedded version...\n")
    copy_embedded = true
    top_version = "panel.love"
  end
end

function start_game(file)
  if not love.filesystem.mount(PATH..file, '') then error("Could not mount game file: "..file) end
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
  love.filesystem.write(PATH..".version", file)
  if local_version and local_version ~= file and love.filesystem.getInfo(PATH..local_version) then
    love.filesystem.remove(PATH..local_version)
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

  elseif downstart_game then
    if update_steps == 1 then
      body = http.request(updater_config.server_url.."/"..top_version)
      display_message("Writing to disk...\n")
      update_steps = 2
    elseif update_steps == 2 then
      love.filesystem.write(PATH..top_version, body)
      change_current_version(top_version, local_version)
      start_game(top_version)
    end
  end

end

function create_window()
  love.window.setMode(400, 300)
end

function display_message(txt)
  messages = messages..txt
  wait_messages = 10
end

function love.draw()
  love.graphics.print(messages, 10, 10)
end
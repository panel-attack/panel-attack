local socket = require("socket")
local http = require("socket.http")
require("class")

GameUpdater = class(function(self, name)
    if not name then error("GameUpdater: you need to specify a name") end

    self.path = "updater/"..name.."/"
    if not love.filesystem.getInfo(self.path) then love.filesystem.createDirectory(self.path) end
    if not love.filesystem.getInfo(self.path.."config.lua") then love.filesystem.write(self.path.."config.lua", love.filesystem.read("_config.lua")) end

    self.name = name
    self.thread = nil
    require("_config")
    self.config = updater_config
    package.loaded["_config"] = nil
    require("updater."..name..".config")
    if type(updater_config) == "table" then
      for k,v in pairs(updater_config) do
        if type(v) == type(self.config[k]) then
          self.config[k] = v
        end
      end
    end

    self.version_file = self.path..".version"
    self.local_version = love.filesystem.read(self.version_file)

    self.has_local_version = false
    if self.local_version and love.filesystem.getInfo(self.path..self.local_version) then
      self.has_local_version = true
    end

  end)

-- returns thread channel [async returns sorted list of all versions available on the server]
function GameUpdater.async_download_available_versions(self, timeout, max_size)
  if self.thread and self.thread:isRunning() then error ("GameUpdater: a thread is already running") end
  self.thread = love.thread.newThread("game_updater_thread.lua")
  self.thread:start("download_available_versions", self.config.server_url, timeout, max_size)
  return love.thread.getChannel('download_available_versions')
end

-- returns thread channel [async returns bool download success]
function GameUpdater.async_download_file(self, filename)
  if self.thread and self.thread:isRunning() then error ("GameUpdater: a thread is already running") end
  self.thread = love.thread.newThread("game_updater_thread.lua")
  self.thread:start("download_file", self.config.server_url.."/"..filename, self.path..filename)
  return love.thread.getChannel('download_file')
end

function GameUpdater.get_version(self)
  if self.has_local_version then
    return self.local_version
  else
    return nil
  end
end

function GameUpdater.change_version(self, filename)
  if filename and love.filesystem.getInfo(self.path..filename) then
    love.filesystem.write(self.version_file, filename)
    if self.local_version and self.local_version ~= filename and love.filesystem.getInfo(self.path..self.local_version) then
      love.filesystem.remove(self.path..self.local_version)
    end
    return true
  end
  return false
end
ACTION = "READ"
DATA_LOCATION = "INTERNAL"

AndroidMigration = { eventLog = {} }

require("androidMigration.file")

function AndroidMigration.readStorage(self)
  self.filetree = {}
  self:recursiveRead("", self.filetree) -- "" refers to the root directory
  self:logEvent("Finished reading all files in " .. DATA_LOCATION .. " storage into memory")
end

function AndroidMigration.wipeStorage(self)
  --recursiveRemoveFiles("") -- "" is the root directory, enable for final testing/release
end

function AndroidMigration.writeStorage(self)
  self:recursiveWrite(self.filetree)
  self:logEvent("Finished writing all files into " .. DATA_LOCATION .. " storage from memory")
end

function AndroidMigration.validateWrite(self)
  self.action = "VALIDATE"
  self.oldFiletree = self.filetree
  self:logEvent("Confirming results of write process in " .. DATA_LOCATION .. " storage")
  self:readStorage()
  self:logEvent("Comparing write results with internal memory")
  return self:recursiveCompare(self.oldFiletree, self.filetree)
end

function AndroidMigration.reboot(self, intendedLocation, action)
  self:logEvent("Setting " .. action .. " location to " .. intendedLocation)
  DATA_LOCATION = intendedLocation
  self.updateConfig(intendedLocation)
  ACTION = action
  package.loaded.conf = nil
  love.conf = nil
  love.init()
  love.load()
end


function AndroidMigration.updateConfig(intendedLocation)
  if intendedLocation == "INTERNAL" then
    config.androidUseExternalStorage = false
  else
    config.androidUseExternalStorage = true
  end
end

function AndroidMigration.terminateMigration(self, intendedLocation)
  -- update config
  self.updateConfig(intendedLocation)
  -- wipe globals
  _ENV.DATA_LOCATION = nil
  _ENV.ACTION = nil
  _ENV.AndroidMigration = nil
  -- unload modules
  package.loaded.androidMigration.main = nil
  package.loaded.androidMigration.file = nil
end

function AndroidMigration.logEvent(self, ...)
  self.eventLog[#self.EVENT_LOG+1] = ...
  gprint(..., 30, 30)
end

function AndroidMigration.writeLog(self)
  local text = table.concat(self.eventLog, "\n")
  self.eventLog = { self.eventLog[#self.eventLog] }
  print(text)
  love.filesystem.append("migration.log", text)
end


function AndroidMigration.run(self)
  if config.androidUseExternalStorage == false then
    if ACTION == "READ" then
      self:readStorage()
      coroutine.yield()
      self:reboot("EXTERNAL", "WRITE")
      coroutine.yield()
    elseif ACTION == "WRITE" then
      -- try resave everything in internal storage
      self:writeStorage()
      coroutine.yield()
    else--WIPE
      self:wipeStorage()
      coroutine.yield()
      self:terminateMigration("EXTERNAL")
    end
  else
    self:writeStorage()
    coroutine.yield()
    if self:validateWrite() then
      self:logEvent("Comparison of files finished, all write results are valid")
      coroutine.yield()
      self:logEvent("Rebooting to wipe internal storage")
      coroutine.yield()
      self:reboot("INTERNAL", "WIPE")
      coroutine.yield()
    else
      self:logEvent("Validation of migration process failed, check migration.log for further information")
      coroutine.yield()
      self:logEvent("Starting the game using internal storage...")
      coroutine.yield()
      self:writeLog()
      self:terminateMigration("INTERNAL")
    end
  end
end

return AndroidMigration
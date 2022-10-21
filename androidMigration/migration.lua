require("input")

ACTION = "READ"
DATA_LOCATION = "INTERNAL"

AndroidMigration = { eventLog = {}, progress = "Waiting for confirmation" }

require("androidMigration.file")

function AndroidMigration.readStorage(self)
  self.progress = "Reading all files in " .. DATA_LOCATION .. " storage into memory..."
  self.filetree = {}
  self.saveDirectory = love.filesystem.getSaveDirectory()
  self:recursiveRead("", self.filetree) -- "" refers to the root directory
  self.progress = "Finished reading all files in " .. DATA_LOCATION .. " storage into memory"
end

function AndroidMigration.wipeStorage(self)
  --self:recursiveRemoveFiles("") -- "" is the root directory, enable for final testing/release
end

function AndroidMigration.writeStorage(self)
  self.progress = "Writing all files in memory to " .. DATA_LOCATION .. " storage"
  self:recursiveWrite(self.filetree)
  self.progress = "Finished writing all files from memory to " .. DATA_LOCATION .. " storage"
end

function AndroidMigration.validateWrite(self)
  self.action = "VALIDATE"
  self.oldFiletree = self.filetree
  self.progress = "Confirming results of write process in " .. DATA_LOCATION .. " storage"
  self:readStorage()
  self.progress = "Comparing write results with internal memory to validate successful migration"
  return self:recursiveCompare(self.oldFiletree, self.filetree)
end

function AndroidMigration.reboot(self, intendedLocation, action)
  self:logEvent(".")
  self.progress = self.progress .. "\nRestart to " .. action .. " imminent"
  for i = 0, 300 do
    self.eventLog[#self.eventLog] = self.eventLog[#self.eventLog] .. "."
    self:printEvents()
  end
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
  self:logEvent(".")
  self.progress = self.progress .. "\nRestarting the game using " .. intendedLocation .. " storage"
  for i = 0, 300 do
    self.eventLog[#self.eventLog] = self.eventLog[#self.eventLog] .. "."
    self:printEvents()
  end
  -- update config
  self.updateConfig(intendedLocation)
  -- wipe globals
  _G.DATA_LOCATION = nil
  _G.ACTION = nil
  _G.AndroidMigration = nil
  -- unload modules
  package.loaded["androidMigration.migration"] = nil
  package.loaded["androidMigration.file"] = nil
end

function AndroidMigration.logEvent(self, ...)
  self.eventLog[#self.eventLog+1] = ...
  self:printEvents()
end

function AndroidMigration.printEvents(self)
  local i = 0

  for y_offset = canvas_height - 50, 60, -15 do
    gprint(self.eventLog[#self.eventLog - i], 30, y_offset)
  end
  gprint(self.progress, 15, 30)
end

function AndroidMigration.writeLog(self)
  local text = table.concat(self.eventLog, "\n")
  self.eventLog = { self.eventLog[#self.eventLog] }
  print(text)
  love.filesystem.append("migration.log", text)
end

AndroidMigration.infoMessage = "Your device has been detected by Panel Attack as an Android device.\n" ..
"To facilitate the installation of mods and retrieval of data (e.g. for moving data or using the same user_id between PC and phone) Panel Attack will attempt to migrate its data from internal storage to external storage.\n"..
"Internal storage = only accessible by the app, users can't read or write | External storage = accessible by the app and the user, you can read and write (aka install mods, retrieve replays and user id)\n" ..
"No data will be lost in this process. In case something goes wrong, old data is retained and the game will start as normal afterwards.\n" ..
"If you encounter an issue with the migration, please notify us by creating an issue on https://github.com/panel-attack/panel-attack/issues or posting in the bugs channel in the panel attack discord server under https://discord.panelattack.com \n\n" ..
"Press any key or touch your display to start the migration."

function AndroidMigration.displayInfoMessage(self)
  gprintf(self.infoMessage, 0, 30)
end

function AndroidMigration.confirmStartMigration()
  for _, value in pairs(this_frame_keys) do
    if value == true then
      return true
    end
  end

  if #love.touch.getTouches() > 0 then
    return true
  end

  return false
end

function AndroidMigration.run(self)
  if config.androidUseExternalStorage == false then
    if ACTION == "READ" then
      while not self.confirmStartMigration() do
        self:displayInfoMessage()
        coroutine.yield()
      end

      self:readStorage()
      coroutine.yield()
      self:reboot("EXTERNAL", "WRITE")
      coroutine.yield()

    elseif ACTION == "WIPE" then
      self:wipeStorage()
      coroutine.yield()
      self:terminateMigration("EXTERNAL")
    end
  else
    self:writeStorage()
    coroutine.yield()
    if self:validateWrite() then
      self.progress = "Comparison of files finished, all write results are valid"
      coroutine.yield()
      self:logEvent("Rebooting to wipe internal storage")
      coroutine.yield()
      self:reboot("INTERNAL", "WIPE")
      coroutine.yield()
    else
      self.progress = "Validation of migration process failed, check migration.log for further information"
      coroutine.yield()
      self:logEvent("Starting the game using internal storage...")
      coroutine.yield()
      self:writeLog()
      self:terminateMigration("INTERNAL")
    end
  end
end

return AndroidMigration
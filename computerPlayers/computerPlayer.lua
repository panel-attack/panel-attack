require("engine")
require("computerPlayers.DummyCpu.DummyCpu")
local logger = require("logger")

CPUConfig = class(function(self, actualConfig)
  self.log = actualConfig["log"]
end)

function CPUConfig.print(self)
  print("print config")
  for key, value in pairs (self) do
      print('\t', key, value)
  end
end

ComputerPlayer = class(function(self, cpuName, configName)
  logger.trace("Initialising Computerplayer " .. cpuName .. " with config " .. configName)
  if cpuName == "DummyCpu" then
    self.implementation = DummyCpu()
  end

  if configName then
    local cpuConfigs = self:getConfigs()
    local config = cpuConfigs[configName]
  
    if config then
        logger.trace("cpu config successfully loaded")
        self:setConfig(config)
    else
        error("cpu config is nil")
    end
  end
end)

-- ComputerPlayer holds some functions it expects CPU implementations to implement
-- this is some kind of check for "interface" implementation
-- does actually not seem to work although I don't understand why
function ComputerPlayer.validateImplementation(self)
  if self.implementation.name == nil then
    error("cpu does not have a name")
  end

  if self.implementation.setConfig == nil then
    error(self.implementation.name .. " does not implement setConfig")
  end

  if self.implementation.getConfigs == nil then
    error(self.implementation.name .. " does not implement getConfigs")
  end

  if self.implementation.getInput == nil then
    error(self.implementation.name .. " does not implement getInput")
  end

  if self.implementation.updateStack == nil then
    error(self.implementation.name .. " does not implement updateStack")
  end
end

-- exposed for selection in menu
function ComputerPlayer.setConfig(self, config)
  self.config = CPUConfig(config)
  self.implementation:setConfig(config)
end

-- exposed for selection in menu
function ComputerPlayer.getConfigs(self)
  return self.implementation.getConfigs()
end

function ComputerPlayer.run(self, stack)
  if stack:game_ended() == false then
    self.stack = stack
    self.implementation:updateStack(stack)
    local nextInput = self.implementation:getInput()
    stack:receiveConfirmedInput(nextInput)
  end
end
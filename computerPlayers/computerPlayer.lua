require("engine")
require("profiler")
require("computerPlayers.TreeSearchComputer.TreeSearchComputer")
require("computerPlayers.EndarisCpu.EndarisCpu")

local PROFILE_TIME = 400

CPUConfig = class(function(self, actualConfig)
  self.log = actualConfig["log"]
  self.profiled = actualConfig["profiled"]
end)

function CPUConfig.print(self)
  print("print config")
  for key, value in pairs (self) do
      print('\t', key, value)
  end
end

ComputerPlayer = class(function(self, cpuName, configName)
  print("Initialising Computerplayer " .. cpuName .. " with config " .. configName)
  if cpuName == "TreeSearchComputer" then
    self.implementation = TreeSearchComputer()
  elseif cpuName == "EndarisCpu" then
    self.implementation = EndarisCpu()
  end

  if configName then
    local cpuConfigs = self:getConfigs()
    local config = cpuConfigs[configName]
  
    if config then
        print("cpu config successfully loaded")
        self:setConfig(config)
    else
        error("cpu config is nil")
    end
  end
end)

-- ComputerPlayer holds some functions it expects CPU implementations to implement
-- this is some kind of check for "interface" implementation
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
    self:startProfiler()
    self.implementation:updateStack(stack)
    local nextInput = self.implementation:getInput()
    self:stopProfiler()
    if nextInput then
      stack.input_buffer = stack.input_buffer .. nextInput
    end
    assert(#stack.input_buffer > 0, "Should have input from computer")
  end
end

function ComputerPlayer.startProfiler(self) 
  if self.config.profiled and self.profiler == nil and self.stack.which == 2 then
    -- arg references the globally available parameter for the main method
    local launch_type = arg[2]
    if launch_type == "test" or launch_type == "debug" then
      error("Can't profile while debugging")
    end
    self.profiler = newProfiler()
    self.profiler:start()
  end
end

function ComputerPlayer.stopProfiler(self)
  if self.profiler and self.stack.CLOCK > PROFILE_TIME then
    self.profiler:stop()
    local outfile = io.open( "profile.txt", "w+" )
    self.profiler:report( outfile )
    outfile:close()
    self.config.profiled = false
    self.profiler = nil
  end
end
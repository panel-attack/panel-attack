require("computerPlayers.StackExtensions")

EndarisCpu = class(function(self, stack)
  self.name = "EndarisCpu"
  self.realStack = stack
  self:initializeThinkProcess()
end)

local configs = { ['DummyConfig'] = { Log = 4 } }

function EndarisCpu.getConfigs(self)
  return configs
end

function EndarisCpu.setConfig(self, config)
  if config then
    self.config = config
    self:log(1, "cpu config successfully loaded")
    self.config:print()
  else
    error("cpu config is nil")
  end
end

-- a glorified print that prints based on the log level in the configuration
function EndarisCpu.log(self, level, ...)
  if self.config.Log >= level then
      print(...)
  end
end

function EndarisCpu.initializeThinkProcess(self)
  self.thinkRoutine = coroutine.create(self.think)
end

function EndarisCpu.resumeThinking(self)
  self.startTime = os.clock()
  local ok, errorMsg = coroutine.resume(self.thinkRoutine, self)
  if not ok then
    error(errorMsg .. "\n" .. debug.traceback(self.thinkRoutine) .. "\n" .. debug.traceback(mainloop))
  end
end

-- resumes the think routine of the cpu implementation
-- returns an encoded input for the game to use
function EndarisCpu.getInput(self)
  if self.realStack == nil or self.realStack:gameResult() ~= nil then
    -- game is over and shouldn't really ask us for more inputs
    return base64encode[1]
  else
    self:resumeThinking()

    -- wiggle in temporary absence of the think routine providing inputs 
    return base64encode[21]
  end
end

-- the main processing routine for finding out what to do next, runs in a coroutine
function EndarisCpu.think(self)
  self.startTime = os.clock()
  self:log(5, "starting coroutine at " .. self.startTime)

  -- The think process should never end on its own
  while true do
    -- do things
    self:yieldIfTooLong()
    -- do more things
    self:log(5, "yielding after finishing the thinking process at " .. os.clock())
    coroutine.yield()
  end
end

-- If we spent enough time, pass the ball back to the main routine to avoid freezes/lag
function EndarisCpu.yieldIfTooLong(self)
  local currentTime = os.clock()
  local timeSpent = currentTime - self.startTime
  -- conservatively, give PA up to half a frame (8.3ms) on the locked 60 FPS update rate to do its things
  -- use the rest for the CPU calcs
  if timeSpent > 0.08 then
    self:log(5, "yielding because the thinking process took too long at " .. os.clock())
    coroutine.yield()
  end
end
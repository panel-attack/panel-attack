require("engine")

local cpuConfigs = {
  ["Hard"] =
  {
    log = 0,
    profiled = false,
    inputSpeed = 4
  },
  ["Dev"] =
  {
    log = 2,
    profiled = false,
    inputSpeed = 15
  },
  ["DevSlow"] =
  {
    log = 2,
    profiled = false,
    inputSpeed = 60
  }
}

local active_cpuConfig = cpuConfigs["Dev"]

CPUConfig = class(function(self, actualConfig)
  self.log = actualConfig["log"]
  self.inputSpeed = actualConfig["inputSpeed"]
  self.profiled = actualConfig["profiled"]
end)

ComputerPlayer = class(function(self)
  if active_cpuConfig then
      print("cpu config successfully loaded")
      self.config = CPUConfig(active_cpuConfig)
  else
      error("cpu config is nil")
  end
end)

--inputs directly as variables cause there are no input devices
local waitInput = base64encode[0 + 1]
local rightInput = base64encode[1 + 1]
local leftInput = base64encode[2 + 1]
local downInput = base64encode[4 + 1]
local upInput = base64encode[8 + 1]
local swapInput = base64encode[16 + 1]
local raiseInput = base64encode[32 + 1]

--these won't be sent as input but serve as indicators when the CPU needs to wait with an input for the correct time instead of performing the swap at the rate limit (and thus failing the trick)
--whether they will see much use or not remains to be seen
local insert = 64
local slide = 128
local catch = 256
local doubleInsert = 512
--technically more than just a swap, combine this with the direction to find out in which direction the stealth is going
--the CPU should make sure to save up enough idleframes for all moves and then perform the inputs in one go
local stealth = 1024

function ComputerPlayer.isMovement(self, input)
  --innocently assuming we never input a direction together with something else unless it's a special that includes a timed swap anyway (doubleInsert,stealth)
  if input == rightInput or input == leftInput or input == upInput or input == downInput then
      return true
  end
  return false
end

-- a glorified print that can be turned on/off via the cpu configuration
-- high level means very detailed logging
function ComputerPlayer.cpuLog(self, level, ...)
  if self.config.log >= level then
      print(...)
  end
end

function ComputerPlayer.getInput(self, stack)

  local result
  if self.config.profiled and self.profiler == nil then
    self.profiler = newProfiler()
    self.profiler:start()
  end

  local inputBuffer = ""

  if stack.CLOCK % self.config.inputSpeed == 0 then
    self:cpuLog(2, "Computer Running at Clock: " .. stack.CLOCK)
    
    local bestAction = nil
    local bestEvaluation = -10000
    local actions = self:allActions(stack)
    for idx = 1, #actions do
      local action = actions[idx]
      local evaluation = self:evaluateAction(stack, action)
      if evaluation > bestEvaluation then
        bestAction = action
        bestEvaluation = evaluation
      end
    end

    inputBuffer = bestAction
  elseif #stack.input_buffer == 0 then
    inputBuffer = waitInput
  end

  if self.profiler and stack.CLOCK > 1000 then
    self.profiler:stop()
    local outfile = io.open( "profile.txt", "w+" )
    self.profiler:report( outfile )
    outfile:close()
    self.config.profiled = false
  end

  if inputBuffer ~= "" then
    self:cpuLog(3, "executing input " .. inputBuffer)
  end
  return inputBuffer
end

function ComputerPlayer.allActions(self, stack)
  local actions = {}

  actions[#actions + 1] = upInput .. waitInput .. swapInput
  actions[#actions + 1] = rightInput .. waitInput .. swapInput
  actions[#actions + 1] = downInput  .. waitInput .. swapInput
  actions[#actions + 1] = leftInput  .. waitInput .. swapInput

  actions[#actions + 1] = leftInput  .. waitInput .. downInput .. waitInput .. swapInput
  actions[#actions + 1] = leftInput  .. waitInput .. upInput .. waitInput .. swapInput
  actions[#actions + 1] = rightInput  .. waitInput .. downInput .. waitInput .. swapInput
  actions[#actions + 1] = rightInput  .. waitInput .. upInput .. waitInput .. swapInput

  return actions
end


function ComputerPlayer.idleAction(self, idleCount)
  local result = ""
  idleCount = idleCount or 1
  for idx = 1, idleCount do
    result = result .. waitInput
  end
  return result
end

function ComputerPlayer.evaluateAction(self, oldStack, action)

  local stack = deepcopy(oldStack, {computer=true, garbage_target=true}, {prev_states=true, computer=true, garbage_target=true, canvas=true})

  stack.input_buffer = stack.input_buffer .. action
  stack.input_buffer = stack.input_buffer .. self:idleAction(10)
  stack:run(#stack.input_buffer)

  local result = math.random() / 1000 -- small amount of randomness

  if stack:game_ended() then
    result = -1000
    self:cpuLog(4, "avoiding game over")
  end

  local cursorRow = stack.cur_row
  local cursorColumn = stack.cur_col
  if cursorRow and cursorColumn and stack.width and stack.height then
    if stack.width >= cursorColumn and stack.height >= cursorRow then
      local leftPanel = stack.panels[cursorRow][cursorColumn]
      local rightPanel = stack.panels[cursorRow][cursorColumn+1]
      if leftPanel.color == 0 or leftPanel.garbage then
        if leftPanel.garbage or rightPanel.garbage or rightPanel.color == 0 then
          self:cpuLog(4, "avoiding empty")
          result = result - 100 -- avoid cursor positions that do nothing
        end
      end
    end
  end

  for col = 1, stack.width do
    for row = 1, stack.height do
      if stack.panels[row][col].state == "matched" then
        result = result + 10
        self:cpuLog(4, "Computer: " .. stack.CLOCK .. " preferring matches")
      end
    end
  end

  if self.chain_counter and self.chain_counter > 0 then
    self:cpuLog(2, "Computer: " .. stack.CLOCK .. " found chain!")
    result = result + (10000 * self.chain_counter)
  end

  return result
end
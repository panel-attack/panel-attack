require("engine")
require("profiler")

local cpuConfigs = {
  ["Hard"] =
  {
    log = 0,
    profiled = false,
    inputSpeed = 10
  },
  ["Medium"] =
  {
    log = 0,
    profiled = false,
    inputSpeed = 15
  },
  ["Dev"] =
  {
    log = 3,
    profiled = true,
    inputSpeed = 15
  },
  ["DevSlow"] =
  {
    log = 6,
    profiled = false,
    inputSpeed = 60
  }
}

local active_cpuConfig = cpuConfigs["Hard"]

CPUConfig = class(function(self, actualConfig)
  self.log = actualConfig["log"]
  self.inputSpeed = actualConfig["inputSpeed"]
  self.profiled = actualConfig["profiled"]
end)

ComputerPlayer = class(function(self)
  if active_cpuConfig then
      print("cpu config successfully loaded")
      self.config = CPUConfig(active_cpuConfig)
      self.lastInputTime = 0
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
  if self.config.profiled and self.profiler == nil and stack.which == 1 then

    self.profiler = newProfiler()
    self.profiler:start()
  end

  if #stack.input_buffer > 0 then
    self.lastInputTime = stack.CLOCK
    return nil
  end

  local inputBuffer = ""

  if stack.CLOCK - self.lastInputTime > self.config.inputSpeed then
    self:cpuLog(2, "Computer Calculating at Clock: " .. stack.CLOCK)
    
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
    self.lastInputTime = stack.CLOCK
    self:cpuLog(4, "executing input " .. inputBuffer)
  else
    inputBuffer = waitInput
  end

  if self.profiler and stack.CLOCK > 1000 then
    self.profiler:stop()
    local outfile = io.open( "profile.txt", "w+" )
    self.profiler:report( outfile )
    outfile:close()
    self.config.profiled = false
    self.profiler = nil
  end

  return inputBuffer
end

function ComputerPlayer.allActions(self, stack)
  local actions = {}

  actions[#actions + 1] = waitInput

  actions[#actions + 1] = raiseInput

  local cursorRow = stack.cur_row
  local cursorColumn = stack.cur_col
  for column = 1, 6, 1 do
    for row = 1, 12, 1 do
      if math.abs(row - cursorRow) + math.abs(column - cursorColumn) < 5 then
        actions[#actions + 1] = self:moveToRowColumnAction(stack, row, column) .. swapInput
      end
    end
  end

  -- actions[#actions + 1] = upInput .. waitInput .. swapInput
  -- actions[#actions + 1] = rightInput .. waitInput .. swapInput
  -- actions[#actions + 1] = downInput  .. waitInput .. swapInput
  -- actions[#actions + 1] = leftInput  .. waitInput .. swapInput

  -- --diagonal
  -- actions[#actions + 1] = leftInput  .. waitInput .. downInput .. waitInput .. swapInput
  -- actions[#actions + 1] = leftInput  .. waitInput .. upInput .. waitInput .. swapInput
  -- actions[#actions + 1] = rightInput  .. waitInput .. downInput .. waitInput .. swapInput
  -- actions[#actions + 1] = rightInput  .. waitInput .. upInput .. waitInput .. swapInput

  -- --two straight
  -- actions[#actions + 1] = leftInput  .. waitInput .. leftInput .. waitInput .. swapInput
  -- actions[#actions + 1] = rightInput  .. waitInput .. rightInput .. waitInput .. swapInput
  -- actions[#actions + 1] = downInput  .. waitInput .. downInput .. waitInput .. swapInput
  -- actions[#actions + 1] = upInput  .. waitInput .. upInput .. waitInput .. swapInput

  -- --two diagonal
  -- actions[#actions + 1] = leftInput  .. waitInput .. downInput .. waitInput .. leftInput  .. waitInput .. downInput .. waitInput .. swapInput
  -- actions[#actions + 1] = leftInput  .. waitInput .. upInput .. waitInput .. leftInput  .. waitInput .. upInput .. waitInput .. swapInput
  -- actions[#actions + 1] = rightInput  .. waitInput .. downInput .. waitInput .. rightInput  .. waitInput .. downInput .. waitInput .. swapInput
  -- actions[#actions + 1] = rightInput  .. waitInput .. upInput .. waitInput .. rightInput  .. waitInput .. upInput .. waitInput .. swapInput

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


function ComputerPlayer.moveToRowColumnAction(self, stack, row, column)

  local cursorRow = stack.cur_row
  local cursorColumn = stack.cur_col

  local result = ""

  if cursorColumn > column then
    for index = cursorColumn, column, -1 do
      result = result .. leftInput .. waitInput
      result = result .. waitInput .. waitInput .. waitInput .. waitInput .. waitInput .. waitInput
    end
  end

  if cursorColumn < column then
    for index = cursorColumn, column, 1 do
      result = result .. rightInput .. waitInput
      result = result .. waitInput .. waitInput .. waitInput .. waitInput .. waitInput .. waitInput
    end
  end

  if cursorRow > row then
    for index = cursorRow, row, -1 do
      result = result .. downInput .. waitInput
      result = result .. waitInput .. waitInput .. waitInput .. waitInput .. waitInput .. waitInput
    end
  end

  if cursorRow < row then
    for index = cursorRow, row, 1 do
      result = result .. upInput .. waitInput
      result = result .. waitInput .. waitInput .. waitInput .. waitInput .. waitInput .. waitInput
    end
  end

  return result
end

function ComputerPlayer.rowEmpty(self, stack, row)
  local allBlank = true
  for col = 1, stack.width do
    if stack.panels[row][col].color ~= 0 then
      allBlank = false
      break
    end
  end
  return allBlank
end

function ComputerPlayer.evaluateAction(self, oldStack, action)

  -- TODO pass in match
  local match = deepcopy(oldStack.match, nil, {P1=true, P2=true})
  local stack = deepcopy(oldStack, nil, {garbage_target=true, prev_states=true, canvas=true, computer=true, match=true})
  local otherStack = deepcopy(oldStack.garbage_target, nil, {garbage_target=true, prev_states=true, canvas=true, computer=true, match=true})
  stack.garbage_target = otherStack
  otherStack.garbage_target = stack
  if stack.which == 1 then
    match.P1 = stack
    match.P2 = otherStack
  else
    match.P2 = stack
    match.P1 = otherStack
  end
  stack.match = match
  otherStack.match = match

  local targetTime = 50
  if #action > targetTime then
    error("action too big: " .. #action)
  end
  local idleTime = targetTime - #action
  stack.input_buffer = stack.input_buffer .. action
  stack.input_buffer = stack.input_buffer .. self:idleAction(idleTime)
  stack.garbage_target.input_buffer = stack.garbage_target.input_buffer .. self:idleAction(targetTime)

  stack:run(#stack.input_buffer)
  stack.garbage_target:run(#stack.garbage_target.input_buffer)

  local cursorRow = stack.cur_row
  local cursorColumn = stack.cur_col
  if cursorRow and cursorColumn and stack.width and stack.height then
    if stack.width >= cursorColumn and stack.height >= cursorRow then
      local leftPanel = stack.panels[cursorRow][cursorColumn]
      local rightPanel = stack.panels[cursorRow][cursorColumn+1]
      if leftPanel.color == 0 or leftPanel.garbage then
        if leftPanel.garbage or rightPanel.garbage or rightPanel.color == 0 then
          self:cpuLog(4, "avoiding empty")
          return -10000 -- avoid cursor positions that do nothing
        end
      end
    end
  end

  local result = math.random() / 100 -- small amount of randomness

  local gameResult = stack:gameResult()
  if gameResult and gameResult ~= 0 then
    result = result - (100000 * gameResult)
    self:cpuLog(3, "game over!")
  end

  -- for col = 1, stack.width do
  --   for row = 1, stack.height do
  --     if stack.panels[row][col].state == "matched" then
  --       result = result + 10
  --       self:cpuLog(3, "Computer: " .. stack.CLOCK .. " preferring matches")
  --     end
  --   end
  -- end

  result = result + (stack.stop_time * 20000)
  result = result + (stack.pre_stop_time * 2000)

  if self:rowEmpty(stack, 3) then
    result = result - 100
    self:cpuLog(3, "Computer: " .. stack.CLOCK .. " low panel count")
  end

  for index = 8, 12, 1 do
    if self:rowEmpty(stack, index) == false then
      result = result - 100
      self:cpuLog(3, "Computer: " .. stack.CLOCK .. " near top out")
    end
  end

  for index = 1, 50, 50 do
    stack.input_buffer = stack.input_buffer .. self:idleAction(1)
    stack.garbage_target.input_buffer = stack.garbage_target.input_buffer .. self:idleAction(1)
    stack:run(#stack.input_buffer)
    stack.garbage_target:run(#stack.input_buffer)

    result = result + (stack.stop_time * 20000)
    result = result + (stack.pre_stop_time * 20)

    local gameResult = stack:gameResult()
    if gameResult and gameResult ~= 0 then
      result = result + (100000 * gameResult)
      break
    end

    -- for k, v in pairs(stack.garbage_to_send) do
    --   if #v > 0 then
    --     self:cpuLog(3, "Computer: " .. stack.CLOCK .. " found garbage to send!")
    --     result = result + 10000
    --   end
    -- end
  end

  self:cpuLog(2, "Computer - Action " .. action .. " Value: " .. result)

  return result
end
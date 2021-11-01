require("engine")
require("profiler")

local MONTE_CARLO_RUN_COUNT = 1
local MAX_CURSOR_MOVE_DISTANCE = 20
local CURSOR_MOVE_WAIT_TIME = 2
local PROFILE_TIME = 800
local MAX_CLOCK_PLAYOUT = 10

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
    profiled = false,
    inputSpeed = 15
  },
  ["DevSlow"] =
  {
    log = 6,
    profiled = true,
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
  if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
  end
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
    self:cpuLog(2, "Computer " .. stack.which .. " Calculating at Clock: " .. stack.CLOCK)
    
    local results = self:bestAction(stack)

    inputBuffer = results[1]
    self.lastInputTime = stack.CLOCK
    self:cpuLog(4, "Best Action: " .. inputBuffer)
  else
    inputBuffer = waitInput
  end

  if self.profiler and stack.CLOCK > PROFILE_TIME then
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

  -- actions[#actions + 1] = swapInput

  local cursorRow = stack.cur_row
  local cursorColumn = stack.cur_col
  for column = 1, stack.width - 1, 1 do
    for row = 1, stack.height, 1 do
      local distance = math.abs(row - cursorRow) + math.abs(column - cursorColumn)
      if distance > 0 and distance <= MAX_CURSOR_MOVE_DISTANCE and stack:canSwap(row, column) then
        actions[#actions + 1] = self:moveToRowColumnAction(stack, row, column) .. swapInput
      end
    end
  end

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
    result = result .. string.rep(leftInput .. string.rep(waitInput, CURSOR_MOVE_WAIT_TIME), cursorColumn - column)
  elseif cursorColumn < column then
    result = result .. string.rep(rightInput .. string.rep(waitInput, CURSOR_MOVE_WAIT_TIME), column - cursorColumn)
  end

  if cursorRow > row then
    result = result .. string.rep(downInput .. string.rep(waitInput, CURSOR_MOVE_WAIT_TIME), cursorRow - row)
  elseif cursorRow < row then
    result = result .. string.rep(upInput .. string.rep(waitInput, CURSOR_MOVE_WAIT_TIME), row - cursorRow)
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

function ComputerPlayer.copyMatch(self, oldStack)

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

  return stack
end

function ComputerPlayer.addAction(self, stack, action)
  stack.input_buffer = stack.input_buffer .. action
end

function ComputerPlayer.heuristicValueForStack(self, stack)

  local result = math.random() / 10000000 -- small amount of randomness

  local gameResult = stack:gameResult()
  if gameResult and gameResult ~= 0 then
    result = result + (gameResult / 10)
  end

  result = result + (stack.stop_time  / 100)
  result = result + (stack.pre_stop_time / 10000)

  if self:rowEmpty(stack, 3) then
    result = result + (-1 / 100000)
    self:cpuLog(3, "Computer: " .. stack.CLOCK .. " low panel count")
  end

  for index = 8, 12, 1 do
    if self:rowEmpty(stack, index) == false then
      result = result + (-1 / 100000)
      self:cpuLog(3, "Computer: " .. stack.CLOCK .. " near top out")
    end
  end

  return result
end

function ComputerPlayer.playoutValueForStack(self, stack, maxClock)

  while stack.CLOCK + #stack.input_buffer <= stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer do
    local randomAction = uniformly(self:allActions(stack))
    self:addAction(stack, randomAction)
  end 

  while stack.CLOCK + #stack.input_buffer >= stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer do
    local randomAction2 = uniformly(self:allActions(stack.garbage_target))
    self:addAction(stack.garbage_target, randomAction2)
  end 

  --local runAmount = math.min(#stack.input_buffer, #stack.garbage_target.input_buffer)
  local goal = math.min(stack.CLOCK + #stack.input_buffer, stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer)
  stack:run(goal - stack.CLOCK)
  stack.garbage_target:run(goal - stack.garbage_target.CLOCK)

  if stack:game_ended() == false and stack.CLOCK ~= goal then
    error("us goal wrong")
  end
  if stack.garbage_target:game_ended() == false and stack.garbage_target.CLOCK ~= goal then
    error("opponent goal wrong")
  end

  local gameResult = stack:gameResult()
  if gameResult then
    -- if gameResult == 1 then
    --   gameResult = gameResult - (stack.CLOCK / 1000)
    -- end
    -- if gameResult == -1 then
    --   gameResult = gameResult + (stack.CLOCK / 1000)
    -- end
    return gameResult
  end

  if stack.CLOCK < maxClock then
    self:cpuLog(7, "Deeper..." .. stack.CLOCK)
    local innerValue = self:playoutValueForStack(stack, maxClock)
    return innerValue
  end

  return self:heuristicValueForStack(stack)
end

function ComputerPlayer.monteCarloValueForStack(self, stack, maxClock, n)
  
  n = n or MONTE_CARLO_RUN_COUNT
  local sum = 0
  for index = 1, n do
    local copiedStack = self:copyMatch(stack)
    local value = self:playoutValueForStack(copiedStack, maxClock)
    sum = sum + value
  end
  sum = sum / n
  return sum
end

function ComputerPlayer.bestAction(self, stack, maxClock)
  maxClock = maxClock or stack.CLOCK + MAX_CLOCK_PLAYOUT
  --self:cpuLog(2, "maxClock " .. maxClock )

  local bestAction = nil
  local bestEvaluation = -100000
  local actions = self:allActions(stack)
  for idx = 1, #actions do
    local action = actions[idx]
    local simulatedStack = self:copyMatch(stack)

    self:addAction(simulatedStack, action)

    local evaluation = self:monteCarloValueForStack(simulatedStack, maxClock)
    --local evaluation = self:heuristicValueForStack(simulatedStack)
    --local result = self:bestAction(simulatedStack, maxClock)
    
    self:cpuLog(2, "Computer - Action " .. action .. " Value: " .. evaluation)
    if bestAction == nil or evaluation > bestEvaluation then
      bestAction = action
      bestEvaluation = evaluation
    end
  end

  self:cpuLog(2, "Computer - done, best " .. bestAction .. " Value: " .. bestEvaluation)
  return {bestAction, bestEvaluation}
end
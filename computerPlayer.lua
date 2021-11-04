require("engine")
require("profiler")
PriorityQueue = dofile("priority_queue.lua")

local MONTE_CARLO_RUN_COUNT = 1
local MAX_CURSOR_MOVE_DISTANCE = 5
local CURSOR_MOVE_WAIT_TIME = 2
local PROFILE_TIME = 800
local MAX_CLOCK_PLAYOUT = 10
local EXPAND_COUNT = 3

local HEURISTIC_GAME_OVER_WEIGHT = 1000000
local HEURISTIC_STOP_TIME_WEIGHT = 1000
local HEURISTIC_PRE_STOP_TIME_WEIGHT = 50
local HEURISTIC_NEAR_TOP_OUT_WEIGHT = 12
local HEURISTIC_LOW_PANEL_COUNT_WEIGHT = 10
local HEURISTIC_RANDOM_WEIGHT = 1

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
    
    --local results = self:bestAction(stack)
    local results = self:treeSearch(stack)

    inputBuffer = results[1]
    self.lastInputTime = stack.CLOCK
    self:cpuLog(4, "Best Action: " .. inputBuffer)
    assert(inputBuffer and inputBuffer ~= "", "no result action")
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
        actions[#actions + 1] = self:moveToRowColumnAction(stack, row, column) .. swapInput .. waitInput
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

  local result = math.random() * HEURISTIC_RANDOM_WEIGHT -- small amount of randomness

  local gameResult = stack:gameResult()
  if gameResult and gameResult ~= 0 then
    result = gameResult * HEURISTIC_GAME_OVER_WEIGHT
  elseif stack:game_ended() ~= stack.garbage_target:game_ended() then
    error("Stacks differ in game over")
  elseif stack.CLOCK ~= stack.garbage_target.CLOCK then
    error("Stacks not simulated equal")
  end

  if stack.pre_stop_time > 0 then
    self:cpuLog(6, "stop time: " .. stack.pre_stop_time)
    result = result + (stack.pre_stop_time * HEURISTIC_PRE_STOP_TIME_WEIGHT)
  end

  if stack.pre_stop_time > 0 then
    self:cpuLog(6, "pre_stop_time: " .. stack.pre_stop_time)
    result = result + (stack.pre_stop_time * HEURISTIC_STOP_TIME_WEIGHT)
  end


  if self:rowEmpty(stack, 3) then
    result = result + HEURISTIC_LOW_PANEL_COUNT_WEIGHT
    self:cpuLog(3, "Computer: " .. stack.CLOCK .. " low panel count")
  end

  for index = 8, 12, 1 do
    if self:rowEmpty(stack, index) == false then
      result = result + HEURISTIC_NEAR_TOP_OUT_WEIGHT
      self:cpuLog(4, "Computer: " .. stack.CLOCK .. " near top out")
    end
  end

  return result
end

function ComputerPlayer.heuristicValueForIdleFilledStack(self, stack)
  self:fillIdleActions(stack)
  self:simulateTillEqual(stack)
  return self:heuristicValueForStack(stack)
end

function ComputerPlayer.simulateTillEqual(self, stack)
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
end

function ComputerPlayer.fillIdleActions(self, stack)
  while stack.CLOCK + #stack.input_buffer < stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer do
    local count = stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer - stack.CLOCK + #stack.input_buffer
    self:addAction(stack, self:idleAction(count))
  end 

  while stack.CLOCK + #stack.input_buffer > stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer do
    local count = stack.CLOCK + #stack.input_buffer - stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer
    self:addAction(stack.garbage_target, self:idleAction(count))
  end 
end

function ComputerPlayer.fillRandomActions(self, stack)
  while stack.CLOCK + #stack.input_buffer <= stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer do
    local randomAction = uniformly(self:allActions(stack))
    self:addAction(stack, randomAction)
  end 

  while stack.CLOCK + #stack.input_buffer >= stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer do
    local randomAction2 = uniformly(self:allActions(stack.garbage_target))
    self:addAction(stack.garbage_target, randomAction2)
  end 
end

function ComputerPlayer.playoutValueForStack(self, stack, maxClock)

  self:fillRandomActions(stack)
  self:simulateTillEqual(stack)

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

function ComputerPlayer.bestAction(self, stack, maxClock, depthAllowed)
  maxClock = maxClock or stack.CLOCK + MAX_CLOCK_PLAYOUT
  --self:cpuLog(2, "maxClock " .. maxClock )

  local bestAction = nil
  local bestEvaluation = -100000
  local actions = self:allActions(stack)
  for idx = 1, #actions do
    local action = actions[idx]
    local simulatedStack = self:copyMatch(stack)

    self:addAction(simulatedStack, action)

    local evaluation
    if (depthAllowed and depthAllowed <= 0) or (maxClock and stack.CLOCK + #stack.input_buffer > maxClock) then
      self:fillIdleActions(simulatedStack)
      evaluation = self:heuristicValueForStack(simulatedStack)
    else
      if depthAllowed then
        depthAllowed = depthAllowed - 1
      end
      local result = self:bestAction(simulatedStack, maxClock, depthAllowed)
      --evaluation = self:monteCarloValueForStack(simulatedStack, maxClock, depthAllowed)
    end

    
    self:cpuLog(2, "Computer - Action " .. action .. " Value: " .. evaluation)
    if bestAction == nil or evaluation > bestEvaluation then
      bestAction = action
      bestEvaluation = evaluation
    end
  end

  self:cpuLog(2, "Computer - done, best " .. bestAction .. " Value: " .. bestEvaluation)
  return {bestAction, bestEvaluation}
end

function ComputerPlayer.treeSearch(self, stack)

  stack = self:copyMatch(stack)

  local resultQueue = PriorityQueue()
  local unexpandedQueue = PriorityQueue()

  local baseValue = self:heuristicValueForIdleFilledStack(stack)
  unexpandedQueue:put({stack=stack, actions="", value=baseValue}, baseValue)

  local expandCount = 0
  while unexpandedQueue:size() > 0 and expandCount < EXPAND_COUNT do
    expandCount = expandCount + 1

    local expand = unexpandedQueue:pop()

    local gameResult = expand.stack:gameResult()

    if gameResult == nil then
      local actions = self:allActions(expand.stack)

      self:cpuLog(4, "expanding " .. #actions)
      for idx = 1, #actions do
        local action = actions[idx]
        local simulatedStack = self:copyMatch(expand.stack)
        self:addAction(simulatedStack, action)
        local totalActions = expand.actions .. action
        local value = self:heuristicValueForIdleFilledStack(simulatedStack) --kinda side effecty
        if value > 0 then
          self:cpuLog(4, "Computer - found " .. value .. "  totalActions: " .. totalActions .. " clock: " .. simulatedStack.CLOCK)
        end
        unexpandedQueue:put({stack=simulatedStack, actions=totalActions, value=value}, -value)
      end
    end
  
    if #expand.actions > 0 then
      resultQueue:put(expand, -expand.value)
    end
  end

  assert(resultQueue:size() > 0, "no results in queue")
  local result = resultQueue:pop()
  local bestAction = result.actions
  local bestEvaluation = result.value

  self:cpuLog(2, "Computer - done, best " .. bestAction .. " Value: " .. bestEvaluation)
  return {bestAction, bestEvaluation}
end

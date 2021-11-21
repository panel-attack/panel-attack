require("engine")
require("profiler")

local MONTE_CARLO_RUN_COUNT = 1
local CURSOR_MOVE_WAIT_TIME = 2
local PROFILE_TIME = 400
local MAX_CLOCK_PLAYOUT = 10
local EXPAND_COUNT = 3
local MAX_THINK_TIME = 1 / 130
local DEFAULT_CURSOR_MOVE_DISTANCE = 20

local HEURISTIC_STOP_TIME_WEIGHT = .2
local HEURISTIC_PRE_STOP_TIME_WEIGHT = .1
local HEURISTIC_RANDOM_WEIGHT = 0.001
local HEURISTIC_LOW_PANEL_COUNT_WEIGHT = -0.01

local STACK_LOW_ROW = 3
local STACK_ROW_EMPTY_ALLOWING_RAISE = 3

local cpuConfigs = {
  ["Hard"] =
  {
    log = 0,
    profiled = false,
    inputSpeed = 5
  },
  ["Medium"] =
  {
    log = 2,
    profiled = false,
    inputSpeed = 10
  },
  ["Easy"] =
  {
    log = 0,
    profiled = false,
    inputSpeed = 60
  },
  ["Dev"] =
  {
    log = 3,
    profiled = false,
    inputSpeed = 5,
    heuristicPanelScore = 0.05
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
  self.heuristicPanelScore = actualConfig["heuristicPanelScore"] or 0
  self.cursorMoveDistance = actualConfig["cursorMoveDistance"] or DEFAULT_CURSOR_MOVE_DISTANCE
end)

ComputerPlayer = class(function(self, configName)
  local config = active_cpuConfig
  if configName then
    config = cpuConfigs[configName]
  end

  if config then
      print("cpu config successfully loaded")
      self.config = CPUConfig(config)
      self.targetInputTime = nil
      self.thinkRoutine = nil
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

function ComputerPlayer.run(self, stack)
  if stack:game_ended() == false then
    local nextInput = self:getInput(stack)
    if nextInput then
      stack.input_buffer = stack.input_buffer .. nextInput
    end
    assert(#stack.input_buffer > 0, "Should have input from computer")
  end
end

function ComputerPlayer.getInput(self, stack)
  local result
  if self.config.profiled and self.profiler == nil and stack.which == 2 then
    local launch_type = arg[2]
    if launch_type == "test" or launch_type == "debug" then
      error("Can't profile while debugging")
    end
    self.profiler = newProfiler()
    self.profiler:start()
  end

  if self.targetInputTime == nil and #stack.input_buffer <= self.config.inputSpeed then
    self.targetInputTime = stack.CLOCK + self.config.inputSpeed
    local idleCount = self.config.inputSpeed - #stack.input_buffer
    self:initThink(stack, idleCount)
    self.thinkRoutine = coroutine.create(self.think)
  end

  local inputBuffer = nil
  if self.targetInputTime then
    local status, err = coroutine.resume(self.thinkRoutine, self)
    if not status then
      error(err .. "\n" .. debug.traceback(mainloop))
    end

    if self.targetInputTime == stack.CLOCK then
      local results = self:currentResult()
      inputBuffer = results[1]
      assert(inputBuffer and inputBuffer ~= "", "no result action")
      self.targetInputTime = nil
      self:clearThink()

      self:cpuLog(1, "Computer " .. stack.which .. " inputting " .. inputBuffer .. " at Clock: " .. stack.CLOCK .. " with value " .. results[2])
    else
      if #stack.input_buffer > 0 then
        self:cpuLog(4, "Computer thinking while using up inputs")
      else
        self:cpuLog(4, "Computer thinking while idling")
        inputBuffer = waitInput
      end
    end
  else
    assert(#stack.input_buffer > 0, "expected input")
    self:cpuLog(4, "Computer not thinking, already has large input count: " .. #stack.input_buffer)
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

  --actions[#actions + 1] = waitInput

  if self:rowEmpty(stack, STACK_ROW_EMPTY_ALLOWING_RAISE) then
    actions[#actions + 1] = raiseInput
  end

  --actions[#actions + 1] = swapInput .. waitInput

  local cursorRow = stack.cur_row
  local cursorColumn = stack.cur_col
  for column = 1, stack.width - 1, 1 do
    for row = 1, stack.height, 1 do
      local distance = math.abs(row - cursorRow) + math.abs(column - cursorColumn)
      if distance > 0 and distance <= self.config.cursorMoveDistance then
        if stack:canSwap(row, column) then
          if stack.panels[row][column].color ~= stack.panels[row][column + 1].color then
            -- We wait one frame after swapping because thats when the swap actually happens
            actions[#actions + 1] = self:moveToRowColumnAction(stack, row, column) .. swapInput .. string.rep(waitInput, 5)
          end
        end
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

function ComputerPlayer.panelCount(self, stack)
  local panelCount = 0

  for column = 1, stack.width - 1, 1 do
    for row = 1, stack.height, 1 do
      if stack.panels[row][column].color ~= 0 then
        panelCount = panelCount + 1
      end
    end
  end
  return panelCount
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
  -- TODO not copying prev_states means we can't simulate rollback of garbage, but copying is expensive?
  local match = deepcopy(oldStack.match, nil, {P1=true, P2=true, P1CPU=true, P2CPU=true})
  local stack = deepcopy(oldStack, nil, {garbage_target=true, prev_states=true, canvas=true, match=true})
  local otherStack = deepcopy(oldStack.garbage_target, nil, {garbage_target=true, prev_states=true, canvas=true, match=true})
  otherStack.is_local = false
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

function ComputerPlayer.panelsScore(self, stack)

  local score = 0
  local panels = stack.panels

  local colorColumns = {}

  for color = 1, stack.NCOLORS do
    colorColumns[color] = {total=0, columns={}}
  end
  colorColumns[8] = {total=0, columns={}}

  for row = 1, stack.height do
    for col = 1, stack.width do
      local color = panels[row][col].color
      if color > 0 and color ~= 9 then
        if not panels[row][col]:exclude_match() then
          table.insert(colorColumns[color].columns, col)
          colorColumns[color].total = colorColumns[color].total + col
        end
      end
    end
  end

  local bestColor = 0
  local bestColorCount = 0
  for k, color in pairs(colorColumns) do
    if #color.columns > bestColorCount then
      bestColor = k
      bestColorCount = #color.columns
    end
  end

  --for k, color in pairs(colorColumns) do
  local color = colorColumns[bestColor]
    if #color.columns > 2 then
      local averageColumn = color.total / #color.columns
      local colorScore = 0
      for k, v in pairs(color.columns) do
        -- ((x+2)*0.1)^(-1.5)
        local distance = math.abs(v - averageColumn)
        --local panelScore = math.pow((distance+2)*0.1, -3.2)
        local panelScore = -distance
        --colorScore = colorScore + math.pow(math.abs(v - averageColumn), 2)
        colorScore = colorScore + panelScore
      end
      score = score + colorScore
    end
  --end

  return score / 200
end

function ComputerPlayer.heuristicValueForStack(self, stack)


  local gameResult = stack:gameResult()
  if gameResult and gameResult == 1 then
    return 1
  elseif gameResult and gameResult == -1 then
    return 0
  elseif stack:game_ended() ~= stack.garbage_target:game_ended() then
    error("Stacks differ in game over")
  elseif stack.CLOCK ~= stack.garbage_target.CLOCK then
    error("Stacks not simulated equal")
  end

  local result = 0.5 + math.random() * HEURISTIC_RANDOM_WEIGHT -- small amount of randomness

  if stack.stop_time > 0 then
    local maxStopTime = 1000 -- TODO
    local value = (stack.stop_time / maxStopTime) * HEURISTIC_STOP_TIME_WEIGHT
    result = result + value
    self:cpuLog(4, "stop time: " .. value)
  end

  if stack.pre_stop_time > 0 then
    local maxPreStop = stack.FRAMECOUNT_MATCH + stack.FRAMECOUNT_POP * (100) --TODO
    local value = (stack.pre_stop_time / maxPreStop) * HEURISTIC_PRE_STOP_TIME_WEIGHT
    result = result + value
    self:cpuLog(4, "pre_stop_time: " .. value)
  end
  
  if self.config.heuristicPanelScore ~= 0 then
    local localResult = self:panelsScore(stack) * self.config.heuristicPanelScore
    self:cpuLog(2, "panelScore: " .. localResult)
    result = result + localResult
  end

  if self:rowEmpty(stack, STACK_LOW_ROW) then
    local panelCount = self:panelCount(stack)
    local maxPanels = (STACK_LOW_ROW * stack.width)
    local value = (maxPanels - panelCount) / maxPanels * HEURISTIC_LOW_PANEL_COUNT_WEIGHT
    result = result + value
    self:cpuLog(2, "Computer: " .. stack.CLOCK .. " low panel count " .. value)
  end

  -- for index = 8, 12, 1 do
  --   if self:rowEmpty(stack, index) == false then
  --     result = result + HEURISTIC_NEAR_TOP_OUT_WEIGHT
  --     self:cpuLog(2, "Computer: " .. stack.CLOCK .. " near top out")
  --   end
  -- end

  return result
end

function ComputerPlayer.heuristicValueForIdleFilledStack(self, stack)
  self:fillIdleActions(stack)
  self:simulateTillEqual(stack)
  return self:heuristicValueForStack(stack)
end

function ComputerPlayer.simulateAllInputs(self, stack)
  stack:run(#stack.input_buffer)
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
    local count = (stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer) - (stack.CLOCK + #stack.input_buffer)
    self:addAction(stack, self:idleAction(count))
  end 

  while stack.CLOCK + #stack.input_buffer > stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer do
    local count = (stack.CLOCK + #stack.input_buffer) - (stack.garbage_target.CLOCK + #stack.garbage_target.input_buffer)
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

--[[
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
--]]

function ComputerPlayer.yieldIfTooLong(self)
  -- If we spent enough time, pause
  local currentTime = os.clock()
  local timeSpent = currentTime - self.startTime
  if timeSpent > MAX_THINK_TIME then
    self:cpuLog(4, "Computer - timeSpent " .. round(timeSpent, 4) .. " " .. self.unexpandedQueue:size() .. " / " .. self.resultQueue:size())
    coroutine.yield()
    self.startTime = os.clock()
  end
end

function ComputerPlayer.think(self)

  self.startTime = os.clock()

  -- Never terminate the coroutine
  while true do
    if self.unexpandedQueue:size() > 0 then
      local expand = self.unexpandedQueue:pop()

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

          -- Don't allow the empty start state to be a valid result
          if #totalActions > 0 then
            local node = {stack=simulatedStack, actions=totalActions, value=value}
            local expandValue = -1 * self:expandValue(value, #totalActions)
            self.unexpandedQueue:put(node, expandValue)
            self.resultQueue:put(node, -value)
          end

          self:yieldIfTooLong()
        end
      end
    
      self:yieldIfTooLong()
    else
      coroutine.yield()
      self.startTime = os.clock()
    end
  end
end

-- function ComputerPlayer.mctsValue(self, stack) 
--   self = current
--   q = sum of explored values
--   n = numberOfVisits explored
--   c = child
--   local c_param = math.sqrt(2)
--   local exploitation = c.q() / c.n()
--   local exploration = c_param * math.sqrt((2 * math.log(self.n()) / c.n()
--   local value = exploitation + exploration
--   return value
-- end

function ComputerPlayer.expandValue(self, value, depth)
  --local depthMultiplier = 3 - math.sqrt(depth * 2.2)
  --local depthMultiplier = math.sqrt(depth * 6.2)
  local depthMultiplier = 1.0
  local result = value * depth
  return result
end


function ComputerPlayer.initThink(self, stack, idleCount)
  self.resultQueue = PriorityQueue()
  self.unexpandedQueue = PriorityQueue()

  stack = self:copyMatch(stack)
  self:addAction(stack, self:idleAction(idleCount))
  assert(stack.CLOCK + #stack.input_buffer == self.targetInputTime, "should have buffer to input time")

  local baseValue = self:heuristicValueForIdleFilledStack(stack)
  self.unexpandedQueue:put({stack=stack, actions="", value=baseValue}, self:expandValue(baseValue, 0))

end

function ComputerPlayer.clearThink(self)
  self.resultQueue = PriorityQueue()
  self.unexpandedQueue = PriorityQueue()
end

function ComputerPlayer.currentResult(self) 
  if self.resultQueue:size() > 0 then
    local result = self.resultQueue:pop()
    local bestAction = result.actions
    local bestEvaluation = result.value

    self:cpuLog(1, "Computer resultQueue:" .. self.resultQueue:size() .. " unexpandedQueue " .. self.unexpandedQueue:size())
    return {bestAction, bestEvaluation}
  else
    return {waitInput, 0}
  end
end
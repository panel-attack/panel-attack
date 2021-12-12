require("engine")
require("profiler")

local MONTE_CARLO_RUN_COUNT = 1
local DEFAULT_CURSOR_MOVE_WAIT_TIME = 2
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
    log = 5,
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
    log = 2,
    profiled = false,
    inputSpeed = 60 * 1,
    actionsPerThink = 10,
    cursorMoveWaitTime = 10,
    cursorMoveDistance = 20,
    heuristicPanelScore = 0.05
  },
  ["DevSlow"] =
  {
    log = 6,
    profiled = true,
    inputSpeed = 60
  }
}

JamesAi = class(function(self)  
    self.name = "JamesAi"
    self.stack = nil
    self.config = nil
end)

function JamesAi.initializeConfig(self, config)
    self.config.log = config["log"]
    self.config.inputSpeed = config["inputSpeed"]
    self.config.actionsPerThink = config["actionsPerThink"] or nil
    self.config.cursorMoveWaitTime = config["cursorMoveWaitTime"] or DEFAULT_CURSOR_MOVE_WAIT_TIME
    self.config.profiled = config["profiled"]
    self.config.heuristicPanelScore = config["heuristicPanelScore"] or 0
    self.config.cursorMoveDistance = config["cursorMoveDistance"] or DEFAULT_CURSOR_MOVE_DISTANCE
end

function JamesAi.getConfigs()
    return cpuConfigs
end

function JamesAi.setConfig(self, config)
    if config then
        print("cpu config successfully loaded")
        self.config = CPUConfig(config)
        self:initializeConfig(config)
        self.targetInputTime = nil
        self.thinkRoutine = nil
    else
        error("cpu config is nil")
    end
end

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

function JamesAi.isMovement(self, input)
  --innocently assuming we never input a direction together with something else unless it's a special that includes a timed swap anyway (doubleInsert,stealth)
  if input == rightInput or input == leftInput or input == upInput or input == downInput then
      return true
  end
  return false
end

-- a glorified print that can be turned on/off via the cpu configuration
-- high level means very detailed logging
function JamesAi.cpuLog(self, level, ...)
  if self.config.log >= level then
      print(...)
  end
end

function JamesAi.getInput(self)
  if self.targetInputTime == nil and #self.stack.input_buffer <= self.config.inputSpeed then
    self.targetInputTime = self.stack.CLOCK + self.config.inputSpeed
    local idleCount = self.config.inputSpeed - #self.stack.input_buffer
    self:initThink(idleCount)
    self.thinkRoutine = coroutine.create(self.think)
  end

  local inputBuffer = nil
  if self.targetInputTime then
    local status, err = coroutine.resume(self.thinkRoutine, self)
    if not status then
      error(err .. "\n" .. debug.traceback(mainloop))
    end

    if self.targetInputTime == self.stack.CLOCK then
      local results = self:currentResult()
      inputBuffer = results[1]
      assert(inputBuffer and inputBuffer ~= "", "no result action")
      self.targetInputTime = nil
      self:clearThink()

      self:cpuLog(1, "Computer " .. self.stack.which .. " inputting " .. inputBuffer .. " at Clock: " .. self.stack.CLOCK .. " with value " .. results[2])
    else
      if #self.stack.input_buffer > 0 then
        self:cpuLog(4, "Computer thinking while using up inputs")
      else
        self:cpuLog(4, "Computer thinking while idling")
        inputBuffer = waitInput
      end
    end
  else
    assert(#self.stack.input_buffer > 0, "expected input")
    self:cpuLog(4, "Computer not thinking, already has large input count: " .. #self.stack.input_buffer)
  end

  return inputBuffer
end

function JamesAi.allActions(self, stack, actionsAllowed)
  local actions = {}

  --actions[#actions + 1] = waitInput

  if not actionsAllowed or actionsAllowed > 0 then
    if self:rowEmpty(stack, STACK_ROW_EMPTY_ALLOWING_RAISE) then
      actions[#actions + 1] = raiseInput
    end
  end

  --actions[#actions + 1] = swapInput .. waitInput

  local cursorRow = stack.cur_row
  local cursorColumn = stack.cur_col
  for column = 1, stack.width - 1, 1 do
    for row = 1, stack.height, 1 do
      local distance = math.abs(row - cursorRow) + math.abs(column - cursorColumn)
      if not actionsAllowed or actionsAllowed > distance + 1 then
        if distance > 0 and distance <= self.config.cursorMoveDistance then
          if stack:canSwap(row, column) then
            if stack.panels[row][column].color ~= stack.panels[row][column + 1].color then
              -- We wait one frame after swapping because thats when the swap actually happens
              actions[#actions + 1] = self:moveToRowColumnAction(row, column) .. swapInput .. string.rep(waitInput, 5)
            end
          end
        end
      end
    end
  end

  return actions
end

function JamesAi.idleAction(self, idleCount)
  local result = ""
  idleCount = idleCount or 1
  for idx = 1, idleCount do
    result = result .. waitInput
  end
  return result
end

function JamesAi.moveToRowColumnAction(self, row, column)

  local cursorRow = self.stack.cur_row
  local cursorColumn = self.stack.cur_col

  local result = ""
  local cursorWaitTime = self.config.cursorMoveWaitTime

  if cursorColumn > column then
    result = result .. string.rep(leftInput .. string.rep(waitInput, cursorWaitTime), cursorColumn - column)
  elseif cursorColumn < column then
    result = result .. string.rep(rightInput .. string.rep(waitInput, cursorWaitTime), column - cursorColumn)
  end

  if cursorRow > row then
    result = result .. string.rep(downInput .. string.rep(waitInput, cursorWaitTime), cursorRow - row)
  elseif cursorRow < row then
    result = result .. string.rep(upInput .. string.rep(waitInput, cursorWaitTime), row - cursorRow)
  end

  return result
end

function JamesAi.panelCount(self, stack)
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

function JamesAi.rowEmpty(self, stack, row)
  local allBlank = true
  for col = 1, stack.width do
    if stack.panels[row][col].color ~= 0 then
      allBlank = false
      break
    end
  end
  return allBlank
end

function JamesAi.copyMatch(self, oldStack)

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

function JamesAi.addAction(self, stack, action)
  stack.input_buffer = stack.input_buffer .. action
end

function JamesAi.panelsScore(self)

  local score = 0
  local panels = self.stack.panels

  local colorColumns = {}

  for color = 1, self.stack.NCOLORS do
    colorColumns[color] = {total=0, columns={}}
  end
  colorColumns[8] = {total=0, columns={}}

  for row = 1, self.stack.height do
    for col = 1, self.stack.width do
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
  local bestColorCount = -1
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

function JamesAi.heuristicValueForStack(self)


  local gameResult = self.stack:gameResult()
  if gameResult and gameResult == 1 then
    return 1
  elseif gameResult and gameResult == -1 then
    return 0
  elseif self.stack:game_ended() ~= self.stack.garbage_target:game_ended() then
    error("Stacks differ in game over")
  elseif self.stack.CLOCK ~= self.stack.garbage_target.CLOCK then
    error("Stacks not simulated equal")
  end

  local result = 0.5 + math.random() * HEURISTIC_RANDOM_WEIGHT -- small amount of randomness

  if self.stack.stop_time > 0 then
    local maxStopTime = 1000 -- TODO
    local value = (self.stack.stop_time / maxStopTime) * HEURISTIC_STOP_TIME_WEIGHT
    result = result + value
    self:cpuLog(4, "stop time: " .. value)
  end

  if self.stack.pre_stop_time > 0 then
    local maxPreStop = self.stack.FRAMECOUNT_MATCH + self.stack.FRAMECOUNT_POP * (100) --TODO
    local value = (self.stack.pre_stop_time / maxPreStop) * HEURISTIC_PRE_STOP_TIME_WEIGHT
    result = result + value
    self:cpuLog(4, "pre_stop_time: " .. value)
  end
  
  if self.config.heuristicPanelScore ~= 0 then
    local localResult = self:panelsScore() * self.config.heuristicPanelScore
    self:cpuLog(4, "panelScore: " .. localResult)
    result = result + localResult
  end

  if self:rowEmpty(self.stack, STACK_LOW_ROW) then
    local panelCount = self:panelCount()
    local maxPanels = (STACK_LOW_ROW * self.stack.width)
    local value = (maxPanels - panelCount) / maxPanels * HEURISTIC_LOW_PANEL_COUNT_WEIGHT
    result = result + value
    self:cpuLog(4, "Computer: " .. self.stack.CLOCK .. " low panel count " .. value)
  end

  -- for index = 8, 12, 1 do
  --   if self:rowEmpty(self.stack, index) == false then
  --     result = result + HEURISTIC_NEAR_TOP_OUT_WEIGHT
  --     self:cpuLog(2, "Computer: " .. self.stack.CLOCK .. " near top out")
  --   end
  -- end

  return result
end

function JamesAi.heuristicValueForIdleFilledStack(self)
  self:fillIdleActions()
  self:simulateTillEqual()
  return self:heuristicValueForStack()
end

function JamesAi.simulateAllInputs(self)
  self.stack:run(#self.stack.input_buffer)
end

function JamesAi.simulateTillEqual(self)
  --local runAmount = math.min(#self.stack.input_buffer, #self.stack.garbage_target.input_buffer)
  local goal = math.min(self.stack.CLOCK + #self.stack.input_buffer, self.stack.garbage_target.CLOCK + #self.stack.garbage_target.input_buffer)
  self.stack:run(goal - self.stack.CLOCK)
  self.stack.garbage_target:run(goal - self.stack.garbage_target.CLOCK)

  if self.stack:game_ended() == false and self.stack.CLOCK ~= goal then
    error("us goal wrong")
  end
  if self.stack.garbage_target:game_ended() == false and self.stack.garbage_target.CLOCK ~= goal then
    error("opponent goal wrong")
  end
end

function JamesAi.fillIdleActions(self)
  while self.stack.CLOCK + #self.stack.input_buffer < self.stack.garbage_target.CLOCK + #self.stack.garbage_target.input_buffer do
    local count = (self.stack.garbage_target.CLOCK + #self.stack.garbage_target.input_buffer) - (self.stack.CLOCK + #self.stack.input_buffer)
    self:addAction(self.stack, self:idleAction(count))
  end 

  while self.stack.CLOCK + #self.stack.input_buffer > self.stack.garbage_target.CLOCK + #self.stack.garbage_target.input_buffer do
    local count = (self.stack.CLOCK + #self.stack.input_buffer) - (self.stack.garbage_target.CLOCK + #self.stack.garbage_target.input_buffer)
    self:addAction(self.stack.garbage_target, self:idleAction(count))
  end 
end

--[[
function JamesAi.fillRandomActions(self)
  while self.stack.CLOCK + #self.stack.input_buffer <= self.stack.garbage_target.CLOCK + #self.stack.garbage_target.input_buffer do
    local randomAction = uniformly(self:allActions())
    self:addAction(self.stack, randomAction)
  end 

  while self.stack.CLOCK + #self.stack.input_buffer >= self.stack.garbage_target.CLOCK + #self.stack.garbage_target.input_buffer do
    local randomAction2 = uniformly(self:allActions(self.stack.garbage_target))
    self:addAction(self.stack.garbage_target, randomAction2)
  end 
end

function JamesAi.playoutValueForStack(self, maxClock)

  self:fillRandomActions()
  self:simulateTillEqual()

  local gameResult = self.stack:gameResult()
  if gameResult then
    -- if gameResult == 1 then
    --   gameResult = gameResult - (self.stack.CLOCK / 1000)
    -- end
    -- if gameResult == -1 then
    --   gameResult = gameResult + (self.stack.CLOCK / 1000)
    -- end
    return gameResult
  end

  if self.stack.CLOCK < maxClock then
    self:cpuLog(7, "Deeper..." .. self.stack.CLOCK)
    local innerValue = self:playoutValueForStack(maxClock)
    return innerValue
  end

  return self:heuristicValueForStack()
end

function JamesAi.monteCarloValueForStack(self, maxClock, n)
  
  n = n or MONTE_CARLO_RUN_COUNT
  local sum = 0
  for index = 1, n do
    local copiedStack = self:copyMatch(self.stack)
    local value = self:playoutValueForStack(copiedStack, maxClock)
    sum = sum + value
  end
  sum = sum / n
  return sum
end

function JamesAi.bestAction(self, maxClock, depthAllowed)
  maxClock = maxClock or self.stack.CLOCK + MAX_CLOCK_PLAYOUT
  --self:cpuLog(2, "maxClock " .. maxClock )

  local bestAction = nil
  local bestEvaluation = -100000
  local actions = self:allActions()
  for idx = 1, #actions do
    local action = actions[idx]
    local simulatedStack = self:copyMatch(self.stack)

    self:addAction(simulatedStack, action)

    local evaluation
    if (depthAllowed and depthAllowed <= 0) or (maxClock and self.stack.CLOCK + #self.stack.input_buffer > maxClock) then
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

function JamesAi.yieldIfTooLong(self)
  -- If we spent enough time, pause
  local currentTime = os.clock()
  local timeSpent = currentTime - self.startTime
  if timeSpent > MAX_THINK_TIME then
    self:cpuLog(4, "Computer - timeSpent " .. round(timeSpent, 4) .. " " .. self.unexpandedQueue:size() .. " / " .. self.resultQueue:size())
    coroutine.yield()
    self.startTime = os.clock()
  end
end

function JamesAi.think(self)

  self.startTime = os.clock()

  -- Never terminate the coroutine
  while true do
    if self.unexpandedQueue:size() > 0 then
      local expand = self.unexpandedQueue:pop()

      local gameResult = expand.stack:gameResult()

      if gameResult == nil then

        local actionsAllowed = nil
        if self.config.actionsPerThink then
          local _, idleCount = string.gsub(expand.actions, waitInput, "")
          local actionCount = #expand.actions - idleCount
          actionsAllowed = self.config.actionsPerThink - actionCount
          self:cpuLog(5, "actionsAllowed " .. actionsAllowed)
        end
        local actions = self:allActions(expand.stack, actionsAllowed)

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

-- function JamesAi.mctsValue(self) 
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

function JamesAi.expandValue(self, value, depth)
  --local depthMultiplier = 3 - math.sqrt(depth * 2.2)
  --local depthMultiplier = math.sqrt(depth * 6.2)
  local depthMultiplier = 1.0
  local result = value * depth
  return result
end

function JamesAi.updateStack(self, stack)
  self.stack = self:copyMatch(stack)  
end

function JamesAi.initThink(self, idleCount)
  self.resultQueue = PriorityQueue()
  self.unexpandedQueue = PriorityQueue()

  self.stack = self:copyMatch(self.stack)
  self:addAction(self.stack, self:idleAction(idleCount))
  assert(self.stack.CLOCK + #self.stack.input_buffer == self.targetInputTime, "should have buffer to input time")

  self.thinkStartClock = self.stack.CLOCK
  
  local baseValue = self:heuristicValueForIdleFilledStack()
  self.unexpandedQueue:put({stack=self.stack, actions="", value=baseValue}, self:expandValue(baseValue, 0))

end

function JamesAi.clearThink(self)
  self.resultQueue = PriorityQueue()
  self.unexpandedQueue = PriorityQueue()
end

function JamesAi.currentResult(self) 
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
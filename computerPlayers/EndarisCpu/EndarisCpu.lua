require("computerPlayers.EndarisCpu.StackExtensions")
require("computerPlayers.EndarisCpu.GridVector")
require("computerPlayers.EndarisCpu.CpuStack")
require("computerPlayers.EndarisCpu.RowGrid")
require("computerPlayers.EndarisCpu.CpuInput")
require("computerPlayers.EndarisCpu.Helpers")
require("computerPlayers.EndarisCpu.Actions")
require("computerPlayers.EndarisCpu.Attack")
require("computerPlayers.EndarisCpu.Defense")
require("computerPlayers.EndarisCpu.Defragmentation")

CpuLog = nil

local cpuConfigs = {
    ['DevConfig'] = {
        ReadingBehaviour = 'WaitMatch',
        Log = 4,
        MoveRateLimit = 10,
        MoveSwapRateLimit = 10,
        DefragmentationPercentageThreshold = 0.3
    },
    ['DummyTestOption'] = {
        ReadingBehaviour = 'WaitAll',
        Log = 3,
        MoveRateLimit = 40,
        MoveSwapRateLimit = 40,
        DefragmentationPercentageThreshold = 0.3
    }
}

EndarisCpu = class(function(self)
    self.name = "EndarisCpu"
    self.actions = {}
    self.currentAction = nil
    self.actionQueue = {}
    self.inputQueue = {}
    self.simulationQueue = {}
    self.cpuStack = nil
    self.realStack = nil
    self.enable_stealth = true
    self.enable_inserts = true
    self.enable_slides = false
    self.enable_catches = false
    self.enable_doubleInsert = false
    self.lastInput = Input.WaitTimeSpan(170, 180)
    self.lookAheadSnapShots = {}
end)

function EndarisCpu.getConfigs()
    return cpuConfigs
end

function EndarisCpu.setConfig(self, config)
    if config then
        print("cpu config successfully loaded")
        self.config = CPUConfig(config)
        self:initializeConfig(config)
        self.config:print()
    else
        error("cpu config is nil")
    end
end

function EndarisCpu.initializeConfig(self, config)
    self.config.Log = config['Log']
    CpuLog = CpuLogger(self.config.Log)
    self.config.ReadingBehaviour = config['ReadingBehaviour']
    -- config is supposed to be in frames but internally s are being used
    self.config.MoveRateLimit = config['MoveRateLimit']
    self.config.MoveSwapRateLimit = config['MoveSwapRateLimit']
    self.config.DefragmentationPercentageThreshold = config['DefragmentationPercentageThreshold']
end

function EndarisCpu.updateStack(self, realStack)
    CpuLog:log(1, "entering function updateStack")
    if self.realStack == nil then
        self.realStack = realStack
    end
    if realStack then
        CpuLog:log(1, "CLOCK realStack: " .. self.realStack.CLOCK)
        if self.cpuStack == nil then
          self.cpuStack =  StackExtensions.copyStack(realStack)
            self:initializeCoroutine()
        else
            CpuLog:log(1, "CLOCK local stack: " .. self.cpuStack.CLOCK)
            if #self.lookAheadSnapShots > 0 then
                CpuLog:log(1, "Found " .. #self.lookAheadSnapShots .. " lookAheadSnapshots")
                local snapShot = self.lookAheadSnapShots[1]

                -- compare stack with the snapshot at the snapshot's time
                if realStack.CLOCK >= snapShot.CLOCK then
                    CpuLog:log(1, "Real stack caught up with oldest snapshot")
                    if not StackExtensions.panelsAreEqualByPanels(self.cpuStack.panels, realStack.panels) then
                        -- discard queued actions in favor of recalculation
                        CpuLog:log(1, "Found mismatch between realStack and simulated snapshot, discarding planned actions and simulated stack and restart the coroutine on the new stack copy")
                        self.lookAheadSnapShots = {}
                        self.actionQueue = {}
                        self.inputQueue = {} --makes sense cause we just finished an action
                        self.simulationQueue = {}
                        self.cpuStack =  StackExtensions.copyStack(realStack)
                        -- need to restart the coroutine to discard calculations in progress from invalid stack
                        self:initializeCoroutine()
                    else
                        CpuLog:log(1, "RealStack and simulated snapshot are equal, removing snapshot and resuming with simulated stack")
                        -- snapShot has been reached with the expected result
                        table.remove(self.lookAheadSnapShots, 1)
                    end
                else
                    --CpuLog:log(1, "Real stack has not yet caught up with oldest snapshot")
                    if not self.thinkRoutine or coroutine.status(self.thinkRoutine) == "dead" then
                        CpuLog:log(1, "Coroutine has terminated for whatever reason, restarting the think process")
                        -- currently not thinking, might as well plan out more moves in the future
                        self:initializeCoroutine()
                    end
                end
            else
                CpuLog:log(1, "No lookAheadSnapshots found, coroutine expected to be suspended")
                assert(coroutine.status(self.thinkRoutine) == "suspended")
            end
        end
    end
end

function EndarisCpu.initializeCoroutine(self)
    self.thinkRoutine = coroutine.create(self.think)
end

function EndarisCpu.think(self)
    self.startTime = os.clock()
    self.yieldCount = 0
    CpuLog:log(3, "starting coroutine at " .. self.startTime)

    -- Never terminate the coroutine
    while true do
        local gameResult = self.realStack:gameResult()

        --this means the game is still in progress
        if gameResult == nil then
            if self.cpuStack then
                if self.currentAction then
                    self:finalizeCurrentAction()
                end
                -- discard actions of previous loop
                self.actions = {}

                -- technically the snapshot system should work but I think there are still some direct references to current_action and/or lastInput that make the CPU goof around if the snapshot system is used
                if #self.lookAheadSnapShots < 1 then
                    self.strategy = self:chooseStrategy()
                    self:yieldIfTooLong()
                    self:chooseAction()
                    self:yieldIfTooLong()
                    -- to avoid having to reinitialise the coroutine a stack projection is generated that holds...
                    -- ...anticipated future snapshots of the stack that can be compared...
                    -- ... to the updates received from the game to see if all happened according to expectations
                    self:simulatePostActionStack()
                end
            end
        end
        CpuLog:log(3, "yielding after finishing the thinking process at " .. os.clock())
        coroutine.yield()
    end
end

function EndarisCpu.yieldIfTooLong(self)
    -- If we spent enough time, pass the ball back to the main routine to avoid freezes/lag
  local currentTime = os.clock()
  CpuLog:log(6, "it is " .. currentTime .. " o'clock in yieldIfTooLong")
  local timeSpent = currentTime - self.startTime
  -- conservatively, give PA up to half a frame (8.3ms) on the locked 60 FPS update rate to do its things
  -- and use the rest for the CPU calcs
  if timeSpent > 0.083 then
    CpuLog:log(6, "Computer - timeSpent " .. round(timeSpent, 4) .. ", resuming thinking later")
    self.yieldCount = (self.yieldCount or 0) + 1
    coroutine.yield()
    self.startTime = os.clock()
  end
end

function EndarisCpu.getInput(self)
    local ok, errorMsg = coroutine.resume(self.thinkRoutine, self)
    if not ok then
      error(errorMsg .. "\n" .. debug.traceback(self.thinkRoutine) .. "\n" .. debug.traceback(mainloop))
    end

     if self:readyToInput() then
         return self:input()
     else
        return Input.EncodedWait()
     end
end

function EndarisCpu.readyToInput(self)
    --the conditions are intentional so that the control flow (specifically the exits) is more obvious rather than having a tail of "else return" where you can't tell where it's coming from
    if not self.cpuStack then
        return false
    else --there is a stack, most basic requirement
        if not self.inputQueue or #self.inputQueue == 0 then
            return false
        else --there is actually something to execute
            if self.realStack.countdown_timer and self.realStack.countdown_timer > 0 and not Input.isMovement(self.inputQueue[1]) then
                return false
            else --either we're just moving or countdown is already over so we can actually do the thing
                return self.realStack.CLOCK > 180 - self.config.MoveSwapRateLimit
            end
        end
    end
end

function EndarisCpu.input(self)
    local nextInput = table.remove(self.inputQueue, 1)
    if nextInput.executionFrame <= self.realStack.CLOCK then
        if nextInput.name == 'WaitTimeSpan' and nextInput.to > self.realStack.CLOCK then
            -- still need that one
            table.insert(self.inputQueue, 1, nextInput)
        end
        self.lastInput = nextInput
        CpuLog:log(2, 'executing ' .. self.lastInput:toString())
        return nextInput:getEncoded()
    else
        -- not time to execute that input yet, put it back into the table
        CpuLog:log(2, 'executing Wait')
        table.insert(self.inputQueue, 1, nextInput)
        return Input.EncodedWait()
    end
end

function EndarisCpu.finalizeCurrentAction(self)
    CpuLog:log(2, 'finalizing action ' .. self.currentAction.name)

    -- action is now fully wrapped up
    self.currentAction = nil
end

function EndarisCpu.getPostActionWaitTime(self)
    local waitFrames = 0

    if self.currentAction.popsPanels then
        if self.config.ReadingBehaviour == 'WaitAll' then
            -- constant for completing a swap, see Panel.clear() for reference
            waitFrames = waitFrames + 4
            -- wait for all panels to pop
            waitFrames = waitFrames + level_to_flash[self.cpuStack.level]
            waitFrames = waitFrames + level_to_face[self.cpuStack.level]
            --the first panel is popped at the end of the face part so there's only additional waiting time for each panel beyond the first
            for i = 1, #self.currentAction.panels do
                waitFrames = waitFrames + level_to_pop[self.cpuStack.level]
            end

            -- wait for other panels to fall
            waitFrames = waitFrames + level_to_hover[self.cpuStack.level]
            -- this is overly simplified, assuming that all the panels in the action are vertically stacked, meaning this might overshoot the waiting time
            waitFrames = waitFrames + #self.currentAction.panels

            -- 2 frames safety margin cause i'm still finding completed matches
            waitFrames = waitFrames + 2
        elseif self.config.ReadingBehaviour == 'WaitMatch' then
            -- constant for completing a swap, see Panel.clear() for reference
            waitFrames = 4
        --else  cpu.config["ReadingBehaviour"] == "Instantly", default behaviour
        --  waitFrames = 0
        end
    end

    return waitFrames
end

Strategy = class(function(strategy, name, cpu)
    strategy.name = name
    strategy.cpu = cpu
end)

function Strategy.chooseAction(self)
    error("Method chooseAction of strategy " .. self.name .. " has not been implemented.")
end


function EndarisCpu.chooseAction(self)
    if #self.actionQueue > 0 then
        local action = table.remove(self.actionQueue, 1)
        CpuLog:log(1, "Taking action out of the actionQueue")
        CpuLog:log(1, "Setting the current action to " .. action:toString())
        self.currentAction = action
        if not self.currentAction.executionPath or #self.currentAction.executionPath == 0 then
            self.currentAction:calculateExecution(self.cpuStack.cursorPos)
        end
    else
      self:executeStrategy()
    end
      
    if self.currentAction then
      self:assignExecutionFramesToAction(self.currentAction)
      self:appendToInputQueue(self.currentAction)
      self:appendToSimulationQueue(self.currentAction)
    else
        CpuLog:log(1, 'chosen action is nil')
    end
end

-- function serves to actually assign executiontimes to the inputs
function EndarisCpu.assignExecutionFramesToAction(self, action)
    if #action.executionPath == 0 then
        return
    end
    CpuLog:log(3, "entering function assignExecutionTimesToAction")

    local lastInput = nil

    if #self.inputQueue > 0 then
        lastInput = self.inputQueue[#self.inputQueue]
    else
        lastInput = self.lastInput
    end

    -- first determine the earliest possible input based on the last input
    local executionFrame = 0
    if action.executionPath[1].isMovement() and (lastInput == nil or lastInput.isMovement()) then
        executionFrame = math.max(lastInput.executionFrame + self.config.MoveRateLimit, (self.realStack.CLOCK or 0)) + self:getPostActionWaitTime()
    else
        executionFrame = math.max(lastInput.executionFrame + self.config.MoveSwapRateLimit, (self.realStack.CLOCK or 0)) + self:getPostActionWaitTime()
    end

    CpuLog:log(3, "setting executionframe for first input to " .. executionFrame)
    action.executionPath[1] = Input(action.executionPath[1].bit, executionFrame)

    -- base all the others consecutively on the first executionFrame
    for i=2,#action.executionPath do
        local lastExecutionFrame = action.executionPath[i-1].tillFrame

        if action.executionPath[i-1].name == "Wait" or action.executionPath[i].name == "Wait" then
            executionFrame = lastExecutionFrame + 1
        elseif action.executionPath[i-1].isMovement() and action.executionPath[i].isMovement() then
            executionFrame = lastExecutionFrame + self.config.MoveRateLimit
        else
            executionFrame = lastExecutionFrame + self.config.MoveSwapRateLimit
        end

        if action.executionPath[i].tillFrame and action.executionPath[i].tillFrame > action.executionPath[i].executionFrame then
            local duration = action.executionPath[i].tillFrame - action.executionPath[i].executionFrame
            action.executionPath[i] = Input(action.executionPath[i].bit, executionFrame, executionFrame + duration)
        else
            action.executionPath[i] = Input(action.executionPath[i].bit, executionFrame)
        end
    end
end

function EndarisCpu.appendActionToQueue(queue, action)
    for i=1,#action.executionPath do
        CpuLog:log(3, "Inserting following input into the queue: ")
        CpuLog:log(3, action.executionPath[i]:toString())
        queue[#queue + 1] =  action.executionPath[i]
    end
end

function EndarisCpu.appendToInputQueue(self, action)
  CpuLog:log(1, "appending action to inputQueue: " .. action:toString())
  EndarisCpu.appendActionToQueue(self.inputQueue, action)
end

function EndarisCpu.appendToSimulationQueue(self, action)
  CpuLog:log(1, "appending action to simulationQueue: " .. action:toString())
  EndarisCpu.appendActionToQueue(self.simulationQueue, action)
end

function EndarisCpu.chooseStrategy(self)
    if not self.cpuStack or not self.cpuStack.panels then
        return Attack(self)
    else
        print(Puzzle.toPuzzleString(self.cpuStack.panels))
    end

    local garbagePanels = StackExtensions.getGarbageByPanels(self.cpuStack.panels)
    if #garbagePanels > 0 then
        return Defend(self)
    end

    local fragmentationPercentage = StackExtensions.getFragmentationPercentageByPanels(self.cpuStack.panels)
    CpuLog:log(1, 'Fragmentation % is ' .. fragmentationPercentage)
    if fragmentationPercentage > self.config.DefragmentationPercentageThreshold then
        return Defragment(self)
    end

    return Attack(self)
end

function EndarisCpu.executeStrategy(self)
  local actions
  actions = self.strategy:chooseAction()

  if actions == nil and self.strategy.name == "Defend" then
    -- check if it wouldn't be better to defrag now so that one may get into a defendable position again
    if StackExtensions.getFragmentationPercentageByPanels(self.cpuStack.panels)
                          > self.config.DefragmentationPercentageThreshold * 0.5 then
      CpuLog:log(1, "found no action to defend")
      self.strategy = Defragment(self)
    end
    actions = self.strategy:chooseAction()
  end

  -- let the cpu do something if it can't find a sensible action for defrag/defend
  if actions == nil and self.strategy.name ~= "Attack" then
    CpuLog:log(1, "found no action to  " .. self.strategy.name)
    self.strategy = Attack(self)
    actions = self.strategy:chooseAction()
  end

  if actions and #actions > 0 then
    if not self.currentAction then
        CpuLog:log(1, "setting the current action to " .. actions[1]:toString())
        self.currentAction = table.remove(actions, 1)
    end

    for i=1,#actions do
        EndarisCpu.appendActionToQueue(self.actionQueue, actions[i])
    end
  else
    CpuLog:log(1, "executeStrategy failed, couldn't find an action")
  end

end

function EndarisCpu.simulatePostActionStack(self)
  -- get a valid inputbuffer sequence from self.simulationQueue
  -- assign it to the stack
  -- let it run
  CpuLog:log(1, "running simulatePostActionStack")
  local frameCount = self.cpuStack.CLOCK - self.yieldCount
  local inputs = {}
  CpuLog:log(1, "self.stack.CLOCK: " .. self.cpuStack.CLOCK)
  CpuLog:log(1, "self.yieldCount: " .. self.yieldCount)

  for i=1, #self.simulationQueue do
    CpuLog:log(1, "adding " .. self.simulationQueue[i]:toString() .. " to inputbuffer")
    
    local waitFrameCount = math.max(self.simulationQueue[i].executionFrame - frameCount - 1, 0)
    
    CpuLog:log(1, "waitFrameCount: " .. waitFrameCount)
    for j=1, waitFrameCount do
      inputs[#inputs+1] = Input.EncodedWait()
    end
    
    frameCount = self.simulationQueue[i].executionFrame
    if self.simulationQueue[i].name == "Wait" then
      while frameCount <= self.simulationQueue[i].tillFrame do
        frameCount = frameCount + 1
        inputs[#inputs+1] = Input.EncodedWait()
      end
    else
      inputs[#inputs+1] = self.simulationQueue[i]:getEncoded()
    end
    -- adding waitFrames at the end to make sure that the final swap completes before reading the stack again
    inputs[#inputs+1] = "AA"
  end

  local inputbuffer = table.concat(inputs)
  
  CpuLog:log(1, "inputbuffer:" .. inputbuffer)
  CpuLog:log(1, "CLOCK local stack before running inputs " .. self.cpuStack.CLOCK)
  CpuLog:log(1, StackExtensions.AsAprilStack(self.cpuStack))
  self.cpuStack.input_buffer = inputbuffer
  while self.cpuStack.input_buffer:len() > 0 do
    self.cpuStack:setupInput()
    -- stack ceases running if the game ended in any way so we need to avoid getting stuck in a deathloop
    if not self.cpuStack:simulate() then
      self.cpuStack.input_buffer = ""
    end
  end
  CpuLog:log(1, "CLOCK local stack after running inputs " .. self.cpuStack.CLOCK)
  CpuLog:log(1, StackExtensions.AsAprilStack(self.cpuStack))

  local lookAheadCopy = StackExtensions.copyStack(self.cpuStack)
  table.insert(self.lookAheadSnapShots, #self.lookAheadSnapShots + 1, lookAheadCopy)
  self.simulationQueue = {}
end


ActionPanel =
    class(
    function(actionPanel, panel, row, column)
        actionPanel.panel = panel
        actionPanel.id = panel.id
        actionPanel.color = panel.color
        actionPanel.vector = GridVector(row, column)
        actionPanel.targetVector = nil
        actionPanel.cursorStartPos = nil
        actionPanel.isSetupPanel = false
        actionPanel.isExecutionPanel = false
        actionPanel.isSwappable = not panel:exclude_swap()
    end
)

function ActionPanel.toString(self)
    local message = 'panel ' .. self.id .. ' with color ' .. self.color
    if self.vector then
        message = message .. ' at coordinate ' .. self.vector:toString()
    end
    
    if self.targetVector then
        message = message .. ' with targetVector ' .. self.targetVector:toString()
    end
    return message
end

function ActionPanel.copy(self)
    local panel = ActionPanel(self.panel, self.vector.row, self.vector.column)
    if self.cursorStartPos then
        panel.cursorStartPos = GridVector(self.cursorStartPos.row, self.cursorStartPos.column)
    end
    if self.targetVector then
        panel.targetVector = GridVector(self.targetVector.row, self.targetVector.column)
    end
    return panel
end

function ActionPanel.needsToMove(self)
    return not self.vector:equals(self.targetVector)
end

function ActionPanel.equals(self, otherPanel)
    return self.id == otherPanel.id
end

function ActionPanel.setVector(self, vector)
  self.vector = vector
end

function ActionPanel.row(self)
  return self.vector.row
end

function ActionPanel.column(self)
  return self.vector.column
end

function ActionPanel.setColumn(self, column)
  self.vector = GridVector(self.vector.row, column)
end

function ActionPanel.setRow(self, row)
  self.vector = GridVector(row, self.vector.column)
end

function ActionPanel.isMatchable(self)
  return self.color ~= 0 and self.color ~= 9
end

function ActionPanel.getState(self)
  return self.panel.state
end
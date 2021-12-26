require("computerPlayers.EndarisCpu.StackExtensions")
require("computerPlayers.EndarisCpu.GridVector")
require("computerPlayers.EndarisCpu.CpuInput")
require("computerPlayers.EndarisCpu.Helpers")
require("computerPlayers.EndarisCpu.Actions")
require("computerPlayers.EndarisCpu.Attack")
require("computerPlayers.EndarisCpu.Defense")
require("computerPlayers.EndarisCpu.Defragmentation")

CpuLog = nil

local cpuConfigs = {
    ['DevConfig'] = {
        ReadingBehaviour = 'WaitAll',
        Log = 3,
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
    self.stack = nil
    self.enable_stealth = true
    self.enable_inserts = true
    self.enable_slides = false
    self.enable_catches = false
    self.enable_doubleInsert = false
    self.lastInput = Input.WaitTimeSpan(-180, -170)
    self.lastInputTime = -180
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
    self.config.MoveRateLimit = round(config['MoveRateLimit'] / 60, 3)
    self.config.MoveSwapRateLimit = round(config['MoveSwapRateLimit'] / 60, 3)
    self.config.DefragmentationPercentageThreshold = config['DefragmentationPercentageThreshold']
end

function EndarisCpu.updateStack(self, stack)
    if stack then
        if self.stack == nil then
            self.stack = StackExtensions.copyStack(stack)
            self:initializeCoroutine()
        else
            -- compare stack with self.stack at the projected time
            if not StackExtensions.stacksAreEqual(self.stack, stack) then
                -- discard queued actions in favor of recalculation
                self.actionQueue = {}
                self.stack = StackExtensions.copyStack(stack)
                self:initializeCoroutine()
            end
        end
    end
end

function EndarisCpu.initializeCoroutine(self)
    self.thinkRoutine = coroutine.create(self.think)
end

function EndarisCpu.think(self)
    self.startTime = os.clock()
    CpuLog:log(3, "starting coroutine at " .. self.startTime)

    -- Never terminate the coroutine
    while true do
        local gameResult = self.stack:gameResult()

        --this means the game is still in progress
        if gameResult == nil then
            if self.stack and #self.inputQueue == 0 then
                if self.currentAction then
                    self:finalizeCurrentAction()
                end
        
                if #self.actionQueue == 0 then
                    self.strategy = self:chooseStrategy()
                    self:yieldIfTooLong()
                    self.actions = StackExtensions.findActions(self.stack)
                    self:yieldIfTooLong()
                    self:calculateCosts()
                    self:yieldIfTooLong()
                    -- discard actions that aren't reasonably possible to execute:
                    for i=#self.actions,1,-1 do
                        if not StackExtensions.actionIsValid(self.stack, self.actions[i]) then
                            table.remove(self.actions, i)
                        end
                    end
                    self:yieldIfTooLong()
                end
                self:chooseAction()
                -- to avoid having to reinitialise the coroutine a stack projection is generated that holds...
                -- ...anticipated future snapshots of the stack that can be compared...
                -- ... to the updates received from the game to see if all happened according to expectations
                --self:projectPostActionStack()
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
    coroutine.yield()
    self.startTime = os.clock()
  end
end

function EndarisCpu.getInput(self)
    local ok, errorMsg = coroutine.resume(self.thinkRoutine, self)
    if not ok then
        error(errorMsg)
    end

    --the conditions are intentional so that the control flow (specifically the exits) is more obvious rather than having a tail of "else return" where you can't tell where it's coming from
    if not self.stack then
        return Input.EncodedWait()
    else --there is a stack, most basic requirement
        if not self.inputQueue or #self.inputQueue == 0 then
            return Input.EncodedWait()
        else --there is actually something to execute
            if self.stack.countdown_timer and self.stack.countdown_timer > 0 and not Input.isMovement(self.inputQueue[1]) then
                return Input.EncodedWait()
            else --either we're just moving or countdown is already over so we can actually do the thing
                return self:input()
            end
        end
    end
end

function EndarisCpu.input(self)
    local nextInput = table.remove(self.inputQueue, 1)
    if nextInput.executionFrame <= (os.clock() or 0) then
        self.lastInput = nextInput
        self.lastInputTime = (os.clock() or 0)
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
            waitFrames = waitFrames + level_to_flash[self.stack.level]
            waitFrames = waitFrames + level_to_face[self.stack.level]
            --the first panel is popped at the end of the face part so there's only additional waiting time for each panel beyond the first
            for i = 1, #self.currentAction.panels do
                waitFrames = waitFrames + level_to_pop[self.stack.level]
            end

            -- wait for other panels to fall
            waitFrames = waitFrames + level_to_hover[self.stack.level]
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

    return waitFrames / 60
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
        CpuLog:log(1, action:toString())
        self.currentAction = action
        if not self.currentAction.executionPath or #self.currentAction.executionPath == 0 then
            self.currentAction:calculateExecution(self.stack.cur_row, self.stack.cur_col)
        end
        self:appendToInputQueue(self.currentAction)
    else
        self.strategy:chooseAction()
    end

    if self.currentAction then
        CpuLog:log(1, 'chose following action')
        CpuLog:log(1, self.currentAction:toString())
        self:appendToInputQueue(self.currentAction)
    else
        CpuLog:log(1, 'chosen action is nil')
    end
end

-- function serves to actually assign executiontimes to the inputs
function EndarisCpu.assignExecutionFramesToAction(self, action)
    assert(#action.executionPath > 0)
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
        executionFrame = math.max(lastInput.executionFrame + self.config.MoveRateLimit, (os.clock() or 0)) + self:getPostActionWaitTime()
    else
        executionFrame = math.max(lastInput.executionFrame + self.config.MoveSwapRateLimit, (os.clock() or 0)) + self:getPostActionWaitTime()
    end

    CpuLog:log(3, "setting executionframe for first input to " .. executionFrame)
    action.executionPath[1] = Input(action.executionPath[1].bit, executionFrame)

    -- base all the others consecutively on the first executionFrame
    for i=2,#action.executionPath do
        local lastExecutionFrame = action.executionPath[i-1].executionFrame
        executionFrame = 0
        if action.executionPath[i-1].isMovement() and action.executionPath[i].isMovement() then
            executionFrame = lastExecutionFrame + self.config.MoveRateLimit
        else
            executionFrame = lastExecutionFrame + self.config.MoveSwapRateLimit
        end
        action.executionPath[i] = Input(action.executionPath[i].bit, executionFrame)
    end
end

function EndarisCpu.appendToInputQueue(self, action)
    CpuLog:log(1, action:toString())
    self:assignExecutionFramesToAction(action)
    for i=1,#action.executionPath do
        CpuLog:log(3, "Inserting following input into the inputQueue: ")
        CpuLog:log(3, action.executionPath[i]:toString())
        table.insert(self.inputQueue, #self.inputQueue + 1, action.executionPath[i])
    end
end

function EndarisCpu.chooseStrategy(self)
    if not self.stack or not self.stack.panels then
        return Attack(self)
    else
        StackExtensions.printAsAprilStack(self.stack)
    end

    if self.stack.danger_music then
        --return Defend(self) 
        --for testing
        return Defragment(self)
    end

    local fragmentationPercentage = StackExtensions.getFragmentationPercentage(self.stack)
    CpuLog:log(1, 'Fragmentation % is ' .. fragmentationPercentage)
    if fragmentationPercentage > self.config.DefragmentationPercentageThreshold then
        CpuLog:log(1, "Chose Defragment as strategy!")
        return Defragment(self)
    end

    return Attack(self)
end

function EndarisCpu.calculateCosts(self)
    for i = 1, #self.actions do
        self.actions[i]:calculateCost()
    end
end

function EndarisCpu.estimateCost(self, action)
    --dummy value for testing purposes
    --self.stack.cursor_pos
    action.estimatedCost = 1
end


ActionPanel =
    class(
    function(actionPanel, id, color, row, column)
        actionPanel.id = id
        actionPanel.color = color
        actionPanel.row = row
        actionPanel.column = column
        actionPanel.vector = GridVector(row, column)
        actionPanel.targetVector = nil
        actionPanel.cursorStartPos = nil
        actionPanel.isSetupPanel = false
        actionPanel.isExecutionPanel = false
        -- add a reference to the original panel to track state etc.
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
    local panel = ActionPanel(self.id, self.color, self.row, self.column)
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
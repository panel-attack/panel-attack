require("computerPlayers.EndarisCpu.StackExtensions")
require("computerPlayers.EndarisCpu.GridVector")
require("computerPlayers.EndarisCpu.CpuInput")
require("computerPlayers.EndarisCpu.Helpers")
require("computerPlayers.EndarisCpu.Actions")
require("computerPlayers.EndarisCpu.Attack")
require("computerPlayers.EndarisCpu.Defense")
require("computerPlayers.EndarisCpu.Defragmentation")



local cpuConfigs = {
    ['DevConfig'] = {
        ReadingBehaviour = 'WaitAll',
        Log = true,
        MoveRateLimit = 5,
        MoveSwapRateLimit = 10,
        DefragmentationPercentageThreshold = 0.3
    },
    ['DummyTestOption'] = {
        ReadingBehaviour = 'WaitAll',
        Log = false,
        MoveRateLimit = 40,
        MoveSwapRateLimit = 40,
        DefragmentationPercentageThreshold = 0.3
    }
}

EndarisCpu = class(function(self)
    self.name = "EndarisCpu"
    self.panelsChanged = false
    self.cursorChanged = false
    self.actions = {}
    self.currentAction = nil
    self.actionQueue = {}
    self.inputQueue = {}
    self.idleFrames = 0
    self.waitFrames = 0
    self.stack = nil
    self.enable_stealth = true
    self.enable_inserts = true
    self.enable_slides = false
    self.enable_catches = false
    self.enable_doubleInsert = false
    self.lastInput = nil
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
    self.config.ReadingBehaviour = config['ReadingBehaviour']
    self.config.Log = config['Log']
    self.config.MoveRateLimit = config['MoveRateLimit']
    self.config.MoveSwapRateLimit = config['MoveSwapRateLimit']
    self.config.DefragmentationPercentageThreshold = config['DefragmentationPercentageThreshold']
end

function EndarisCpu.getInput(self)
    --the conditions are intentional so that the control flow (specifically the exits) is more obvious rather than having a tail of "else return" where you can't tell where it's coming from
    if not self.stack then
        return self:idle()
    else --there is a stack, most basic requirement
        if not self.inputQueue or #self.inputQueue == 0 then
            cpuLog("a")
            return self:idle()
        else --there is actually something to execute
            if self.stack.countdown_timer and self.stack.countdown_timer > 0 and not isMovement(self.inputQueue[1]) then
                cpuLog("b")
                return self:idle()
            else --either we're just moving or countdown is already over so we can actually do the thing
                if isMovement(self.lastInput) and isMovement(self.inputQueue[1]) then
                    if self.idleFrames < self.config.MoveRateLimit then
                        cpuLog("c")
                        return self:idle()
                    else
                        cpuLog("d")
                        return self:input()
                    end
                else
                    if self.idleFrames < self.config.MoveSwapRateLimit then
                        cpuLog("e")
                        return self:idle()
                    else
                        cpuLog("f")
                        return self:input()
                    end
                end
            end
        end
    end
end

function EndarisCpu.idle(self)
    if not self.idleFrames then
        self.idleFrames = 0
    else
        self.idleFrames = self.idleFrames + 1
    end

    return base64encode[1]
end

function EndarisCpu.input(self)
    self.lastInput = table.remove(self.inputQueue, 1)
    cpuLog('executing input ' .. self.lastInput)
    self.idleFrames = 0
    return base64encode[self.lastInput + 1]
end

function EndarisCpu.updateStack(self, stack)
    self.stack = stack
    self:evaluate()
end

function EndarisCpu.evaluate(self)
    if self.stack and #self.inputQueue == 0 then
        if self.currentAction then
            self:finalizeCurrentAction()
        end

        if self.waitFrames <= 0 then
            if #self.actionQueue == 0 then
                -- this part should go into a subroutine later so that calculations can be done over multiple frames
                self.strategy = self:chooseStrategy()
                self.actions = StackExtensions.findActions(self.stack)
                self:calculateCosts()
            end
            self:chooseAction()
        else
            self.waitFrames = self.waitFrames - 1
        end
    end
end

function EndarisCpu.finalizeCurrentAction(self)
    local waitFrames = 0
    cpuLog('finalizing action ' .. self.currentAction.name)
    cpuLog('ReadingBehaviour config value is ' .. self.config.ReadingBehaviour)

    if self.currentAction.panels then
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
    else
        -- no panels -> must be a raise, 10 is a number found through experimentation when the raise is reliably completed
        -- otherwise the cpu won't detect the rais in time and try to raise again so you get a double raise
        waitFrames = 10
    end

    cpuLog('setting waitframes to ' .. waitFrames)
    self.waitFrames = waitFrames

    -- action is now fully wrapped up
    self.currentAction = nil
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
        cpuLog("Taking action out of the actionQueue")
        action:print()
        self.currentAction = action
        if not self.currentAction.executionPath or #self.currentAction.executionPath == 0 then
            self.currentAction:calculateExecution(self.stack.cur_row, self.stack.cur_col)
        end
        self.inputQueue = self.currentAction.executionPath
    else
        self.strategy:chooseAction()
    end

    if self.currentAction then
        cpuLog('chose following action')
        self.currentAction:print()
        self.inputQueue = self.currentAction.executionPath
    else
        cpuLog('chosen action is nil')
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
    cpuLog('Fragmentation % is ' .. fragmentationPercentage)
    if fragmentationPercentage > self.config.DefragmentationPercentageThreshold then
        cpuLog("Chose Defragment as strategy!")
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

function ActionPanel.print(self)
    local message = 'panel ' .. self.id .. ' with color ' .. self.color 
    if self.vector then
        message = message .. ' at coordinate ' .. self.vector:toString()
    end
    
    if self.targetVector then
        message = message .. ' with targetVector ' .. self.targetVector:toString()
    end
    cpuLog(message)
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
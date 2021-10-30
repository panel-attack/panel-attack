cpu_configs = {
    ["DevConfig"] =
    {
        ReadingBehaviour =  "WaitAll",
        Log = true,
        MoveRateLimit = 15,
        MoveSwapRateLimit = 25,
    },
    ["DummyTestOption"] =
    {
        ReadingBehaviour =  "WaitAll",
        Log = false,
        MoveRateLimit = 40,
        MoveSwapRateLimit = 40,
    }
}

local active_cpuConfig = cpu_configs[1]

CPUConfig = class(function(cpuConfig, actualConfig)
    cpuConfig.ReadingBehaviour = actualConfig["ReadingBehaviour"]
    cpuConfig.Log = actualConfig["Log"]
    cpuConfig.MoveRateLimit = actualConfig["MoveRateLimit"]
    cpuConfig.MoveSwapRateLimit = actualConfig["MoveSwapRateLimit"]
end)


ComputerPlayer = class(function(self)
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
    if active_cpuConfig then
        print("cpu config successfully loaded")
        self.config = CPUConfig(active_cpuConfig)
        print_config(active_cpuConfig)
    else
        error("cpu config is nil")
    end
end)

local wait = 0
--inputs directly as variables cause there are no input devices
local right = 1
local left = 2
local down = 4
local up = 8
local swap = 16
local raise = 32
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
    if input then
        return input > 0 and input < 16
    else --only relevant for the very first input
        return true
    end
end

function ComputerPlayer.getInput(self, stack)
    --the conditions are intentional so that the control flow (specifically the exits) is more obvious rather than having a tail of "else return" where you can't tell where it's coming from
    if not stack then
        return self:idle()
    else    --there is a stack, most basic requirement
        if not self.inputQueue or #self.inputQueue == 0 then
            return self:idle()
        else --there is actually something to execute
            if stack.countdown_timer and stack.countdown_timer > 0 and not self:isMovement(self.inputQueue[1]) then
                return self:idle()
            else --either we're just moving or countdown is already over so we can actually do the thing
                if self:isMovement(self.lastInput) and self:isMovement(self.inputQueue[1]) then
                    if self.idleFrames < self.config.MoveRateLimit then
                        return self:idle()
                    else
                        return self:input()
                    end
                else
                    if self.idleFrames < self.config.MoveSwapRateLimit then
                        return self:idle()
                    else
                        return self:input()
                    end
                end
            end
        end
    end
end

function ComputerPlayer.idle(self)
    if not self.idleFrames then
        self.idleFrames = 0
    else
        self.idleFrames = self.idleFrames + 1
    end
    --cpuLog("#self.inputQueue is " .. #self.inputQueue)
    --cpuLog("self.idleFrames is " .. self.idleFrames)
    -- cpuLog("self.moveRateLimit is " .. self.moveRateLimit)

    return base64encode[1]
end

function ComputerPlayer.input(self)
    self.lastInput = table.remove(self.inputQueue, 1)
    cpuLog("executing input " .. self.lastInput)
    self.idleFrames = 0
    return base64encode[self.lastInput + 1]
end

function ComputerPlayer.updateStack(self, stack)
    self.stack = stack
    self:evaluate()
end

function ComputerPlayer.evaluate(self)
    if #self.inputQueue == 0 then
        if self.currentAction then
            self:finalizeCurrentAction()
        end

        if self.waitFrames <= 0 then
            if #self.actionQueue == 0 then
                -- this part should go into a subroutine later so that calculations can be done over multiple frames
                self:findActions()
                self:calculateCosts()
            end
            self:chooseAction()
        else
            self.waitFrames = self.waitFrames - 1
        end
    end
end

function ComputerPlayer.finalizeCurrentAction(self)
    local waitFrames = 0
    cpuLog("finalizing action " .. self.currentAction.name)
    cpuLog("ReadingBehaviour config value is ".. self.config.ReadingBehaviour)

    if self.currentAction.panels then
        if self.config.ReadingBehaviour == "WaitAll" then
            -- constant for completing a swap, see Panel.clear() for reference
            waitFrames = waitFrames + 4
            -- wait for all panels to pop
            waitFrames = waitFrames + level_to_flash[self.stack.level]
            waitFrames = waitFrames + level_to_face[self.stack.level]
            --the first panel is popped at the end of the face part so there's only additional waiting time for each panel beyond the first
            for i=1,#self.currentAction.panels do
                waitFrames = waitFrames + level_to_pop[self.stack.level]
            end

            -- wait for other panels to fall
            waitFrames = waitFrames + level_to_hover[self.stack.level]
            -- this is overly simplified, assuming that all the panels in the action are vertically stacked, meaning this might overshoot the waiting time
            waitFrames = waitFrames + #self.currentAction.panels

            -- 2 frames safety margin cause i'm still finding completed matches
            waitFrames = waitFrames + 2
         
        elseif self.config.ReadingBehaviour == "WaitMatch" then
            -- constant for completing a swap, see Panel.clear() for reference
            waitFrames = 4
        --else  cpu.config["ReadingBehaviour"] == "Instantly", default behaviour
        --  waitFrames = 0
        end
    else
        -- no panels -> must be a raise, 10 is a number found through experimentation when the raise is reliably completed
        -- otherwise the cpu will spam so much that you get a double raise
        waitFrames = 10
    end

    cpuLog("setting waitframes to " .. waitFrames)
    self.waitFrames = waitFrames

    -- action is now fully wrapped up
    self.currentAction = nil
end

function ComputerPlayer.findActions(self)
    self.actions = {}
    local grid = self:panelsToRowGrid()
    
    --find matches, i is row, j is panel color, grid[i][j] is the amount of panels of that color in the row, k is the column the panel is in
    for j=1,#grid[1] do
        local colorConsecutiveRowCount = 0
        local colorConsecutivePanels = {}
        for i=1,#grid do
            -- horizontal 3 matches
             if grid[i][j] >= 3 then
                --fetch the actual panels
                cpuLog("found horizontal 3 match in row " .. i .. " for color " .. j)
                local panels = {}
                for k=1, #self.stack.panels[i] do
                    if self.stack.panels[i][k].color == j then
                        local actionPanel = ActionPanel(j, i, k)
                        table.insert(panels, actionPanel)
                    end
                end

                -- if there are 4 in the row, add 2 actions
                for n=1,#panels-2 do
                    local actionPanels = {}

                    table.insert(actionPanels, panels[n]:copy())
                    table.insert(actionPanels, panels[n+1]:copy())
                    table.insert(actionPanels, panels[n+2]:copy())
                    
                     --create the action and put it in our list
                    table.insert(self.actions, H3Match(actionPanels))
                end
             end
             -- vertical 3 matches
             if grid[i][j] > 0 then
                colorConsecutiveRowCount = colorConsecutiveRowCount + 1
                colorConsecutivePanels[colorConsecutiveRowCount] = {}
                for k=1, #self.stack.panels[i] do
                    if self.stack.panels[i][k].color == j then
                        local actionPanel = ActionPanel(j, i, k)
                        table.insert(colorConsecutivePanels[colorConsecutiveRowCount], actionPanel)
                    end
                end
                if colorConsecutiveRowCount >= 3 then
                    -- technically we need action for each unique combination of panels to find the best option
                    local combinations = #colorConsecutivePanels[colorConsecutiveRowCount - 2] * #colorConsecutivePanels[colorConsecutiveRowCount - 1] * #colorConsecutivePanels[colorConsecutiveRowCount]
                    cpuLog("found " ..combinations .. " combination(s) for a vertical 3 match in row " .. i-2 .. " to " .. i .. " for color " .. j)

                    for q=1,#colorConsecutivePanels[colorConsecutiveRowCount - 2] do
                        for r=1,#colorConsecutivePanels[colorConsecutiveRowCount - 1] do
                            for s=1,#colorConsecutivePanels[colorConsecutiveRowCount] do
                                local panels = {}
                                table.insert(panels, colorConsecutivePanels[colorConsecutiveRowCount - 2][q]:copy())
                                table.insert(panels, colorConsecutivePanels[colorConsecutiveRowCount - 1][r]:copy())
                                table.insert(panels, colorConsecutivePanels[colorConsecutiveRowCount][s]:copy())
                                table.insert(self.actions, V3Match(panels))
                            end
                        end
                    end
                end
                -- if colorConsecutiveRowCount >= 4 then
                --     cpuLog("found vertical 4 combo in row " .. i-3 .. " to " .. i .. " for color " .. j)
                --     table.insert(self.actions, V4Combo(colorConsecutivePanels))
                -- end
                -- if colorConsecutiveRowCount >= 5 then
                --     cpuLog("found vertical 5 combo in row " .. i-4 .. " to " .. i .. " for color " .. j)
                --     table.insert(self.actions, V5Combo(colorConsecutivePanels))
                -- end
             else
                colorConsecutiveRowCount = 0
                colorConsecutivePanels = {}
             end
         end
     end
end

function ComputerPlayer.calculateCosts(self)
    for i=1,#self.actions do
        self.actions[i]:calculateCost()
    end
end

function ComputerPlayer.estimateCost(self, action)
    --dummy value for testing purposes
    --self.stack.cursor_pos
    action.estimatedCost = 1
end

function ComputerPlayer.chooseAction(self)

    if #self.actionQueue > 0 then
        local action = table.remove(self.actionQueue, 1)
        self.currentAction = action
        self.currentAction:calculateExecution()
        self.inputQueue = self.currentAction.executionPath
    else
        for i=1,#self.actions do
            cpuLog("Action at index" .. i .. ": " ..self.actions[i].name .." with cost of " ..self.actions[i].estimatedCost)
        end

        if #self.actions > 0 then
            self.currentAction = self:getCheapestAction()
        else
            self.currentAction = Raise()
        end
    end

    cpuLog("chose following action")
    if self.currentAction then
        self.currentAction:print()
        self.inputQueue = self.currentAction.executionPath
    else
        cpuLog("chosen action is nil")
    end
end

function ComputerPlayer.getCheapestAction(self)
    local actions = {}

    if #self.actions > 0 then
        table.sort(self.actions, function(a,b)
            return a.estimatedCost < b.estimatedCost
        end)

        for i=#self.actions, 1,-1 do
            self.actions[i]:print()
            -- this is a crutch cause sometimes we can find actions that are already completed and then we choose them cause they're already...complete
            if self.actions[i].estimatedCost == 0 then
                cpuLog("actions is already completed, removing...")
                table.remove(self.actions, i)
            end
        end

        local i = 1
        while i <= #self.actions and self.actions[i].estimatedCost == self.actions[1].estimatedCost do
            self.actions[i]:calculateExecution(self.stack.cur_row, self.stack.cur_col + 0.5)
            table.insert(actions, self.actions[i])
            i = i+1
        end

        table.sort(actions, function(a,b)
            return #a.executionPath < #b.executionPath
        end)

        return actions[1]
    else
        return Raise()
    end
end

-- returns a 2 dimensional array where i is rownumber (bottom to top), index of j is panel color and value is the amount of panels of that color in the row
function ComputerPlayer.panelsToRowGrid(self)
    local panels = self.stack.panels
    self:printAsAprilStack()
    local grid = {}
    for i=1,#panels do
        grid[i] = {}
        -- always use 8: shockpanels appear on every level and we want columnnumber=color number for readability
        for j=1,8 do
            local count = 0
            for k = 1,#panels[1] do
                if panels[i][k].color == j then
                    count = count + 1
                end
            end
            grid[i][j] = count
        end
    end
    return grid
end

-- exists to avoid the case where the cpu finds an action with panels that are falling down and thus no longer in the expected location when the cursor arrives
-- may still be faulty if the panels coincidently fall into a chain
-- should be dropped once the CPU is capable of properly tracking the panels for its current action.
-- function simulatePostFallingState(panels)
--     cpuLog("simulating post falling state")
--     -- go down from top to bottom and reinsert any 0s after finding a non 0 at the top
--     cpuLog("columns = " .. #panels[1])
--     cpuLog("rows = " .. #panels)
--     for i=1,#panels[1] do
--         local panelFound = false
--         for j=#panels,1,-1 do
--             cpuLog("panel at coordinate " .. j .. "|" .. i .. " has color " .. panels[j][i].color)
--             if panels[j][i].color == 0 then
--                 if panelFound then
--                     table.remove(panels[j], i)
--                     table.insert(panels[j], 0)
--                 end
--             else
--                 panelFound = true
--             end
--         end
--     end
--     return panels
-- end

function ComputerPlayer.printAsAprilStack(self)
    if self.stack then
        local panels = self.stack.panels
        local panelString = ""
        for i=#panels,1,-1 do
            for j=1,#panels[1] do
                panelString = panelString.. (tostring(panels[i][j].color))
            end
        end
        cpuLog("april panelstring is " .. panelString)

        panelString = ""
        for i=#panels,1,-1 do
            for j=1,#panels[1] do
                if not panels[i][j].state == "normal" then
                    panelString = panelString.. (tostring(panels[i][j].color))
                end
            end
        end

        cpuLog("panels in non-normal state are " .. panelString)
    end
end

ActionPanel = class(function(actionPanel, color, row, column)
    actionPanel.color = color
    actionPanel.row = row
    actionPanel.column = column
    actionPanel.vector = GridVector(row, column)
    actionPanel.targetVector = nil
    actionPanel.cursorStartPos = nil
    actionPanel.isSetupPanel = false
    actionPanel.isExecutionPanel = false
end)

function ActionPanel.print(self)
    local message = "panel with color " .. self.color .. " at coordinate " .. self.vector:toString()
    if self.targetVector then
        message = message .. " with targetVector " .. self.targetVector:toString()
    end
    cpuLog(message)
end

function ActionPanel.copy(self)
    local panel =  ActionPanel(self.color, self.row, self.column)
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

Action = class(function(action, panels)
    action.panels = panels
    action.garbageValue = 0
    action.stackFreezeValue = 0
    action.estimatedCost = 0
    action.executionPath = nil
    action.isClear = false
    action.name = "unknown action"
end)

function Action.print(self)
    cpuLog("printing " ..self.name .. " with estimated cost of " ..self.estimatedCost)
    if self.panels then
        for i=1,#self.panels do
            self.panels[i]:print()
        end
    end

    if self.executionPath then
        for i = 1, #self.executionPath do
            cpuLog("element " .. i .." of executionpath is " ..self.executionPath[i])
        end
    end
end

function Action.getPanelsToMove(self)
    local panelsToMove = {}
    cpuLog("#self.panels has " ..#self.panels .. " panels")
    for i=1,#self.panels do
        cpuLog("printing panel with index " .. i)
        self.panels[i]:print()

        if self.panels[i]:needsToMove() then
            cpuLog("inserting panel with index " ..i .. " into the table")
            table.insert(panelsToMove, self.panels[i])
        else
            cpuLog(" panel with index " ..i .. " is already at the desired coordinate, skipping")
        end
    end

    return panelsToMove
end

function Action.sortByDistanceToCursor(self, panels, cursorVec)
    --setting the correct cursor position for starting to work on each panel here
    for i=1,#panels do
        local panel = panels[i]
        if panel.vector.column > panel.targetVector.column then
            panel.cursorStartPos = GridVector(panel.row, panel.column - 0.5)
        else
            panel.cursorStartPos = GridVector(panel.row, panel.column + 0.5)
        end
    end

    table.sort(panels, function(a, b)
        return cursorVec:distance(a.cursorStartPos) < cursorVec:distance(b.cursorStartPos)
    end)

    return panels
end

function Action.addCursorMovementToExecution(self, gridVector)
    cpuLog("adding cursor movement to the input queue with vector" ..gridVector:toString())
    --vertical movement
    if math.sign(gridVector.row) == 1 then
        for i=1,math.abs(gridVector.row) do
            table.insert(self.executionPath, down)
        end
    elseif math.sign(gridVector.row) == -1 then
        for i=1,math.abs(gridVector.row) do
            table.insert(self.executionPath, up)
        end
    else
        --no vertical movement required
    end

    --horizontal movement
    if math.sign(gridVector.column) == 1 then
        for i=1,math.abs(gridVector.column) do
            table.insert(self.executionPath, left)
        end
    elseif math.sign(gridVector.column) == -1 then
        for i=1,math.abs(gridVector.column) do
            table.insert(self.executionPath, right)
        end
    else
        --no vertical movement required
    end
end

function Action.addPanelMovementToExecution(self, gridVector)
    cpuLog("adding panel movement to the input queue with vector" ..gridVector:toString())

    -- always starting with a swap because it is assumed that we already moved into the correct location for the initial swap
    table.insert(self.executionPath, swap)
    --section needs a rework once moving panels between rows are considered
    --vertical movement
    if math.sign(gridVector.row) == 1 then
        for i=2,math.abs(gridVector.row) do
            table.insert(self.executionPath, up)
            table.insert(self.executionPath, swap)
        end
    elseif math.sign(gridVector.row) == -1 then
        for i=2,math.abs(gridVector.row) do
            table.insert(self.executionPath, down)
            table.insert(self.executionPath, swap)
        end
    else
        --no vertical movement required
    end

    --horizontal movement
    if math.sign(gridVector.column) == 1 then
        for i=2,math.abs(gridVector.column) do
            table.insert(self.executionPath, right)
            table.insert(self.executionPath, swap)
        end
    elseif math.sign(gridVector.column) == -1 then
        for i=2,math.abs(gridVector.column) do
            table.insert(self.executionPath, left)
            table.insert(self.executionPath, swap)
        end
    else
        --no vertical movement required
    end
end

function Action.calculateCost(self)
    error("calculateCost was not implemented for action " ..self.name)
end

function Action.calculateExecution(self, cursor_row, cursor_col)
    error("calculateExecution was not implemented for action " ..self.name)
end

--#region Action implementations go here

Raise = class(function(action)
    Action.init(action)
    action.name = "Raise"
    action.estimatedCost = 0
    action.executionPath = { raise, wait }
end, Action)

Match3 = class(function(action, panels)
    Action.init(action, panels)
    action.color = panels[1].color
end, Action)

function Match3.calculateExecution(self, cursor_row, cursor_col)
    cpuLog("calculating execution path for action " .. self.name)
    self:print()

    self.executionPath = {}

    local panelsToMove = self:getPanelsToMove()
    cpuLog("found " ..#panelsToMove .. " panels to move")
    -- cursor_col is the column of the left part of the cursor
    local cursorVec = GridVector(cursor_row, cursor_col)
    cpuLog("cursor vec is " ..cursorVec:toString())
    while (#panelsToMove > 0)
    do
        panelsToMove = self:sortByDistanceToCursor(panelsToMove, cursorVec)
        local nextPanel = panelsToMove[1]:copy()
        cpuLog("nextPanel cursorstartpos is " ..nextPanel.cursorStartPos:toString())
        local moveToPanelVec = cursorVec:difference(nextPanel.cursorStartPos)
        cpuLog("difference vec is " ..moveToPanelVec:toString())
        self:addCursorMovementToExecution(moveToPanelVec)
        local movePanelVec = GridVector(0, nextPanel.targetVector.column - nextPanel.vector.column)
        cpuLog("panel movement vec is " ..movePanelVec:toString())
        self:addPanelMovementToExecution(movePanelVec)
        -- update the cursor position for the next round
        cursorVec = cursorVec:substract(moveToPanelVec):add(GridVector(0, movePanelVec.column - math.sign(movePanelVec.column)))
        cpuLog("next cursor vec is " ..cursorVec:toString())
        --remove the panel we just moved so we don't try moving it again
        table.remove(panelsToMove, 1)
        cpuLog(#panelsToMove .. " panels left to move")
    end

    -- wait at the end of each action to avoid scanning the board again while the last swap is still in progress
    -- or don't cause we have waitFrames now
    --table.insert(self.executionPath, wait)
    cpuLog("exiting calculateExecution")
end

H3Match = class(function(action, panels)
    Match3.init(action, panels)
    action.name = "Horizontal 3 Match"
    action.targetRow = 0
end, Match3)

function H3Match.calculateCost(self)
    -- always pick the panel in the middle as the one that doesn't need to get moved
    local middlePanelColumn = self.panels[2].vector.column
    self.panels[1].targetVector = GridVector(self.panels[1].vector.row, middlePanelColumn - 1)
    self.panels[2].targetVector = GridVector(self.panels[2].vector.row, middlePanelColumn)
    self.panels[3].targetVector = GridVector(self.panels[3].vector.row, middlePanelColumn + 1)

    self.estimatedCost = 0
    for i=1,#self.panels do
        local distance = math.abs(self.panels[i].targetVector.column - self.panels[i].vector.column)
        if distance > 0 then
            self.estimatedCost = self.estimatedCost + 2
            self.estimatedCost = self.estimatedCost + distance
        end
    end
end

V3Match = class(function(action, panels)
    Match3.init(action, panels)
    action.name = "Vertical 3 Match"
    action.targetColumn = 0
end, Match3)

function V3Match.calculateCost(self)
    self:chooseColumn()
end

function V3Match.chooseColumn(self)
    local column
    local minCost = 1000
    for i=1,6 do
        local colCost = 0
        for j=1,#self.panels do
            --how many columns the panel is away from the column we're testing for
            local distance = math.abs(self.panels[j].column - i)
            if distance > 0 then
                --penalty for having to move to the panel to move it
                colCost = colCost + 2
                --cost for moving the panel
                colCost = colCost + distance
            end
        end
        if colCost < minCost then
            minCost = colCost
            column = i
        end
    end

    self.estimatedCost = minCost
    self.targetColumn = column
    cpuLog("chose targetColumn " ..self.targetColumn)
    cpuLog("setting target vectors for V3Match " ..self.targetColumn)
    for i=1,#self.panels do
        self.panels[i].targetVector = GridVector(self.panels[i].row, self.targetColumn)
        self.panels[i]:print()
    end
end

V4Combo = class(function(action, panels)
    action.name = "Vertical 4 Combo"
    action.color = panels[1].color
    action.panels = panels
    action.garbageValue = 0
    action.stackFreezeValue = 0
    action.estimatedCost = 0
    action.executionPath = nil
end)

V5Combo = class(function(action, panels)
    action.name = "Vertical 5 Combo"
    action.color = panels[1].color
    action.panels = panels
    action.garbageValue = 0
    action.stackFreezeValue = 0
    action.estimatedCost = 0
    action.executionPath = nil
end)

T5Combo = class(function(action, panels)
    action.name = "T-shaped 5 Combo"
    action.color = panels[1].color
    action.panels = panels
    action.garbageValue = 0
    action.stackFreezeValue = 0
    action.estimatedCost = 0
    action.executionPath = nil
end)

L5Combo = class(function(action, panels)
    action.name = "L-shaped 5 Combo"
    action.color = panels[1].color
    action.panels = panels
    action.garbageValue = 0
    action.stackFreezeValue = 0
    action.estimatedCost = 0
    action.executionPath = nil
end)

T6Combo = class(function(action, panels)
    action.name = "T-shaped 6 Combo"
    action.color = panels[1].color
    action.panels = panels
    action.garbageValue = 0
    action.stackFreezeValue = 0
    action.estimatedCost = 0
    action.executionPath = nil
end)

T7Combo = class(function(action, panels)
    action.name = "T-shaped 7 Combo"
    action.color = panels[1].color
    action.panels = panels
    action.garbageValue = 0
    action.stackFreezeValue = 0
    action.estimatedCost = 0
    action.executionPath = nil
end)

--#endregion


--#region Helper classes and functions go here

GridVector = class(function(vector, row, column)
    vector.row = row
    vector.column = column
end)

function GridVector.distance(self, otherVec)
    --since this is a grid where diagonal movement is not possible it's just the sum of both directions instead of a diagonal
    return math.abs(self.row - otherVec.row) + math.abs(self.column - otherVec.column)
end

function GridVector.difference(self, otherVec)
    return GridVector(self.row - otherVec.row, self.column - otherVec.column)
end

function GridVector.add(self, otherVec)
    return GridVector(self.row + otherVec.row, self.column + otherVec.column)
end

function GridVector.substract(self, otherVec)
    return GridVector(self.row - otherVec.row, self.column - otherVec.column)
end

function GridVector.equals(self, otherVec)
    return self.row == otherVec.row and self.column == otherVec.column
end

function GridVector.toString(self)
    return self.row .. "|" .. self.column
end

function math.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

-- a glorified print that can be turned on/off via the cpu configuration
function cpuLog(...)
    if not active_cpuConfig or active_cpuConfig["Log"] then
        print(...)
    end
end

function print_config(someConfig)
    print("print config")
    for key, value in pairs (someConfig) do
        print('\t', key, value)
    end
end

--#endregion
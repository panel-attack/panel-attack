Action =
    class(
    function(action, panels)
        action.panels = panels
        action.garbageValue = 0
        action.stackFreezeValue = 0
        action.estimatedCost = 0
        action.executionPath = nil
        action.isClear = false
        action.name = 'unknown action'
        action.moves = nil
        action.popsPanels = true
    end
)

function Action.toString(self)
    local actionString = 'printing ' .. self.name .. ' with estimated cost of ' .. self.estimatedCost
    if self.panels then
        actionString = actionString .. "\n"
        for i = 1, #self.panels do
            actionString = actionString .. self.panels[i]:toString() .. "\n"
        end
    end

    if self.executionPath then
        for i = 1, #self.executionPath do
            actionString = actionString .. 'element ' .. i .. ' of executionpath is ' .. self.executionPath[i].bit
            if self.executionPath[i].executionFrame then
                actionString = actionString .. ', scheduled to execute at frame ' .. self.executionPath[i].executionFrame
            else
                actionString = actionString .. ', execution is not scheduled yet'
            end
        end
    else
        actionString = actionString .. 'action has no executionpath'
    end

    return actionString
end

function Action.getPanelsToMove(self)
    local panelsToMove = {}
    for i = 1, #self.panels do
        CpuLog:log(6, self.panels[i]:toString())

        if self.panels[i]:needsToMove() then
            table.insert(panelsToMove, self.panels[i])
        end
    end

    return panelsToMove
end

function Action.sortByDistanceToCursor(self, panels, cursorVec)
    --setting the correct cursor position for starting to work on each panel here
    for i = 1, #panels do
        local panel = panels[i]
        self.setCursorStartPos(panel)
    end

    table.sort(
        panels,
        function(a, b)
            return cursorVec:distance(a.cursorStartPos) < cursorVec:distance(b.cursorStartPos)
        end
    )

    return panels
end

function Action.setCursorStartPos(panel, projectedCoordinate)
    local coordinate = panel.vector

    if projectedCoordinate then
        coordinate = projectedCoordinate
    end

    if coordinate.column > panel.targetVector.column then
        panel.cursorStartPos = GridVector(coordinate.row, coordinate.column - 0.5)
    else
        panel.cursorStartPos = GridVector(coordinate.row, coordinate.column + 0.5)
    end
    CpuLog:log(6, "Set cursorStartPos for panel " .. panel.id .. " to " .. panel.cursorStartPos:toString())
end

function Action.addCursorMovementToExecution(self, gridVector)
    CpuLog:log(6, 'adding cursor movement to the input queue with vector' .. gridVector:toString())
    --vertical movement
    if math.sign(gridVector.row) == 1 then
        for i = 1, math.abs(gridVector.row) do
            table.insert(self.executionPath, Input.Down())
        end
    elseif math.sign(gridVector.row) == -1 then
        for i = 1, math.abs(gridVector.row) do
            table.insert(self.executionPath, Input.Up())
        end
    else
        --no vertical movement required
    end

    --horizontal movement
    if math.sign(gridVector.column) == 1 then
        for i = 1, math.abs(gridVector.column) do
            table.insert(self.executionPath, Input.Left())
        end
    elseif math.sign(gridVector.column) == -1 then
        for i = 1, math.abs(gridVector.column) do
            table.insert(self.executionPath, Input.Right())
        end
    else
        --no vertical movement required
    end
end

function Action.addPanelMovementToExecution(self, gridVector)
    CpuLog:log(6, 'adding panel movement to the input queue with vector' .. gridVector:toString())

    -- always starting with a swap because it is assumed that we already moved into the correct location for the initial swap
    table.insert(self.executionPath, Input.Swap())
    --section needs a rework once moving panels between rows are considered
    --vertical movement
    if math.sign(gridVector.row) == 1 then
        for i = 2, math.abs(gridVector.row) do
            table.insert(self.executionPath, Input.Up())
            table.insert(self.executionPath, Input.Swap())
        end
    elseif math.sign(gridVector.row) == -1 then
        for i = 2, math.abs(gridVector.row) do
            table.insert(self.executionPath, Input.Down())
            table.insert(self.executionPath, Input.Swap())
        end
    else
        --no vertical movement required
    end

    --horizontal movement
    if math.sign(gridVector.column) == 1 then
        for i = 2, math.abs(gridVector.column) do
            table.insert(self.executionPath, Input.Right())
            table.insert(self.executionPath, Input.Swap())
        end
    elseif math.sign(gridVector.column) == -1 then
        for i = 2, math.abs(gridVector.column) do
            table.insert(self.executionPath, Input.Left())
            table.insert(self.executionPath, Input.Swap())
        end
    else
        --no vertical movement required
    end
end

function Action.calculateCost(self)
    error('calculateCost was not implemented for action ' .. self.name)
end

function Action.calculateExecution(self, cursor_row, cursor_col)
    error('calculateExecution was not implemented for action ' .. self.name)
end

function Action.equals(self, action)
    if #self.panels ~= #action.panels then
        return false
    end

    for i=1, #self.panels do
        local matched = false
        for j=1, #action.panels do
            if self.panels[i]:equals(action.panels[j]) then
                matched = true
                break
            end
        end
        if matched == false then
            return false
        end
    end

    return true
end

function Action.calculateCosts(actions, stack)
    for i=1, #actions do
        actions:calculateCost()
    end

    return actions
end

function Action.getCheapestAction(actions, stack)
    if #actions > 0 then
        table.sort(
            actions,
            function(a, b)
                return a.estimatedCost < b.estimatedCost
            end
        )

        -- TODO Endaris: technically this should already be possible to remove but the game lags as a result, research needed
        for i = #actions, 1, -1 do
            CpuLog:log(6, actions[i]:toString())
            -- this is a crutch cause sometimes we can find actions that are already completed and then we choose them cause they're already...complete
            if actions[i].estimatedCost == 0 then
                CpuLog:log(6, 'action is already completed, removing...')
                table.remove(actions, i)
            end
        end

        local i = 1
        local filteredActions = {}
        while i <= #actions and actions[i].estimatedCost == actions[1].estimatedCost do
            actions[i]:calculateExecution(stack.cur_row, stack.cur_col + 0.5)
            table.insert(filteredActions, actions[i])
            i = i + 1
        end

        table.sort(
            filteredActions,
            function(a, b)
                return #a.executionPath < #b.executionPath
            end
        )

        return filteredActions[1]
    else
        return Raise()
    end
end

--#region Action implementations go here

WaitTimeSpan =
    class(
    function(action, from, to)
        Action.init(action)
        action.name = 'WaitTimeSpan'
        action.estimatedCost = 0
        action.executionPath = { Input.WaitTimeSpan(from, to)}
        action.popsPanels = false
    end
    )

Raise =
    class(
    function(action, executionFrame)
        Action.init(action)
        action.name = 'Raise'
        action.estimatedCost = 0
        action.executionPath =
            {Input.Raise(), Input.WaitTimeSpan(0, 9)}
            -- the wait is a crutch to avoid a double raise
        action.popsPanels = false
    end,
    Action
)

MoveCursor =
    class(
        function(action, stack, targetVector)
            Action.init(action)
            action.name = "MoveCursor"
            action.stack = stack
            action.targetVector = targetVector
            action.popsPanels = false
        end
    )


function MoveCursor.calculateExecution(self, cursor_row, cursor_col)
    self.executionPath = {}
    CpuLog:log(6, "cursor_row is " .. cursor_row .. ", cursor_col is " .. cursor_col)
    local cursorVec = GridVector(cursor_row, cursor_col)
    CpuLog:log(6, "cursorVec is " .. cursorVec:toString())

    local moveToPanelVec = cursorVec:difference(self.targetVector)
    self:addCursorMovementToExecution(moveToPanelVec)
end

MovePanel =
    class(
        function(action, stack, panel, targetVector)
            Action.init(action)
            action.name = 'MovePanel'
            action.stack = stack
            action.panel = panel
            action.targetVector = targetVector
            action.panel.targetVector = targetVector
            action.popsPanels = false
        end,
        Action
    )

function MovePanel.calculateExecution(self, cursor_row, cursor_col)
    self.executionPath = {}
    CpuLog:log(6, "cursor_row is " .. cursor_row .. ", cursor_col is " .. cursor_col)
    local cursorVec = GridVector(cursor_row, cursor_col)
    CpuLog:log(6, "cursorVec is " .. cursorVec:toString())

    local generalDirection = self.panel.targetVector.column - self.panel.vector.column
    local movementVec = GridVector(0, (generalDirection / math.abs(generalDirection)) * -1)
    local projectedPos = self.panel.vector

    CpuLog:log(6, "targetVec is " .. self.panel.targetVector:toString())

    while projectedPos.column ~= self.panel.targetVector.column do
        local moveToPanelVec = cursorVec:difference(projectedPos)
        self:addCursorMovementToExecution(moveToPanelVec)
        self:addPanelMovementToExecution(movementVec)

        -- find out where the panel ended up now
        -- the result of the swap
        projectedPos = projectedPos:substract(movementVec)
        CpuLog:log(6, "ProjectedPos after swap is " .. projectedPos:toString())
        -- simulating the effect of gravity after the swap
        for r=projectedPos.row - 1,1,-1 do
            if self.stack.panels[r][projectedPos.column].color == 0 then
                projectedPos = projectedPos:substract(GridVector(1, 0))
            else
                break
            end
        end
        CpuLog:log(5, "ProjectedPos after falling is " .. projectedPos:toString())

        -- update the cursor position for the next round
        cursorVec =
        cursorVec:substract(moveToPanelVec):add(GridVector(0, movementVec.column - math.sign(movementVec.column)))
        CpuLog:log(6, 'next cursor vec is ' .. cursorVec:toString())
    end
end

Match3 =
    class(
    function(action, panels)
        Action.init(action, panels)
        action.color = panels[1].color
    end,
    Action
)

function Match3.calculateExecution(self, cursor_row, cursor_col)
    CpuLog:log(6, 'calculating execution path for action ' .. self.name)
    CpuLog:log(6, self:toString())

    self.executionPath = {}

    local panelsToMove = self:getPanelsToMove()
    CpuLog:log(6, 'found ' .. #panelsToMove .. ' panels to move')
    -- cursor_col is the column of the left part of the cursor
    local cursorVec = GridVector(cursor_row, cursor_col)
    CpuLog:log(6, 'cursor vec is ' .. cursorVec:toString())
    while (#panelsToMove > 0) do
        panelsToMove = self:sortByDistanceToCursor(panelsToMove, cursorVec)
        local nextPanel = panelsToMove[1]:copy()
        CpuLog:log(6, 'nextPanel cursorstartpos is ' .. nextPanel.cursorStartPos:toString())
        local moveToPanelVec = cursorVec:difference(nextPanel.cursorStartPos)
        CpuLog:log(6, 'difference vec is ' .. moveToPanelVec:toString())
        self:addCursorMovementToExecution(moveToPanelVec)
        local movePanelVec = GridVector(0, nextPanel.targetVector.column - nextPanel.vector.column)
        CpuLog:log(6, 'panel movement vec is ' .. movePanelVec:toString())
        self:addPanelMovementToExecution(movePanelVec)
        -- update the cursor position for the next round
        cursorVec =
            cursorVec:substract(moveToPanelVec):add(GridVector(0, movePanelVec.column - math.sign(movePanelVec.column)))
        CpuLog:log(6, 'next cursor vec is ' .. cursorVec:toString())
        --remove the panel we just moved so we don't try moving it again
        table.remove(panelsToMove, 1)
        CpuLog:log(6, #panelsToMove .. ' panels left to move')
    end

    -- wait at the end of each action to avoid scanning the board again while the last swap is still in progress
    -- or don't cause we have waitFrames now
    --table.insert(self.executionPath, wait)
    CpuLog:log(6, 'exiting calculateExecution')
end

function Match3.getConcreteMatchesFromLatentMatch(self)
    error("didn't implement method getConcreteMatchesFromLatentMatch for " .. self.name)
end

H3Match =
    class(
    function(action, panels)
        Match3.init(action, panels)
        action.name = 'Horizontal 3 Match'
        action.targetRow = 0
    end,
    Match3
)

function H3Match.calculateCost(self)
    CpuLog:log(6, "calculating cost for action")
    CpuLog:log(6, self:toString())

    self.estimatedCost = 0
    for i = 1, #self.panels do
        local distance = math.abs(self.panels[i].targetVector.column - self.panels[i].vector.column)
        if distance > 0 then
            self.estimatedCost = self.estimatedCost + 2
            self.estimatedCost = self.estimatedCost + distance
        end
    end
end

function H3Match.getConcreteMatchesFromLatentMatch(self)
    local concreteMatches = {}

    -- need a deepcopy to have unique targetVectors
    local panels = deepcopy(self.panels, {panel=true})
    -- make sure they're in correct order for the loop
    table.sort(panels, function(a,b) return a.vector.column < b.vector.column end)

    -- assuming column index of left most panel
    for i=1,4 do
        for j=1,#panels do
            panels[j].targetVector = GridVector(panels[j].row, i + j - 1)
        end

        local newMatch = H3Match(panels)
        table.insert(concreteMatches, newMatch)
    end

    return concreteMatches
end

V3Match =
    class(
    function(action, panels)
        Match3.init(action, panels)
        action.name = 'Vertical 3 Match'
        action.targetColumn = 0
    end,
    Match3
)

function V3Match.calculateCost(self)
    CpuLog:log(6, "calculating cost for action")
    CpuLog:log(6, self:toString())
    
    self.estimatedCost = 0

    for j = 1, #self.panels do
        --how many columns the panel is away from the column we're testing for
        local distance = math.abs(self.panels[j].column - self.panels[j].targetVector.column)
        if distance > 0 then
            --penalty for having to move to the panel to move it
            self.estimatedCost = self.estimatedCost + 2
            --cost for moving the panel
            self.estimatedCost = self.estimatedCost + distance
        end
    end
end

function V3Match.getConcreteMatchesFromLatentMatch(self)
    local concreteMatches = {}
    -- for each column
    for i = 1, 6 do
        -- need a deepcopy to have unique targetVectors
        local panels = deepcopy(self.panels, {panel=true})
        -- setting targetvector to column
        for j = 1, #panels do
            panels[j].targetVector = GridVector(panels[j].row, i)
        end

        -- creating action from edited panels
        local newMatch = V3Match(panels)
        table.insert(concreteMatches, newMatch)
    end

    return concreteMatches
end

V4Combo =
    class(
    function(action, panels)
        action.name = 'Vertical 4 Combo'
        action.color = panels[1].color
        action.panels = panels
        action.garbageValue = 0
        action.stackFreezeValue = 0
        action.estimatedCost = 0
        action.executionPath = nil
    end
)

V5Combo =
    class(
    function(action, panels)
        action.name = 'Vertical 5 Combo'
        action.color = panels[1].color
        action.panels = panels
        action.garbageValue = 0
        action.stackFreezeValue = 0
        action.estimatedCost = 0
        action.executionPath = nil
    end
)

T5Combo =
    class(
    function(action, panels)
        action.name = 'T-shaped 5 Combo'
        action.color = panels[1].color
        action.panels = panels
        action.garbageValue = 0
        action.stackFreezeValue = 0
        action.estimatedCost = 0
        action.executionPath = nil
    end
)

L5Combo =
    class(
    function(action, panels)
        action.name = 'L-shaped 5 Combo'
        action.color = panels[1].color
        action.panels = panels
        action.garbageValue = 0
        action.stackFreezeValue = 0
        action.estimatedCost = 0
        action.executionPath = nil
    end
)

T6Combo =
    class(
    function(action, panels)
        action.name = 'T-shaped 6 Combo'
        action.color = panels[1].color
        action.panels = panels
        action.garbageValue = 0
        action.stackFreezeValue = 0
        action.estimatedCost = 0
        action.executionPath = nil
    end
)

T7Combo =
    class(
    function(action, panels)
        action.name = 'T-shaped 7 Combo'
        action.color = panels[1].color
        action.panels = panels
        action.garbageValue = 0
        action.stackFreezeValue = 0
        action.estimatedCost = 0
        action.executionPath = nil
    end
)
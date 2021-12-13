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
    end
)

function Action.print(self)
    cpuLog('printing ' .. self.name .. ' with estimated cost of ' .. self.estimatedCost)
    if self.panels then
        for i = 1, #self.panels do
            self.panels[i]:print()
        end
    end

    if self.executionPath then
        for i = 1, #self.executionPath do
            cpuLog('element ' .. i .. ' of executionpath is ' .. self.executionPath[i])
        end
    end
end

function Action.getPanelsToMove(self)
    local panelsToMove = {}
    cpuLog('#self.panels has ' .. #self.panels .. ' panels')
    for i = 1, #self.panels do
        cpuLog('printing panel with index ' .. i)
        self.panels[i]:print()

        if self.panels[i]:needsToMove() then
            cpuLog('inserting panel with index ' .. i .. ' into the table')
            table.insert(panelsToMove, self.panels[i])
        else
            cpuLog(' panel with index ' .. i .. ' is already at the desired coordinate, skipping')
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
    cpuLog("Set cursorStartPos for panel " .. panel.id .. " to " .. panel.cursorStartPos:toString())
end

function Action.addCursorMovementToExecution(self, gridVector)
    cpuLog('adding cursor movement to the input queue with vector' .. gridVector:toString())
    --vertical movement
    if math.sign(gridVector.row) == 1 then
        for i = 1, math.abs(gridVector.row) do
            table.insert(self.executionPath, down)
        end
    elseif math.sign(gridVector.row) == -1 then
        for i = 1, math.abs(gridVector.row) do
            table.insert(self.executionPath, up)
        end
    else
        --no vertical movement required
    end

    --horizontal movement
    if math.sign(gridVector.column) == 1 then
        for i = 1, math.abs(gridVector.column) do
            table.insert(self.executionPath, left)
        end
    elseif math.sign(gridVector.column) == -1 then
        for i = 1, math.abs(gridVector.column) do
            table.insert(self.executionPath, right)
        end
    else
        --no vertical movement required
    end
end

function Action.addPanelMovementToExecution(self, gridVector)
    cpuLog('adding panel movement to the input queue with vector' .. gridVector:toString())

    -- always starting with a swap because it is assumed that we already moved into the correct location for the initial swap
    table.insert(self.executionPath, swap)
    --section needs a rework once moving panels between rows are considered
    --vertical movement
    if math.sign(gridVector.row) == 1 then
        for i = 2, math.abs(gridVector.row) do
            table.insert(self.executionPath, up)
            table.insert(self.executionPath, swap)
        end
    elseif math.sign(gridVector.row) == -1 then
        for i = 2, math.abs(gridVector.row) do
            table.insert(self.executionPath, down)
            table.insert(self.executionPath, swap)
        end
    else
        --no vertical movement required
    end

    --horizontal movement
    if math.sign(gridVector.column) == 1 then
        for i = 2, math.abs(gridVector.column) do
            table.insert(self.executionPath, right)
            table.insert(self.executionPath, swap)
        end
    elseif math.sign(gridVector.column) == -1 then
        for i = 2, math.abs(gridVector.column) do
            table.insert(self.executionPath, left)
            table.insert(self.executionPath, swap)
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

--#region Action implementations go here

Raise =
    class(
    function(action)
        Action.init(action)
        action.name = 'Raise'
        action.estimatedCost = 0
        action.executionPath = {raise, wait}
    end,
    Action
)

Move =
    class(
        function(action, stack, panel, targetVector)
            Action.init(action)
            action.name = 'Move'
            action.stack = stack
            action.panel = panel
            action.targetVector = targetVector
            action.panel.targetVector = targetVector
        end,
        Action
    )

    function Move.calculateExecution(self, cursor_row, cursor_col)
        self.executionPath = {}
        cpuLog("cursor_row is " .. cursor_row .. ", cursor_col is " .. cursor_col)
        local cursorVec = GridVector(cursor_row, cursor_col)
        cpuLog("cursorVec is " .. cursorVec:toString())
        
        local generalDirection = self.panel.targetVector.column - self.panel.vector.column
        local movementVec = GridVector(0, (generalDirection / math.abs(generalDirection)) * -1)
        local projectedPos = self.panel.vector

        cpuLog("targetVec is " .. self.panel.targetVector:toString())

        while projectedPos.column ~= self.panel.targetVector.column do
            local moveToPanelVec = cursorVec:difference(projectedPos)
            self:addCursorMovementToExecution(moveToPanelVec)
            self:addPanelMovementToExecution(movementVec)

            -- find out where the panel ended up now
            -- the result of the swap
            projectedPos = projectedPos:substract(movementVec)
            cpuLog("ProjectedPos after swap is " .. projectedPos:toString())
            -- panel is falling down
            for r=projectedPos.row - 1,1,-1 do
                if self.stack.panels[r][projectedPos.column].color == 0 then
                    projectedPos = projectedPos:substract(GridVector(1, 0))
                else
                    break
                end
            end
            cpuLog("ProjectedPos after falling is " .. projectedPos:toString())

            -- update the cursor position for the next round
            cursorVec =
            cursorVec:substract(moveToPanelVec):add(GridVector(0, movementVec.column - math.sign(movementVec.column)))
            cpuLog('next cursor vec is ' .. cursorVec:toString())
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
    cpuLog('calculating execution path for action ' .. self.name)
    self:print()

    self.executionPath = {}

    local panelsToMove = self:getPanelsToMove()
    cpuLog('found ' .. #panelsToMove .. ' panels to move')
    -- cursor_col is the column of the left part of the cursor
    local cursorVec = GridVector(cursor_row, cursor_col)
    cpuLog('cursor vec is ' .. cursorVec:toString())
    while (#panelsToMove > 0) do
        panelsToMove = self:sortByDistanceToCursor(panelsToMove, cursorVec)
        local nextPanel = panelsToMove[1]:copy()
        cpuLog('nextPanel cursorstartpos is ' .. nextPanel.cursorStartPos:toString())
        local moveToPanelVec = cursorVec:difference(nextPanel.cursorStartPos)
        cpuLog('difference vec is ' .. moveToPanelVec:toString())
        self:addCursorMovementToExecution(moveToPanelVec)
        local movePanelVec = GridVector(0, nextPanel.targetVector.column - nextPanel.vector.column)
        cpuLog('panel movement vec is ' .. movePanelVec:toString())
        self:addPanelMovementToExecution(movePanelVec)
        -- update the cursor position for the next round
        cursorVec =
            cursorVec:substract(moveToPanelVec):add(GridVector(0, movePanelVec.column - math.sign(movePanelVec.column)))
        cpuLog('next cursor vec is ' .. cursorVec:toString())
        --remove the panel we just moved so we don't try moving it again
        table.remove(panelsToMove, 1)
        cpuLog(#panelsToMove .. ' panels left to move')
    end

    -- wait at the end of each action to avoid scanning the board again while the last swap is still in progress
    -- or don't cause we have waitFrames now
    --table.insert(self.executionPath, wait)
    cpuLog('exiting calculateExecution')
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
    cpuLog("calculating cost for action")
    self:print()

    -- always pick the panel in the middle as the one that doesn't need to get moved
    local middlePanelColumn = self.panels[2].vector.column
    self.panels[1].targetVector = GridVector(self.panels[1].vector.row, middlePanelColumn - 1)
    self.panels[2].targetVector = GridVector(self.panels[2].vector.row, middlePanelColumn)
    self.panels[3].targetVector = GridVector(self.panels[3].vector.row, middlePanelColumn + 1)

    self.estimatedCost = 0
    for i = 1, #self.panels do
        local distance = math.abs(self.panels[i].targetVector.column - self.panels[i].vector.column)
        if distance > 0 then
            self.estimatedCost = self.estimatedCost + 2
            self.estimatedCost = self.estimatedCost + distance
        end
    end
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
    cpuLog("calculating cost for action")
    self:print()
    self:chooseColumn()
end

function V3Match.chooseColumn(self)
    local column
    local minCost = 1000
    for i = 1, 6 do
        local colCost = 0
        for j = 1, #self.panels do
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
    cpuLog('chose targetColumn ' .. self.targetColumn)
    cpuLog('setting target vectors for V3Match ' .. self.targetColumn)
    for i = 1, #self.panels do
        self.panels[i].targetVector = GridVector(self.panels[i].row, self.targetColumn)
        self.panels[i]:print()
    end
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
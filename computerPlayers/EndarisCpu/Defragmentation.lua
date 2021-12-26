Defragment = class(
        function(strategy, cpu)
            Strategy.init(strategy, "Defragment", cpu)
        end,
        Strategy
)

function Defragment.chooseAction(self)
    local columns = StackExtensions.getTier1PanelsAsColumns(self.cpu.stack)
    local connectedPanelSections = StackExtensions.getTier1ConnectedPanelSections(self.cpu.stack)
    local panels = {}
    local emptySpaces = {}

    for i=1,#columns do
        for j=1,#columns[i] do
            table.insert(panels, {columns[i][j], 0})
        end
    end

    --setting up a table for the empty spaces
    local maxColHeight = 0
    for i=1,#columns do
        maxColHeight = math.max(maxColHeight, #columns[i])
    end

    for i=1,maxColHeight + 1 do
        for j=1,#columns do
            if self.cpu.stack.panels[i][j].color == 0 then
                local emptySpace = ActionPanel(self.cpu.stack.panels[i][j].id, 0, i, j)
                table.insert(emptySpaces, {emptySpace, 0})
            end
        end
    end

    for i=1,#connectedPanelSections do
        connectedPanelSections[i]:print()

        -- setting scores for panels
        for j=1,#panels do
            if panels[j][1].vector:inRectangle(connectedPanelSections[i].bottomLeftVector, connectedPanelSections[i].topRightVector) then
                panels[j][2] = panels[j][2] + connectedPanelSections[i].numberOfPanels
            end
        end
        -- setting scores for adjacent empty space
        for j=1,#emptySpaces do
            if emptySpaces[j][1].vector:adjacentToRectangle(connectedPanelSections[i].bottomLeftVector, connectedPanelSections[i].topRightVector) then
                emptySpaces[j][2] = emptySpaces[j][2] + 1
            end
        end
    end

    --debugging
    for i=1,#panels do
        --cpuLog("panel " .. panels[i][1].id .. " at coord " .. panels[i][1].vector:toString() .. " with value of " .. panels[i][2])
    end
    --debugging
    for i=1,#emptySpaces do
        --cpuLog("empty space " .. i .. " at coord " .. emptySpaces[i][1].vector:toString() .. " with value of " .. emptySpaces[i][2])
    end

    table.sort(emptySpaces, function(a, b)
        return a[2]>b[2]
    end)

    local emptySpacesToFill = { emptySpaces[1][1] }
    for i=2,#emptySpaces do
        if emptySpaces[i][2] == emptySpaces[1][2] then
            table.insert(emptySpacesToFill, emptySpaces[i][1])
        else
            break
        end
    end

    local cursorVec = GridVector(self.cpu.stack.cur_row, self.cpu.stack.cur_col)
    
    table.sort(emptySpacesToFill, function(a, b)
        return a.vector:distance(cursorVec) < b.vector:distance(cursorVec)
    end)

    local panelsToMove
    for i=1,#emptySpacesToFill do
        if (not panelsToMove or #panelsToMove == 0) then
            if #panels > 0 then
                panelsToMove = self:GetFreshPanelsToMove(panels)
            else
                -- can't continue without panels, rerun defragmentation to source new panels
                break
            end
        end

        table.sort(panelsToMove, function(a, b)
            return math.abs(a.column - emptySpacesToFill[i].column) <
                                math.abs(b.column - emptySpacesToFill[i].column) and
                                a.row >= emptySpacesToFill[i].row
        end)

        CpuLog:log(6, "Trying to fill " .. #emptySpacesToFill .. " emptySpaces with " .. #panelsToMove .. " panels")

        local panel = table.remove(panelsToMove, 1)
        CpuLog:log(1, panel:toString())
        while StackExtensions.moveIsValid(self.cpu.stack, panel.id, emptySpacesToFill[i].vector) == false do
            if #panelsToMove > 0 then
                panel = table.remove(panelsToMove, 1)
            else
                -- reached a dead end, gotta reparse and hope for the best
                -- or maybe raise if it actually deadlocks here (turns out it does)
                CpuLog:log(1, "Tried to defragment but couldn't decide to do anything")
                return
            end
        end
        local action = MovePanel(self.cpu.stack, panel, emptySpacesToFill[i].vector)
        action:calculateExecution(self.cpu.stack.cur_row, self.cpu.stack.cur_col)
        CpuLog:log(1, action:toString())

        if self.cpu.currentAction == nil then
            self.cpu.currentAction = action
        else
            table.insert(self.cpu.actionQueue, action)
        end
    end

    -- open issues with defragmenting:
    -- tries to "upstack" (bottom row) panels
    -- takes the panel instead of the closest panel from the column to downstack
    -- needs to weigh distance on top of solely panel score for the panel selection
    -- sometimes the first line of garbage panels is included in the connectedPanelSections somehow
end

function Defragment.GetFreshPanelsToMove(self, panels)
    table.sort(panels, function(a, b)
        return a[2]<b[2]
    end)

    -- need to rework this somehow to weigh distance against score
    local panelScore = panels[1][2]
    local firstPanel = table.remove(panels, 1)[1]
    local panelsToMove = { firstPanel }
    while #panels > 0 and panels[1][2] - 15 < panelScore do
        local panel = table.remove(panels, 1)[1]
        table.insert(panelsToMove, panel)
    end

    return panelsToMove
end
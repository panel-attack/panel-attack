Defend = class(
        function(strategy, cpu)
            Strategy.init(strategy, "Defend", cpu)
            CpuLog:log(1, "chose to DEFEND")
        end,
        Strategy
)

function Defend.chooseAction(self)
    local action = self:Clear()

    --[[ if not action then
        action = self:DownstackIntoClear()
    end ]]

    return action
end

function Defend.getClearActions(self, actions, stack)
    local clearActions = {}
    local garbagePanels = StackExtensions.getGarbage(stack)
    actions = self:prepareActions(actions, garbagePanels)
    for i=#actions, 1, -1 do
        CpuLog:log(1, actions[i]:toString())
        for j=1, #actions[i].panels do
            for k=1, #garbagePanels do
                if actions[i].panels[j].targetVector:isAdjacent(garbagePanels[k].vector) then
                    table.appendIfNotExists(clearActions, actions[i])
                end
            end
        end
    end

    return clearActions
end

function Defend.prepareActions(self, actions, garbagePanels)
    local potentialClears = {}
    for i = 1, #actions do
        if self:couldBeAClear(actions[i], garbagePanels) then
            table.insert(potentialClears, actions[i])
        end
    end

    for i=#potentialClears,1,-1 do
        CpuLog:log(1, "calculated cost for " .. potentialClears[i]:toString())
        potentialClears[i]:calculateExecution(self.cpu.stack.cur_row, self.cpu.stack.cur_col)
    end


    return potentialClears
end

function Defend.couldBeAClear(self, action, garbagePanels)
    for i=1, #action.panels do
        for j=1, #garbagePanels do
            if action.panels[i].vector:IsInAdjacentRow(garbagePanels[j].vector) then
                return true
            end
        end
    end
    return false
end

function Defend.Clear(self)
    if not self.cpu.actions or #self.cpu.actions == 0 then
        self.cpu.actions = StackExtensions.findActions(self.cpu.stack)
    end

    local clearActions = self:getClearActions(self.cpu.actions)

    if #clearActions > 0 then
        local action = Action.getCheapestAction(clearActions, self.cpu.stack)
        if action then
            CpuLog:log(1, "found action to defend " .. action:toString())
        end
        return action
    else
        return nil
    end
end

function Defend.DownstackIntoClear(self)
    local defragmentationPercentage = StackExtensions.getFragmentationPercentage(self.cpu.stack)
    local rowGrid

    if defragmentationPercentage > self.cpu.config.DefragmentationPercentageThreshold then
        rowGrid = RowGrid.FromStack(self.cpu.stack)
        -- TODO Endaris: get biggest connected panel section that connects directly to garbage and use that as the defense stack instead
    else
        rowGrid = RowGrid.FromStack(self.cpu.stack)
    end

    local potentialClearColors = self:getPotentialClearColors(rowGrid)
    local downstackPairs = {}
    for i=1,#potentialClearColors do
        local pairs = self:getDownstackPairs(rowGrid, potentialClearColors[i])
        table.insert(downstackPairs, {color = potentialClearColors[i], pairs = pairs})
    end

    local clearActions = {}
    for i=1,#downstackPairs do
        local simStack,downstackAction = Defend:simulateDownstackStack(downstackPairs[i])
        local simActions = StackExtensions.findActions(simStack)
        local simClearActions = self:getClearActions(simActions, simStack)
        for j=1, #simClearActions do
            simClearActions[j]:calculateExecution(simStack.cur_row, simStack.cur_col)
            table.insert(clearActions, {clearAction = simClearActions[j], downstackAction = downstackAction})
        end
    end

    if #clearActions > 0 then
        table.sort(clearActions, function(a, b)
            return #a.clearAction.executionPath + #a.downstackAction.executionPath
                    < #b.clearAction.executionPath + #b.downstackAction.executionPath
        end)

        return {clearActions[1].downstackAction, clearActions[1].clearAction}
    else
        return nil
    end
end

function Defend.getPotentialClearColors(self, rowgrid)
    local potentialColors = {}
    -- first eliminate the colors that don't even have 3 panels in the stack
    -- iterating to 8 instead of #grid[i] because 8 is shock, 9 is garbage and 10 is a helper color
    for color=1,8 do
        local colorColumn = rowgrid:GetColorColumn(color)
        if colorColumn:GetTotalPanelCount() >= 3 then
            table.insert(potentialColors, color)
        end
    end

    local stackMinimumTopRow = rowgrid:GetMinimumTopRowIndex()
    for i=#potentialColors, 1, -1 do
        local clearTopRow = self:findTopRowForColorClearOnRowGrid(rowgrid, potentialColors[i])
        if clearTopRow < stackMinimumTopRow then
            -- clear cannot possibly reach the top row even after completely flattening the stack
            table.remove(potentialColors, i)
        end
    end

    return potentialColors
end

function Defend.findTopRowForColorClearOnRowGrid(self, rowgrid, color)
    -- any 1 above 2 or 2 above 1 pattern will always yield a rowgrid in which the arrangeable vertical clear reaches at least as high of a top row as the horizontal clear
    -- even 3 above 0 if we purposely ignore that a row cannot have more than 6 panels
    -- you see this instantly, it's trivial (is what my math prof said while scribbling a ton of greek symbols at incomprehensible speed on the blackboard), so even though I can't think of a formal proof right now, just take it!
    -- therefore only vertical matches need to be considered
    local matchedColorGridColumn = Defend.getTopMostMatchStateAsColorGridRow(rowgrid, color)
    if matchedColorGridColumn then
        for row=#matchedColorGridColumn, 1, -1 do
            if matchedColorGridColumn[row].colorCount > 0 then
                return row
            end
        end
    else
        -- color is not downstackable into a match
        return nil
    end
end

function Defend.getTheoreticalDownstackInstructions(rowgrid, color)
    local colorGridColumn = StackExtensions.getRowGridColumn(rowgrid, color)
    local matchedColorGridColumn = Defend.getTopMostMatchStateAsColorGridRow(rowgrid, color)

    return StackExtensions.substractRowGridColumns(colorGridColumn, matchedColorGridColumn)
end

function Defend.getTopMostMatchStateAsColorGridRow(rowgrid, color)
    local colorGridColumn = RowGrid:GetColorColumn(color)
    local gridTopRow = StackExtensions.getTopRowWithPanelsFromRowGrid(rowgrid)
    local clearTopRow = gridTopRow

    while #table.filter(colorGridColumn.GetLatentMatches(),
        function(match) if match.type == "V" then return match.rows[3] == clearTopRow
                        else return match.row == clearTopRow end
                    end) == 0 do
        Defend.runDownRowGridColumn(colorGridColumn, clearTopRow)
        if colorGridColumn.GetCountInRow(clearTopRow) == 0 then
            -- only possible explanation is that the panel in the top row trickled down because of an empty row
            clearTopRow = clearTopRow - 1
        end
    end

    -- validate that no row has negative emptyPanels (which would make the downstack scenario categorically impossible)
    for row=clearTopRow, 1, -1 do
        if rowgrid:getEmptyPanelsCountInRow(row) < 0 then
            return nil
        end
    end

    return colorGridColumn
end

function Defend.colorGridColumnIsAMatch(colorGridColumn, topRow)
    -- horizontal in top row, yay
    if colorGridColumn[topRow].colorCount == 3 then
        return true
    end

    for row=topRow, topRow-2, -1 do
        if colorGridColumn[row].colorCount < 1 then
            return false
        end
    end

    return true
end

function Defend.runDownRowGridColumn(colorGridColumn, topRow)
    for row=topRow, topRow - 2, -1 do
        if colorGridColumn:GetCountInRow(row) == 0 then
            assert(row < topRow, "if you see this, something is very fishy here")
            colorGridColumn:DropPanel(row)
            return
        end
    end
end

function Defend.getDownstackPairs(self, rowgrid, color)
    local downstackInstructions = Defend.getTheoreticalDownstackInstructions(rowgrid, color)
    local pairs = {}

    for row=#downstackInstructions, 1, -1 do
        if downstackInstructions[row].colorDiff < 0 then
            for times = 1, downstackInstructions[row].colorDiff * -1 do
                table.insert(pairs, #pairs + 1, {panelRowOrigin = row, panelRowDestination = nil, color = color})    
            end
        elseif downstackInstructions[row].colorDiff > 0 then
            for times = 1, downstackInstructions[row].colorDiff do
                for i=1,#pairs do
                    if pairs[i].panelRowDestination == nil then
                        pairs[i].panelRowDestination = row
                        break
                    end
                end
            end
        end
    end

    return pairs
end

function Defend.simulateDownstackStack(self, downstackPairs, color)
    -- this part is absolutely horrifying

    local downstackVectors = StackExtensions.getDownstackPanelVectors(self.cpu.stack)
    local movePanelActions = {}

    for i=1,#downstackPairs do
        local panelsInOriginRow = Defend.getPanelsFilteredByColorAndRow(self.cpu.stack.panels, color, downstackPairs[i].panelRowOrigin)
        local panelsReadyToDownstackInOriginRow = Defend.getPanelsReadyToDownstack(panelsInOriginRow, downstackVectors)

        if #panelsReadyToDownstackInOriginRow >= downstackPairs[i].colorDiff * -1 then
            -- if they are equal, perfect
            -- if the former number is higher it means the following:
            -- there is more than one panel of the color in this row and more panels are already downstackable than necessary
            -- as they are in the same row they naturally cannot be in the same column
            -- as we're running a top down approach it can later be decided which column to use for downstacking, ideally based on panels to downstack further below
            -- for that reason it should not be necessary to move any panels away from the downstack columns
            
        elseif #panelsReadyToDownstackInOriginRow < downstackPairs[i].colorDiff * -1 then

            local panelCountLeftToPrep = downstackPairs[i].colorDiff * -1 - #panelsReadyToDownstackInOriginRow
            for j = 1, #panelsInOriginRow do
                if Defend.panelArrayContainsActionPanel(panelsReadyToDownstackInOriginRow, panelsInOriginRow[j]) then
                    -- already getting downstacked, there's nothing to do
                else
                    -- look for a downstack column that is not yet occupied
                    -- random thought: in the actual case that 2 panels need to be dropped from the top row (e.g. 2 0 0 1 pattern) they could also be dropped from the same column consecutively
                    -- with that in mind, doing each pair in sequence suddenly seems a lot more attractive
                end
            end
            -- need to move #downstackPairs[i].colorDiff panels onto a downstack vector
            for j = panelsReadyToDownstackInOriginRow, downstackPairs[i].colorDiff * -1 do
                local panelToDownstack = panelsInOriginRow[j]
                local downstackVectorsInRow = {}

                -- downstackVector should be in the same row (although I guess if you use a different one you would have already passed one)
                for k = 1, #downstackVectors do
                    if downstackVectors[k].row == setUpForDownstacking[j].vector.row then
                        table.insert(downstackVectorsInRow, downstackVectors[k])
                    end
                end

                if #downstackVectorsInRow == 0 then
                    -- it is impossible to downstack this panel!
                    -- the downstack into clear plan for this color needs to be discarded
                    -- this is the when the panel in question is part to of a 6 column wide connected panel section
                    -- although technically we should never get here in that case because the validity checks prior to this function should have eliminated the color as a potential clear
                    assert(false, "da heck?!")
                else
                    table.sort(downstackVectorsInRow, function(a, b)
                        return a:Distance(panelToDownstack.vector) < b:Distance(panelToDownstack.vector)
                    end)
    
                    local movePanelAction = MovePanel(self.cpu.stack, panelToDownstack, downstackVectorsInRow[1])
                    table.insert(movePanelActions, movePanelAction)
                end
            end
        end
    end

    return movePanelActions
end

function Defend.getPanelsFilteredByColorAndRow(panels, color, row)
    local filteredPanels = {}

    for column=1, #panels[row] do
        if panels[row][column].color == color then
            table.insert(filteredPanels, ActionPanel(panels[row][column], row, column))
        end
    end

    return filteredPanels
end

function Defend.getPanelsReadyToDownstack(panels, downstackPanelVectors)
    local panelsReadyToDownstack = {}

    for i=#panels, 1, -1 do
        if Defend.isOnDownstackVector(downstackPanelVectors, panels[i]) then
            table.insert(panelsReadyToDownstack, panels[i])
        end
    end

    return panelsReadyToDownstack
end

function Defend.panelArrayContainsActionPanel(array, actionPanel)
    for i=1, #array do
        if array[i].panel.id == actionPanel.panel.id then
            return true
        end
    end

    return false
end

function Defend.isOnDownstackVector(downstackVectors, actionPanel)
    for i=1, #downstackVectors do
        if downstackVectors[i]:difference(actionPanel) == GridVector(0, 0) then
            return true
        end
    end
    return false
end

function Defend.findDownstackAction(self, downstackPairs)

end



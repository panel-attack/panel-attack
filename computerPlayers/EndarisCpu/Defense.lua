Defend = class(
        function(strategy, cpu)
            Strategy.init(strategy, "Defend", cpu)
            CpuLog:log(1, "chose to DEFEND")
        end,
        Strategy
)

function Defend.chooseAction(self)
    local action = self:Clear()

    if not action then
        action = self:DownstackIntoClear()
    end

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
    local defenseStack

    if defragmentationPercentage > self.cpu.config.DefragmentationPercentageThreshold then
        defenseStack = self.cpu.stack
        -- TODO Endaris: get biggest connected panel section that connects directly to garbage and use that as the defense stack instead
    else
        defenseStack = self.cpu.stack
    end

    local rowgrid = StackExtensions.toRowGrid(defenseStack)
    local potentialClearColors = self:getPotentialClearColors(rowgrid)
    local downstackPairs = {}
    for i=1,#potentialClearColors do
        local pairs = self:getDownstackPairs(rowgrid, potentialClearColors[i])
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
    -- first eliminate the colors that don't even have 3 panels in the stack
    local potentialColors = {}
    local panelSumForColor = 0
    -- iterating to 8 instead of #grid[i] because color 9 is garbage which is included in the rowGrid to be able to calculate the empty panels per line accurately but cannot form matches
    for color=1,8 do
        for row=1,#rowgrid do
            panelSumForColor = panelSumForColor + rowgrid[row][color]
        end
        if panelSumForColor >= 3 then
            table.insert(potentialColors, color)
        end
    end

    -- measure the empty panels per row to see later how low the stack can potentially get
    local emptyPanelsCount = {}
    for row=1,#rowgrid do
        local emptyPanelsInRow = 6
        for color=1,#rowgrid[1] do
            emptyPanelsInRow = emptyPanelsInRow - rowgrid[row][color]
        end
        emptyPanelsCount[row] = emptyPanelsInRow
    end

    -- this looks kind of ugly, maybe make a RowGrid class later and wrap part of it in some Helper functions on that class
    local stackTopRow = StackExtensions.getTopRowWithPanelsFromRowGrid(rowgrid)
    for i=#potentialColors, 1, -1 do
        local topRow = self:findTopRowForColorClearOnRowGrid(rowgrid, potentialColors[i])
        if topRow < stackTopRow then
            local maxEmptyPanelsCountAbovePotentialClear = (#emptyPanelsCount - (topRow + 1)) * 6
            local emptyPanelsAbovePotentialClear = 0
            for j=topRow+1,#emptyPanelsCount do
                emptyPanelsAbovePotentialClear = emptyPanelsAbovePotentialClear + emptyPanelsCount[j]
            end
            local panelsAbovePotentialClear = maxEmptyPanelsCountAbovePotentialClear - emptyPanelsAbovePotentialClear

            local emptyPanelsAtAndBelowPotentialClear = 0
            for j=1,topRow do
                emptyPanelsAtAndBelowPotentialClear = emptyPanelsAtAndBelowPotentialClear + emptyPanelsCount[j]
            end

            if panelsAbovePotentialClear > emptyPanelsAtAndBelowPotentialClear then
                -- clear cannot possibly reach the top row even after completely flattening the stack
                table.remove(potentialColors, i)
            end
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
    local colorGridColumn = StackExtensions.getRowGridColumn(rowgrid, color)
    local gridTopRow = StackExtensions.getTopRowWithPanelsFromRowGrid(rowgrid)
    local clearTopRow = gridTopRow

    while not Defend.colorGridColumnIsAMatch(colorGridColumn) do
        Defend.runDownRowGridColumn(colorGridColumn, clearTopRow)
        if colorGridColumn[clearTopRow].colorCount == 0 then
            -- only possible explanation is that the panel in the top row trickled down because of an empty row
            clearTopRow = clearTopRow - 1
        end
    end

    -- validate that no row has negative emptyPanels (which would make the downstack scenario categorically impossible)
    for row=clearTopRow, 1, -1 do
        if colorGridColumn.emptyPanelsCount < 0 then
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
    for row=topRow, 1, -1 do
        if colorGridColumn[row].colorCount == 0 and row >= topRow - 2 then
            assert(row < topRow, "if you see this, something is very fishy here")
            colorGridColumn[row + 1].colorCount = colorGridColumn[row + 1].colorCount - 1
            colorGridColumn[row + 1].emptyPanelsCount = colorGridColumn[row + 1].emptyPanelsCount + 1
            colorGridColumn[row].colorCount = colorGridColumn[row].colorCount + 1
            colorGridColumn[row].emptyPanelsCount = colorGridColumn[row].emptyPanelsCount - 1
            return colorGridColumn
        end
    end
end

function Defend.getDownstackPairs(self, rowgrid, color)
    local downstackInstructions = Defend.getTheoreticalDownstackInstructions(rowgrid, color)
    local pairs = {}

    for row=#downstackInstructions, 1, -1 do
        if downstackInstructions[row].colorDiff < 0 then
            table.insert(pairs, #pairs + 1, {panelOrigin = row, panelDestination = nil, color = color})
        elseif downstackInstructions[row].colorDiff > 0 then
            for i=1,#pairs do
                if pairs[i].panelDestination == nil then
                    pairs[i].panelDestination = row
                    break
                end
            end
        end
    end

    return pairs
end

function Defend.simulateDownstackStack(self, downstackPairs, color)
    local prepDownstackingActions = self:preparePanelsForDownstackingActions(downstackPairs, color)
    -- this part is absolutely horrifying
end

function Defend.preparePanelsForDownstackingActions(self, downstackPairs, color)
    local downstackVectors = StackExtensions.getDownstackPanelVectors(self.cpu.stack)
    local movePanelActions = {}

    for i=1,#downstackPairs do
        local originPanels = {}
        for column=1, #self.cpu.stack.panels[downstackPairs[i].panelOrigin] do
            if self.cpu.stack.panels[downstackPairs[i].panelOrigin][column].color == downstackPairs[i].color then
                table.insert(originPanels, ActionPanel(self.cpu.stack.panels[downstackPairs[i].panelOrigin][column], downstackPairs[i].panelOrigin, column))
            end
        end

        local setUpForDownstacking = {}
        for j=#originPanels, 1, -1 do
            if Defend.isOnDownstackVector(downstackVectors, originPanels[j]) then
                local panelToDownstack = table.remove(originPanels, j)
                table.insert(setUpForDownstacking, panelToDownstack)
                downstackPairs[i].colorDiff = downstackPairs[i].colorDiff + 1
            end
        end

        if downstackPairs[i].colorDiff == 0 then
            -- perfect
        elseif downstackPairs[i].colorDiff > 0 then
            local nonDownstackVectors = StackExtensions.getNonDownstackPanelVectors(self.cpu.stack)

            -- need to move #downstackPairs[i].colorDiff panels away from a downstack vector or refrain from downstacking their specific row/column
            for j = downstackPairs[i].colorDiff, 0, -1 do
                local nonDownstackVectorsInRow = {}

                -- the point of this part is that the panel of that color does *not* change it's row so only check stuff from the same row
                for k = 1, #nonDownstackVectors do
                    if nonDownstackVectors[k].row == setUpForDownstacking[j].vector.row then
                        table.insert(nonDownstackVectorsInRow, nonDownstackVectors[k])
                    end
                end

                if #nonDownstackVectorsInRow == 0 then
                    -- there is no way to move it to a nonDownstackVector without downstacking it
                    -- remove the downstackVectors below this so that the panel can't get downstacked as a side effect of downstacking a different one
                    for k = #downstackVectors, 1, -1 do
                        local diffVec = downstackVectors[k]:difference(setUpForDownstacking[j].vector)
                        if diffVec.column == 0 and diffVec.row < 0 then
                            table.remove(downstackVectors, k)
                        end
                    end
                else
                    table.sort(nonDownstackVectorsInRow, function(a, b)
                        return a:Distance(setUpForDownstacking[j].vector) < b:Distance(setUpForDownstacking[j].vector)
                    end)

                    local movePanelAction = MovePanel(self.cpu.stack, setUpForDownstacking[j], nonDownstackVectorsInRow[1])
                    table.insert(movePanelActions, movePanelAction)
                end
            end
        elseif downstackPairs[i].colorDiff < 0 then
            -- need to move #downstackPairs[i].colorDiff panels onto a downstack vector
            for j = 0, downstackPairs[i].colorDiff do
                local panelToDownstack = originPanels[j]
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

function Defend.isOnDownstackVector(downstackVectors, actionPanel)

end

function Defend.findDownstackAction(self, downstackPairs)

end



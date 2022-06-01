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
        self.cpu.actions = StackExtensions.findActions(self.cpu.cpuStack)
    end

    local clearActions = self:getClearActions(self.cpu.actions)

    if #clearActions > 0 then
        local action = Action.getCheapestAction(clearActions, self.cpu.cpuStack)
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
        -- Rerun with full stack if that does not find anything
    elseif defragmentationPercentage == 0 then
      -- abandon ship immediately, this signifies that there is 0 potential for downstacking
      -- meaning that any available clear would have already been found by the regular clear logic
      -- for multistep solves that rely on chains / combos to stall for time while manipulating the stack shape a separate routine will likely be required somewhere down the line
      return
    else
        rowGrid = RowGrid.FromStack(self.cpu.stack)
    end

    local potentialClearColors = Defend.getPotentialClearColors(rowGrid)

    for i=#potentialClearColors, 1, -1 do
      local targetRowGrid = Defend:getTargetRowGrid(rowGrid, potentialClearColors[i])
      if targetRowGrid == nil then
        table.remove(potentialClearColors, i)
      else
        potentialClearColors[i].targetRowGrid = targetRowGrid
      end
    end

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

-- returns an array of color indices that have available latent matches that can realistically touch the garbage
-- along with the index comes a rowgridcolumn for that color that displays the highest row match for the color that has been found to determine the color as a potential clear
function Defend.getPotentialClearColors(rowgrid)
    local potentialColors = {}
    -- first eliminate the colors that don't even have 3 panels in the stack
    -- iterating to 8 instead of #grid[i] because 8 is shock, 9 is garbage and 10 is a helper color
    for color=1,8 do
        local colorColumn = rowgrid:GetColorColumn(color)
        if colorColumn:GetTotalPanelCount() >= 3 then
          potentialColors[#potentialColors+1] = { idx = color, targetGridColumn = nil}
        end
    end

    -- find out how low the stack can be stacked to
    local stackMinimumTopRow = rowgrid:GetMinimumTopRowIndex()
    for i=#potentialColors, 1, -1 do
      -- need a copy, otherwise result might get skewed by other colors already being downstacked for dry simulation
      local rowgridCopy = deepcpy(rowgrid)
      -- then use that information to determine if any match of a color can reach that top row (and thus the garbage)
        local clearTopRow = Defend.findTopRowForColorClearOnRowGrid(rowgridCopy, potentialColors[i].idx)
        if clearTopRow == nil or clearTopRow < stackMinimumTopRow then
            -- clear cannot possibly reach the top row even after completely flattening the stack
            table.remove(potentialColors, i)
        else
          potentialColors[i].targetGridColumn = rowgridCopy:GetColorColumn(potentialColors[i].idx)
        end
    end

    return potentialColors
end

function Defend.findTopRowForColorClearOnRowGrid(rowgrid, color)
    -- any 1 above 2 or 2 above 1 pattern will always yield a rowgrid in which the arrangeable vertical clear reaches at least as high of a top row as the horizontal clear:
    -- 2      1    0   1      1    0   1      0    0
    -- 1  ->  1 or 3;  2  ->  1 or 3;  0  ->  1 or 0   etc. etc., the vertical option always reaches higher
    -- 0      1    0   0      1    0   2      1    3
    --                                        1    0
    -- even 3 above 0 if we purposely ignore that a row cannot have more than 6 panels (which might prevent downstacking into that shape)
    -- 3      1    3
    -- 0  ->  1 or 0
    -- 0      1    0
    -- you see this instantly, it's trivial (is what my math prof said while scribbling a ton of greek symbols at incomprehensible speed on the blackboard), so even though I can't think of a formal proof right now, just take it!
    -- therefore only vertical matches need to be considered to find the TOP ROW for the color clear
    -- for further consideration it only needs to be checked if downstacking to the required degree is possible
    local matchedColorGridColumn = Defend.getTopMostMatchStateAsColorGridColumn(rowgrid, color)
    if matchedColorGridColumn then
        for row=#matchedColorGridColumn.sourceRowGrid.gridRows, 1, -1 do
            if matchedColorGridColumn:GetCountInRow(row) > 0 then
              -- just returning the top row index of the match we found
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
    local matchedColorGridColumn = Defend.getTopMostMatchStateAsColorGridColumn(rowgrid, color)

    return StackExtensions.substractRowGridColumns(colorGridColumn, matchedColorGridColumn)
end

function Defend.getTopMostMatchStateAsColorGridColumn(rowgrid, color)
    local colorGridColumn = rowgrid:GetColorColumn(color)
    local gridTopRow = rowgrid:GetTopRowWithPanels()
    local clearTopRow = gridTopRow

    -- this while is arranging the colorgridcolumn into the state of the match of that color that reaches furthest to the top
    -- won't deathloop cause we KNOW we have enough panels for a match and the amount of panels per row as well as the row we want to reach are still being ignored
    while #table.filter(colorGridColumn:GetLatentMatches(),
        function(match) return Defend.MatchWouldClear(clearTopRow, match) end) == 0 do
        Defend.downstackRowGridColumnTopDown(colorGridColumn, clearTopRow)
        -- check if we downstacked the top most panel so that the toprow we can potentially reach with this color got reduced
        if colorGridColumn:GetCountInRow(clearTopRow) == 0 then
            -- panel in the top row trickled down because of an empty row below
            clearTopRow = clearTopRow - 1
        end
    end

    -- validate that no row has negative emptyPanels by downstacking into an already full row
    for row=clearTopRow, 1, -1 do
        if rowgrid.gridRows[row].emptyPanelCount < 0 then
          -- which makes the imagined downstack scenario categorically impossible
            return nil
        end
    end

    -- returning the arranged colorGridColumn, comparison with where the garbage is happens elsewhere
    return colorGridColumn
end

function Defend.MatchWouldClear(clearTopRow, match)
  if match.type == "V" then return match.rows[3] == clearTopRow
  else return match.row == clearTopRow end
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

function Defend.downstackRowGridColumnTopDown(colorGridColumn, topRow)
  if colorGridColumn:GetCountInRow(topRow) > 0 then
    for row=topRow, topRow - 2, -1 do
      if row == 0 then
        -- can't drop anything to row 0, need to opt for horizontal match by dropping top down
        -- basically guaranteed to be in a scenario where 3 panels are spread across row 1 and 2
        colorGridColumn:DropPanelOneRow(topRow)
        return
      else
        if colorGridColumn:GetCountInRow(row) == 0 then
            assert(row < topRow, "if you see this, something is very fishy here")
            colorGridColumn:DropPanelOneRow(row + 1)
            return
        end
      end
    end
  --else
  -- if there's no panel in the top row, don't even bother, come back after lowering the top row
  end
end

-- uses the desired gridColumn of the color in conjunction with the rowGrid to come up with a full RowGrid that supports the form of the targetGridColumn
-- returns the rowGrid if one can be found, nil otherwise
function Defend.getTargetRowGrid(self, originalRowGrid, color, targetGridColumn)
  -- first apply the targetGridColumn to the originalRowGrid
  local originalGridColumn = originalRowGrid:GetColorColumn(color)
  local diffColumn = targetGridColumn:Subtract(originalGridColumn)
  local targetRowGrid = originalRowGrid:SubtractColumn(diffColumn)
  local matchTopRow = targetGridColumn:GetTopRowWithPanels()


  -- next analyse the emptyPanelsCount for each row to find out if / where additional panels need to be moved
  -- going top down because for bottom up, you'd always need to consider the case that you could drop something from a column further up if the column that has the extra panels doesn't work for you
  for i = #targetRowGrid.gridRows, 2, -1 do
    for j = i - 1, 1, -1 do
      -- check if higher row has more panels than the low row
      while targetRowGrid.gridRows[i].emptyPanelCount < targetRowGrid.gridRows[j].emptyPanelCount do
        -- dropping a panel is required
        -- convert colors in the row from which we need to drop one panel to color 10
        if Defend.IsPartOfMatch(targetGridColumn, matchTopRow, i) then
          targetRowGrid.gridRows[i] = targetRowGrid.gridRows[i]:TransformToColor10Except(color)
        else
          targetRowGrid.gridRows[i] = targetRowGrid.gridRows[i]:TransformToColor10Except()
        end

        if targetRowGrid.gridRows[i]:GetColorCount(10) == 0 then
          -- there are no panels to drop, abort
          return nil
        else
          targetRowGrid.gridRows[j].colorColumns[10] = targetRowGrid.gridRows[j].colorColumns[10] + 1
          targetRowGrid.gridRows[i].colorColumns[10] = targetRowGrid.gridRows[i].colorColumns[10] - 1
        end
      end
    end
  end

  -- Compare the top row of the match to the current top row and downstack all other panels into the well until the match is in the top row
  local topRowWithPanels = targetRowGrid:GetTopRowWithPanels()
  while topRowWithPanels > matchTopRow do
    local row = targetRowGrid.gridRows[topRowWithPanels]
    for i = 1, #row.colorColumns do
      if i ~= color then
        targetRowGrid:GetColorColumn():DropPanels(topRowWithPanels)
      end
    end
    topRowWithPanels = targetRowGrid:GetTopRowWithPanels()
  end

  return targetRowGrid
end

function Defend.IsPartOfMatch(targetGridColumn, matchTopRow, rowIndex)
  -- horizontal match
  if targetGridColumn.GetCountInRow(matchTopRow) >= 3 then
    return rowIndex == matchTopRow
  else
    -- vertical match
    return rowIndex >= matchTopRow - 2
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



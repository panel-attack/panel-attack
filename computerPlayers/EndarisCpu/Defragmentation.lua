Defragment = class(
        function(strategy, cpu)
            Strategy.init(strategy, "Defragment", cpu)
            CpuLog:log(1, "chose to DEFRAGMENT")
        end,
        Strategy
)

function Defragment.chooseAction(self)
    local gapToBeFilled
    local panelToMove

    local cursorVec = GridVector(self.cpu.cpuStack.cur_row, self.cpu.cpuStack.cur_col)
    local columns = StackExtensions.getTier1PanelsAsColumns(self.cpu.cpuStack)
    local connectedPanelSections = StackExtensions.getTier1ConnectedPanelSections(self.cpu.cpuStack)
    local panels = self.GetScoredPanelTable(columns, connectedPanelSections)
    local filteredPanels = Defragment.FilterPanels(panels)
    local emptySpaces = self.getScoredEmptySpaceTable(self.cpu.cpuStack.panels, columns, connectedPanelSections)
    local emptySpacesToFill = self.FilterEmptySpaces(emptySpaces)
    if #emptySpacesToFill == 1 then
        gapToBeFilled = emptySpacesToFill[1]
        panelToMove = self:findBestPanelForGap(gapToBeFilled, filteredPanels)
        if not panelToMove then
            panelToMove = self:findBestPanelForGap(gapToBeFilled, panels)
        end
    else
        panelToMove = Defragment.getClosestPanelToCursor(filteredPanels, cursorVec)
        gapToBeFilled = Defragment.findBestGapForPanel(self.cpu.cpuStack.panels, panelToMove, emptySpacesToFill)
    end

    if panelToMove and gapToBeFilled then
        local action = MovePanel(self.cpu.cpuStack, panelToMove, gapToBeFilled.vector)
        action:calculateExecution(self.cpu.cpuStack.cur_row, self.cpu.cpuStack.cur_col)

        return action
    else
        CpuLog:log(1, "targetted gap or panel is likely not swappable at the moment due to an unexpected match or similar things")
        return nil
    end

    -- open issues with defragmenting:
    -- takes the panel instead of the closest panel from the column to downstack
    -- needs to weigh distance on top of solely panel score for the panel selection
    -- sometimes the first line of garbage panels is included in the connectedPanelSections somehow (need a unittest)
end

-- returns all panels with color 0 along with a score based on how many connectedPanelSections are adjacent to it
function Defragment.getScoredEmptySpaceTable(panels, columns, connectedPanelSections)
    local emptySpaces = {}

    --setting up a table for the empty spaces
    local maxColHeight = 0
    for i=1,#columns do
        maxColHeight = math.max(maxColHeight, #columns[i])
    end

    for i=1,maxColHeight + 1 do
        for j=1,#columns do
            if panels[i][j].color == 0 then
                local emptySpace = ActionPanel(panels[i][j], i, j)
                table.insert(emptySpaces, {panel = emptySpace, score = 0})
            end
        end
    end

    for i=1,#connectedPanelSections do
        connectedPanelSections[i]:print()

        -- setting scores for adjacent empty space
        for j=1,#emptySpaces do
            if emptySpaces[j].panel.vector:adjacentToRectangle(connectedPanelSections[i].bottomLeftVector, connectedPanelSections[i].topRightVector) then
                emptySpaces[j].score = emptySpaces[j].score + 1
            end
        end
    end

    --create a new table without emptySpaces that scored 0 because none cares about them
    local filteredEmptySpaces = {}
    for i=1, #emptySpaces do
        if emptySpaces[i].score > 0 then
            table.insert(filteredEmptySpaces, emptySpaces[i])
        end
    end

    --but if we only have ones that scored 0, we still would like them
    if #filteredEmptySpaces == 0 then
        filteredEmptySpaces = emptySpaces
    end

    --debugging
    for i=1,#filteredEmptySpaces do
        CpuLog:log(5, "empty space " .. i .. " at coord " .. filteredEmptySpaces[i].panel.vector:toString() .. " with value of " .. filteredEmptySpaces[i].score)
    end

    return filteredEmptySpaces
end

-- returns all emptyspaces that share the highest score
function Defragment.FilterEmptySpaces(emptySpaces)
    table.sort(emptySpaces, function(a, b)
        return a.score<b.score
    end)

    --special low stack scenario where no connectedPanelSections exist
    if emptySpaces[1].score == 0 then
        table.sort(emptySpaces, function(a, b)
            -- in that case we fill the lowest gaps but not those in row 1 since panels are scarce
            -- and panels in row 1 won't contribute to form a connectedpanelsection
            return a.panel:row() < b.panel:row() and a.panel:row() ~=1
        end)

        local emptySpacesToFill = { emptySpaces[1].panel }
        for i=2,#emptySpaces do
            if emptySpaces[i].panel:row() == emptySpaces[1].panel:row() then
                table.insert(emptySpacesToFill, emptySpaces[i].panel)
            else
                break
            end
        end

        return emptySpacesToFill
    else
        local emptySpacesToFill = { emptySpaces[1].panel }
        for i=2,#emptySpaces do
            if emptySpaces[i].score == emptySpaces[1].score then
                table.insert(emptySpacesToFill, emptySpaces[i].panel)
            else
                break
            end
        end

        return emptySpacesToFill
    end
end

-- returns all panels above row 1 with a score based on the connectedPanelSections they are contained in
function Defragment.GetScoredPanelTable(columns, connectedPanelSections)
    local panels = {}

    for i=1,#columns do
        for j=1,#columns[i] do
            -- panels in the bottom row cannot be used for downstacking
            if columns[i][j].vector.row > 1 then
                table.insert(panels, {panel = columns[i][j], score = 0})
            end
        end
    end

    for i=1,#connectedPanelSections do
        connectedPanelSections[i]:print()

        -- setting scores for panels
        for j=1,#panels do
            if panels[j].panel.vector:inRectangle(connectedPanelSections[i].bottomLeftVector, connectedPanelSections[i].topRightVector) then
                panels[j].score = panels[j].score + connectedPanelSections[i].numberOfPanels
            end
        end
    end

    --debugging
    for i=1,#panels do
        CpuLog:log(5, "panel " .. panels[i].panel.id .. " at coord " .. panels[i].panel.vector:toString() .. " with value of " .. panels[i].score)
    end

    return panels
end

function Defragment.FilterPanels(panels)
    local panelsToMove = {}

    table.sort(panels, function(a, b)
        return a.score>b.score
    end)

    if panels[1].score > 0 then
        -- default, by score
        table.insert(panelsToMove, 1, panels[1])
        for i=2,#panels do
            if panels[i].score + 15 >= panels[1].score then
                table.insert(panelsToMove, panels[i])
            else
                break
            end
        end
    else
    --special weird/low stack scenario where no connectedPanelSections exist
        table.sort(panels, function(a, b)
            -- in that case we take the highest panel
            return a.panel:row() > b.panel:row()
        end)

        table.insert(panelsToMove, 1, panels[1])
        for i=2,#panels do
            if panels[i].panel:row() == panels[1].panel:row() then
                table.insert(panelsToMove, panels[i])
            else
                break
            end
        end
    end

    return panelsToMove
end

function Defragment.getClosestEmptySpaceToCursorAsPanel(emptySpaces, cursorVec)
    table.sort(emptySpaces, function(a, b)
        return a.vector:distance(cursorVec) < b.vector:distance(cursorVec)
    end)

    return emptySpaces[1]
end

-- tests all panels in order of score whether they can be moved into the gap and returns the first one with which it is possible
function Defragment.findBestPanelForGap(self, gapPanel, scoredPanels)
    -- no sorting of scoredPanls necessary as they are already sorted through prior filtering

    CpuLog:log(4, "trying to fill gap " .. gapPanel.vector:toString())
    CpuLog:log(4, "searching among " .. #scoredPanels .. " panels")

    for i=1,#scoredPanels do
        CpuLog:log(4, "Checking panel " .. scoredPanels[i].panel.vector:toString())
        if StackExtensions.moveIsValid(self.cpu.cpuStack, scoredPanels[i].panel, gapPanel.vector) then
            CpuLog:log(4, "Selected " .. scoredPanels[i].panel:toString())
            return scoredPanels[i].panel
        end
    end

    CpuLog:log(1, "Unexpectedly couldn't find a panel to fill the gap with")
    return nil
end

function Defragment.getClosestPanelToCursor(panels, cursorVec)
    table.sort(panels, function(a, b)
        return a.panel.vector:distance(cursorVec) < b.panel.vector:distance(cursorVec)
    end)

    return panels[1].panel
end

function Defragment.findBestGapForPanel(stackPanels, panel, emptySpacesToFill)
    table.sort(emptySpacesToFill, function(a, b)
        return a.vector:distance(panel.vector) < b.vector:distance(panel.vector)
    end)

    for i=1, #emptySpacesToFill do
        if StackExtensions.moveIsValidByPanels(stackPanels, panel, emptySpacesToFill[i].vector) then
            return emptySpacesToFill[i]
        end
    end

    CpuLog:log(1, "Unexpectedly couldn't find a gap to put the panel into")
    return nil
end
Defragment = class(
        function(strategy, cpu)
            Strategy.init(strategy, "Defragment", cpu)
            CpuLog:log(1, "chose to DEFRAGMENT")
        end,
        Strategy
)

function Defragment.chooseAction(self)
    local columns = StackExtensions.getTier1PanelsAsColumns(self.cpu.stack)
    local connectedPanelSections = StackExtensions.getTier1ConnectedPanelSections(self.cpu.stack)
    local panels = self.GetScoredPanelTable(columns, connectedPanelSections)
    local emptySpaces = self.getScoredEmptySpaceTable(self.cpu.stack.panels, columns, connectedPanelSections)
    local emptySpacesToFill = self:FilterEmptySpaces(emptySpaces)
    local gapToBeFilled = self:getClosestEmptySpaceToCursorAsPanel(emptySpacesToFill)
    local panelToMove = self:findBestPanelForGap(gapToBeFilled, panels)

    if panelToMove then
        local action = MovePanel(self.cpu.stack, panelToMove, gapToBeFilled.vector)
        action:calculateExecution(self.cpu.stack.cur_row, self.cpu.stack.cur_col)
        CpuLog:log(1, action:toString())

        return action
    else
        CpuLog:log(1, "targetted gap is likely not swappable at the moment due to an unexpected match or similar things")
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

    --purge emptySpaces that scored 0 because none cares about them
    for i=#emptySpaces, 1, -1 do
        if emptySpaces[i].score == 0 then
            table.remove(emptySpaces, i)
        end
    end

    --debugging
    for i=1,#emptySpaces do
        CpuLog:log(5, "empty space " .. i .. " at coord " .. emptySpaces[i].panel.vector:toString() .. " with value of " .. emptySpaces[i].score)
    end

    return emptySpaces
end

-- returns all emptyspaces that share the highest score
function Defragment.FilterEmptySpaces(self, emptySpaces)
    table.sort(emptySpaces, function(a, b)
        return a.score>b.score
    end)

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

-- returns all panels above row 3 with a score based on the connectedPanelSections they are contained in
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

function Defragment.getClosestEmptySpaceToCursorAsPanel(self, emptySpaces)
    local cursorVec = GridVector(self.cpu.stack.cur_row, self.cpu.stack.cur_col)

    table.sort(emptySpaces, function(a, b)
        return a.vector:distance(cursorVec) < b.vector:distance(cursorVec)
    end)

    return emptySpaces[1]
end

-- tests all panels in order of score whether they can be moved into the gap and returns the first one with which it is possible
function Defragment.findBestPanelForGap(self, gapPanel, scoredPanels)
    table.sort(scoredPanels, function(a, b)
        return a.score<b.score
    end)
    CpuLog:log(1, "trying to fill gap " .. gapPanel.vector:toString())
    CpuLog:log(1, "searching among " .. #scoredPanels .. " panels")

    for i=1,#scoredPanels do
        CpuLog:log(1, "Checking panel " .. scoredPanels[i].panel.vector:toString())
        if StackExtensions.moveIsValid(self.cpu.stack, scoredPanels[i].panel, gapPanel) then
            CpuLog:log(4, "Selected " .. scoredPanels[i].panel:toString())
            return scoredPanels[i].panel
        end
    end

    CpuLog:log(1, "Unexpectedly couldn't find a panel to fill the gap with")
    return nil
end
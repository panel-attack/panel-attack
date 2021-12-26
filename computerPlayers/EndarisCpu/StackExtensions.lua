-- all StackExtensions should have an extra method that only takes the panelproperty as the parameter
-- unless they need more than just the panels property
-- this makes it easier to mock a stack for unit tests while maintaining convenience

function StackExtensions.printAsAprilStack(stack)
    StackExtensions.printAsAprilStackByPanels(stack.panels)
end

function StackExtensions.printAsAprilStackByPanels(panels)
    local aprilString = StackExtensions.AsAprilStackByPanels(panels)
    print("april panelstring is " .. aprilString)
end

-- returns the maximum number of panels connected in a MxN rectangle shape
-- where M >= 2 and N >= 3 divided through the total number of panels on the board
-- a panel counts as connected if you can move it along that block without it dropping rows
-- 1 - N_connectedpanels / N_totalpanels
function StackExtensions.getFragmentationPercentage(stack)
    return StackExtensions.getFragmentationPercentageByPanels(stack.panels)
end

function StackExtensions.getFragmentationPercentageByPanels(panels)
    local connectedPanels = StackExtensions.getMaxConnectedTier1PanelsCountByPanels(panels)
    local totalPanels = StackExtensions.getTotalTier1PanelsCountByPanels(panels)

    print('total panel count is ' .. totalPanels)
    print('connected panel count is ' .. connectedPanels)

    return 1 - (connectedPanels / totalPanels)
end

--gets all panels in the stack that are in the first tier of the stack
function StackExtensions.getTotalTier1PanelsCount(stack)
    return StackExtensions.getTotalTier1PanelsCountByPanels(stack.panels)
end

function StackExtensions.getTotalTier1PanelsCountByPanels(panels)
    local panelCount = 0
    local columns = StackExtensions.getTier1PanelsAsColumnsByPanels(panels)

    for i = 1, #columns do
        for j = 1, #columns[i] do
            panelCount = panelCount + 1
        end
    end

    return panelCount
end

-- returns the stack in 6 columns that hold the panels from bottom up
function StackExtensions.getPanelsAsColumns(stack)
    return StackExtensions.getPanelsAsColumnsByPanels(stack.panels)
end

function StackExtensions.getPanelsAsColumnsByPanels(panels)
    local columns = {}
    -- first transforming into a column representation
    if panels and panels[1] then
        for i = 1, #panels[1] do
            columns[i] = {}
            for j = 1, #panels do
                local panel = panels[j][i]
                columns[i][j] = ActionPanel(panel.id, panel.color, j, i)
            end
        end
    end
    return columns
end

-- returns the stack in 6 columns that hold the panels from bottom up until reaching the first garbage panel
-- for that reason at times it may not actually be the entire first tier if a low combo garbage blocks early and has panels on top
function StackExtensions.getTier1PanelsAsColumns(stack)
    return StackExtensions.getTier1PanelsAsColumnsByPanels(stack.panels)
end

function StackExtensions.getTier1PanelsAsColumnsByPanels(panels)
    -- first transforming into a column representation
    local columns = StackExtensions.getPanelsAsColumnsByPanels(panels)

    -- cut out everything 0 and everything that is behind a 9
    for i =1, #columns do
        for j = #columns[i], 1,-1 do
            if columns[i][j].color == 0 then
                table.remove(columns[i], j)
            elseif columns[i][j].color == 9 then
                for k = #columns[i],j,-1 do
                    table.remove(columns[i], k)
                end
            end
        end
    end

    return columns
end

-- returns the maximum number of panels connected in a MxN rectangle shape in the first tier of the stack
-- where M >= 2 and N >= 3
-- a panel counts as connected if you can move it along that block without it dropping rows
function StackExtensions.getMaxConnectedTier1PanelsCount(stack)
    return StackExtensions.getMaxConnectedTier1PanelsCountByPanels(stack.panels)
end

function StackExtensions.getMaxConnectedTier1PanelsCountByPanels(panels)
    local maximumConnectedPanelCount = 0

    local panelSections = StackExtensions.getTier1ConnectedPanelSectionsByPanels(panels)

    for i=1,#panelSections do
        maximumConnectedPanelCount = math.max(maximumConnectedPanelCount, panelSections[i].numberOfPanels)
    end

    return maximumConnectedPanelCount
end

-- returns all sections of connected panels that are at least 2x3 in size
-- a panel counts as connected if you can move it along that section without it dropping rows
-- includes sections that are fully part of other sections, no duplicates
function StackExtensions.getTier1ConnectedPanelSections(stack)
    return StackExtensions.getTier1ConnectedPanelSectionsByPanels(stack.panels)
end

function StackExtensions.getTier1ConnectedPanelSectionsByPanels(panels)
    local columns = StackExtensions.getTier1PanelsAsColumnsByPanels(panels)
    local connectedPanelSections = {}

    for i = 1, #columns - 1 do
        local baseHeight = #columns[i]
        --CpuLog:log(6, 'column ' .. i .. ' with a height of ' .. baseHeight)

        --match with height = baseHeight - 1 and heigh = baseHeight
        for height = baseHeight - 1, baseHeight do
                local connectedPanelCount = baseHeight
                local colsToTheLeft = 0
                local colsToTheRight = 0
                for k = i - 1, 1, -1 do
                    -- from column i to the left side of the board
                    if columns[k] and #columns[k] >= height then
                        connectedPanelCount = connectedPanelCount + math.min(height + 1, #columns[k])
                        colsToTheLeft = colsToTheLeft + 1
                    else
                        break
                    end
                end

                -- from column i to the right side of the board
                for k = i + 1, #columns do
                    if columns[k] and #columns[k] >= height then
                        connectedPanelCount = connectedPanelCount + math.min(height + 1, #columns[k])
                        colsToTheRight = colsToTheRight + 1
                    else
                        break
                    end
                end

                local cols = 1 + colsToTheLeft + colsToTheRight
                --CpuLog:log(6, "Found " .. cols .. " columns around column " .. i .. " with a height of >= " .. height)

                if cols >= 2 and (connectedPanelCount / cols) > 2 then
                    --suffices the 2x3 criteria

                    --add all valid subsections in the section
                    for c=cols,2,-1 do
                        for rows=height+1,3,-1 do
                            for col_offset=i - colsToTheLeft,i - colsToTheLeft + (cols - c) do
                                
                                local startCol = col_offset
                                local endCol = col_offset + c - 1 -- -1 because the col range is [], not [)
                                local bottomLeft = GridVector(1, startCol)
                                local topRight = GridVector(rows, endCol)

                                local alreadyExists = false
                                -- but only those that don't exist yet
                                for n=1,#connectedPanelSections do
                                    if connectedPanelSections[n].bottomLeftVector:equals(bottomLeft) and connectedPanelSections[n].topRightVector:equals(topRight) then
                                        alreadyExists = true
                                        break
                                    end
                                end

                                if alreadyExists == false then
                                    -- count the panels
                                    --CpuLog:log(6, "Counting panels for subsection " .. bottomLeft:toString() .. "," .. topRight:toString())
                                    --CpuLog:log(6, "c: " .. c .. ",rows: " .. rows .. ",startCol: " .. startCol .. ",endCol: " .. endCol .. ",col_offset: " .. col_offset)
                                    local panelCount = 0
                                    for l=startCol,endCol do
                                        panelCount = panelCount + math.min(rows, #columns[l])
                                    end
                
                                    table.insert(connectedPanelSections,
                                    ConnectedPanelSection(bottomLeft, topRight,
                                                          panelCount, panels))
                                end

                            end
                        end
                    end
                end
        end
    end

    return connectedPanelSections
end

ConnectedPanelSection = class(function(panelSection, bottomLeftVector, topRightVector, numberOfPanels, panels)
    panelSection.bottomLeftVector = bottomLeftVector
    panelSection.topRightVector = topRightVector
    panelSection.numberOfPanels = numberOfPanels
    panelSection.panels = {}

    for i=bottomLeftVector.row,topRightVector.row do
        for j=bottomLeftVector.column,topRightVector.column do
            table.insert(panelSection.panels, panels[i][j])
        end
    end
end)

function ConnectedPanelSection.print(self)
    CpuLog:log(6, self:toString())
end

function ConnectedPanelSection.toString(self)
    return "ConnectedPanelSection with anchors " .. self.bottomLeftVector:toString() .. ", " .. self.topRightVector:toString() 
    .. " containing a total of " .. self.numberOfPanels .. " panels"
end

function ConnectedPanelSection.equals(self, otherSection)
    return self.bottomLeftVector:equals(otherSection.bottomLeftVector) and
        self.topRightVector:equals(otherSection.topRightVector) and
        self.numberOfPanels == otherSection.numberOfPanels and
        StackExtensions.panelsAreEqualByPanels(self.panels, otherSection.panels)
end


function StackExtensions.toRowGrid(stack)
    local panels = stack.panels
    StackExtensions.printAsAprilStack(stack)
    local grid = {}
    for i = 1, #panels do
        grid[i] = {}
        -- always use 8: shockpanels appear on every level and we want columnnumber=color number for readability
        for j = 1, 8 do
            local count = 0
            for k = 1, #panels[1] do
                if panels[i][k].color == j then
                    count = count + 1
                end
            end
            grid[i][j] = count
        end
    end
    return grid
end


function StackExtensions.findActions(stack)
    local actions = {}
    local grid = StackExtensions.toRowGrid(stack)

    --find matches, i is row, j is panel color, grid[i][j] is the amount of panels of that color in the row, k is the column the panel is in
    for j = 1, #grid[1] do
        local colorConsecutiveRowCount = 0
        local colorConsecutivePanels = {}
        for i = 1, #grid do
            -- horizontal 3 matches
            if grid[i][j] >= 3 then
                --fetch the actual panels
                CpuLog:log(6, 'found horizontal 3 match in row ' .. i .. ' for color ' .. j)
                local panels = {}
                for k = 1, #stack.panels[i] do
                    if stack.panels[i][k].color == j then
                        local actionPanel = ActionPanel(stack.panels[i][k].id, j, i, k)
                        table.insert(panels, actionPanel)
                    end
                end

                -- if there are 4 in the row, add 2 actions
                for n = 1, #panels - 2 do
                    local actionPanels = {}

                    table.insert(actionPanels, panels[n]:copy())
                    table.insert(actionPanels, panels[n + 1]:copy())
                    table.insert(actionPanels, panels[n + 2]:copy())

                    --create the action and put it in our list
                        table.insert(actions, H3Match(actionPanels))
                end
            end
            -- vertical 3 matches
            if grid[i][j] > 0 then
                -- if colorConsecutiveRowCount >= 4 then
                --     CpuLog:log(6, "found vertical 4 combo in row " .. i-3 .. " to " .. i .. " for color " .. j)
                --     table.insert(actions, V4Combo(colorConsecutivePanels))
                -- end
                -- if colorConsecutiveRowCount >= 5 then
                --     CpuLog:log(6, "found vertical 5 combo in row " .. i-4 .. " to " .. i .. " for color " .. j)
                --     table.insert(actions, V5Combo(colorConsecutivePanels))
                -- end
                colorConsecutiveRowCount = colorConsecutiveRowCount + 1
                colorConsecutivePanels[colorConsecutiveRowCount] = {}
                for k = 1, #stack.panels[i] do
                    if stack.panels[i][k].color == j then
                        local actionPanel = ActionPanel(stack.panels[i][k].id, j, i, k)
                        table.insert(colorConsecutivePanels[colorConsecutiveRowCount], actionPanel)
                    end
                end
                if colorConsecutiveRowCount >= 3 then
                    -- technically we need action for each unique combination of panels to find the best option
                    local combinations =
                        #colorConsecutivePanels[colorConsecutiveRowCount - 2] *
                        #colorConsecutivePanels[colorConsecutiveRowCount - 1] *
                        #colorConsecutivePanels[colorConsecutiveRowCount]
                    -- CpuLog:log(6,
                    --     'found ' ..
                    --         combinations ..
                    --             ' combination(s) for a vertical 3 match in row ' ..
                    --                 i - 2 .. ' to ' .. i .. ' for color ' .. j
                    -- )

                    for q = 1, #colorConsecutivePanels[colorConsecutiveRowCount - 2] do
                        for r = 1, #colorConsecutivePanels[colorConsecutiveRowCount - 1] do
                            for s = 1, #colorConsecutivePanels[colorConsecutiveRowCount] do
                                local panels = {}
                                table.insert(panels, colorConsecutivePanels[colorConsecutiveRowCount - 2][q]:copy())
                                table.insert(panels, colorConsecutivePanels[colorConsecutiveRowCount - 1][r]:copy())
                                table.insert(panels, colorConsecutivePanels[colorConsecutiveRowCount][s]:copy())
                                table.insert(actions, V3Match(panels))
                            end
                        end
                    end
                end
            else
                colorConsecutiveRowCount = 0
                colorConsecutivePanels = {}
            end
        end
    end

    return actions
end

function StackExtensions.swapIsValid(panel1, panel2)
    return panel1:exclude_swap() and panel2:exclude_swap()
end

function StackExtensions.moveIsValid(stack, panelId, targetVector)
    return StackExtensions.moveIsValidByPanels(stack.panels, panelId, targetVector)
end

function StackExtensions.moveIsValidByPanels(panels, panelId, targetVector)
    local panel = StackExtensions.getPanelByIdFromPanels(panels, panelId)
    if panel.height < targetVector.column then
        return false
    else
        -- this is very naive and certainly not true in some cases but should be fine for a start
        return true
    end
end

function StackExtensions.getPanelById(stack, id)
    return StackExtensions.getPanelById(stack.panels, id)
end

function StackExtensions.getPanelByIdFromPanels(panels, id)
    for i=1,#panels do
        for j=1, #panels[1] do
           if panels[i][j].id == id then
            panels[i][j].height = j
            panels[i][j].width = i
               return panels[i][j]
           end
        end
    end

    return nil
end

function StackExtensions.calculateExecution(stack, action)
    -- 2 components are important:
    -- 1. the action has to know how it executes (setup and execution panel)
    -- -> dictates order of panels
    -- 2. the stack has to sanity check whether a movement is actually possible
    -- -> checks whether we are actually falling down
end

function StackExtensions.actionIsValid(stack, action)
    return StackExtensions.actionIsValidByPanels(stack.panels, action)
end


function StackExtensions.actionIsValidByPanels(panels, action)
    for i=1, #action.panels do
        if not StackExtensions.moveIsValidByPanels(panels,
                               action.panels[i].id, action.panels[i].targetVector) then
            return false
        end
    end

    return true
end

-- not really equal but sufficiently equal
function StackExtensions.stacksAreEqual(stack, otherStack)
    if stack and otherStack then
        if StackExtensions.panelsAreEqualByPanels(stack.panels, otherStack.panels) then
            return true
        else
            return false
        end
    end
end

function StackExtensions.panelsAreEqualByPanels(panels, otherPanels)
    if #panels ~= #otherPanels then
        return false
    end

    for i=1,#panels do
        for j=1,#panels[i] do
           if not panels[i][j]:equals(otherPanels[i][j]) then
               return false
           end
        end
    end

    return true
end

-- this is halfbaked but should be fine for now
function Panel.equals(self, otherPanel)
    if self == nil and otherPanel == nil then
        return true
    elseif self.id == otherPanel.id and
        self.state == otherPanel.state and
        self.chaining == otherPanel.chaining then
        return true
    else
        return false
    end
end
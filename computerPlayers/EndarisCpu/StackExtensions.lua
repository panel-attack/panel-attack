StackExtensions = class(function(self) end)

function StackExtensions.printAsAprilStack(stack)
    if stack then
        local panels = stack.panels
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


-- returns the maximum number of panels connected in a MxN rectangle shape
-- where M >= 2 and N >= 3 divided through the total number of panels on the board
-- a panel counts as connected if you can move it along that block without it dropping rows
-- 1 - N_connectedpanels / N_totalpanels
function StackExtensions.getFragmentationPercentage(stack)
    local connectedPanels = stack:getMaxConnectedTier1PanelsCount()
    local totalPanels = stack:getTotalTier1PanelsCount()

    print('total panel count is ' .. totalPanels)
    print('connected panel count is ' .. connectedPanels)

    return 1 - (connectedPanels / totalPanels)
end

--gets all panels in the stack that are in the first tier of the stack
function Stack.getTotalTier1PanelsCount(self)
    local panelCount = 0
    local columns = self:getTier1PanelsAsColumns()

    for i = 1, #columns do
        for j = 1, #columns[i] do
            panelCount = panelCount + 1
        end
    end

    return panelCount
end

-- returns the stack in 6 columns that hold the panels from bottom up
function Stack.getPanelsAsColumns(self)
    local columns = {}
    -- first transforming into a column representation
    if self.panels and self.panels[1] then
        for i = 1, #self.panels[1] do
            columns[i] = {}
            for j = 1, #self.panels do
                local panel = self.panels[j][i]
                columns[i][j] = ActionPanel(panel.id, panel.color, j, i)
            end
        end
    end
    return columns
end

-- returns the stack in 6 columns that hold the panels from bottom up until reaching the first garbage panel
-- for that reason at times it may not actually be the entire first tier if a low combo garbage blocks early and has panels on top
function Stack.getTier1PanelsAsColumns(self)
    -- first transforming into a column representation
    local columns = self:getPanelsAsColumns()

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
function Stack.getMaxConnectedTier1PanelsCount(self)
    local maximumConnectedPanelCount = 0

    local panelSections = self:getTier1ConnectedPanelSections()

    for i=1,#panelSections do
        maximumConnectedPanelCount = math.max(maximumConnectedPanelCount, panelSections[i].numberOfPanels)
    end

    return maximumConnectedPanelCount
end

-- returns all sections of connected panels that are at least 2x3 in size
-- a panel counts as connected if you can move it along that section without it dropping rows
-- includes sections that are fully part of other sections, no duplicates
function Stack.getTier1ConnectedPanelSections(self)
    local columns = self:getTier1PanelsAsColumns()
    local connectedPanelSections = {}

    for i = 1, #columns - 1 do
        local baseHeight = #columns[i]
        cpuLog('column ' .. i .. ' with a height of ' .. baseHeight)

        --match with height = baseHeight - 1 and heigh = baseHeight
        for height = baseHeight - 1, baseHeight do
            if alreadyExists ~= true then
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
                cpuLog("Found " .. cols .. " columns around column " .. i .. " with a height of >= " .. height)

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
                                    cpuLog("Counting panels for subsection " .. bottomLeft:toString() .. "," .. topRight:toString())
                                    cpuLog("c: " .. c .. ",rows: " .. rows .. ",startCol: " .. startCol .. ",endCol: " .. endCol .. ",col_offset: " .. col_offset)
                                    local panelCount = 0
                                    for l=startCol,endCol do
                                        panelCount = panelCount + math.min(rows, #columns[l])
                                    end
                
                                    table.insert(connectedPanelSections,
                                    ConnectedPanelSection(bottomLeft, topRight,
                                                          panelCount, self.panels))
                                end

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
            table.insert(panelSection.panels, panels[j][i])
        end
    end
end)

function ConnectedPanelSection.print(self)
    cpuLog("ConnectedPanelSection with anchors " .. self.bottomLeftVector:toString() .. ", " .. self.topRightVector:toString() 
            .. " containing a total of " .. self.numberOfPanels .. " panels")
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
                cpuLog('found horizontal 3 match in row ' .. i .. ' for color ' .. j)
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
                --     cpuLog("found vertical 4 combo in row " .. i-3 .. " to " .. i .. " for color " .. j)
                --     table.insert(actions, V4Combo(colorConsecutivePanels))
                -- end
                -- if colorConsecutiveRowCount >= 5 then
                --     cpuLog("found vertical 5 combo in row " .. i-4 .. " to " .. i .. " for color " .. j)
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
                    cpuLog(
                        'found ' ..
                            combinations ..
                                ' combination(s) for a vertical 3 match in row ' ..
                                    i - 2 .. ' to ' .. i .. ' for color ' .. j
                    )

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

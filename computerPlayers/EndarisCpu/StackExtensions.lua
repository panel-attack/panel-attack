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

  print("total panel count is " .. totalPanels)
  print("connected panel count is " .. connectedPanels)

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
        columns[i][j] = ActionPanel(panels[j][i], j, i)
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
  for i = 1, #columns do
    for j = #columns[i], 1, -1 do
      if columns[i][j].color == 0 then
        table.remove(columns[i], j)
      elseif columns[i][j].color == 9 then
        for k = #columns[i], j, -1 do
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

  for i = 1, #panelSections do
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

  for i = 1, #columns do
    local baseHeight = #columns[i]
    CpuLog:log(6, "column " .. i .. " with a height of " .. baseHeight)

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
      CpuLog:log(6, "Found " .. cols .. " columns around column " .. i .. " with a height of >= " .. height)

      if cols >= 2 and (connectedPanelCount / cols) > 2 then
        --suffices the 2x3 criteria

        --add all valid subsections in the section
        for c = cols, 2, -1 do
          for rows = height + 1, 3, -1 do
            for col_offset = i - colsToTheLeft, i - colsToTheLeft + (cols - c) do
              local startCol = col_offset
              local endCol = col_offset + c - 1 -- -1 because the col range is [], not [)
              local bottomLeft = GridVector(1, startCol)
              local topRight = GridVector(rows, endCol)

              local alreadyExists = false
              -- but only those that don't exist yet
              for n = 1, #connectedPanelSections do
                if
                  connectedPanelSections[n].bottomLeftVector:equals(bottomLeft) and
                    connectedPanelSections[n].topRightVector:equals(topRight)
                 then
                  alreadyExists = true
                  break
                end
              end

              if alreadyExists == false then
                -- count the panels
                CpuLog:log(6, "Counting panels for subsection " .. bottomLeft:toString() .. "," .. topRight:toString())
                CpuLog:log(
                  6,
                  "c: " ..
                    c ..
                      ",rows: " ..
                        rows .. ",startCol: " .. startCol .. ",endCol: " .. endCol .. ",col_offset: " .. col_offset
                )
                local panelCount = 0
                for l = startCol, endCol do
                  panelCount = panelCount + math.min(rows, #columns[l])
                end

                -- a scenario in when a subsection assumed to have a certain amount of rows
                -- fails to actually meet the same amount of rows as its parent section
                local isValid = math.ceil(panelCount / (endCol - startCol + 1)) == rows

                if isValid then
                  local newPanelSection = ConnectedPanelSection(bottomLeft, topRight, panelCount, panels)
                  CpuLog:log(5, "Adding new " .. newPanelSection:toString())
                  table.insert(connectedPanelSections, newPanelSection)
                else
                  CpuLog:log(6, "Section is not actually " .. rows .. " rows high and is therefore skipped.")
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

ConnectedPanelSection =
  class(
  function(panelSection, bottomLeftVector, topRightVector, numberOfPanels, panels)
    panelSection.bottomLeftVector = bottomLeftVector
    panelSection.topRightVector = topRightVector
    panelSection.numberOfPanels = numberOfPanels
    panelSection.panels = {}

    for i = bottomLeftVector.row, topRightVector.row do
      for j = bottomLeftVector.column, topRightVector.column do
        table.insert(panelSection.panels, panels[i][j])
      end
    end
  end
)

function ConnectedPanelSection.print(self)
  CpuLog:log(6, self:toString())
end

function ConnectedPanelSection.toString(self)
  return "ConnectedPanelSection with anchors " ..
    self.bottomLeftVector:toString() ..
      ", " .. self.topRightVector:toString() .. " containing a total of " .. self.numberOfPanels .. " panels"
end

function ConnectedPanelSection.equals(self, otherSection)
  return self.bottomLeftVector:equals(otherSection.bottomLeftVector) and
    self.topRightVector:equals(otherSection.topRightVector) and
    self.numberOfPanels == otherSection.numberOfPanels and
    StackExtensions.panelsAreEqualByPanels(self.panels, otherSection.panels)
end

function StackExtensions.getTopRowWithPanelsFromRowGrid(rowgrid)
end

function StackExtensions.getRowGridColumn(rowgrid, color)
  local colorGridColumn = {}
  for row = #rowgrid, 1, -1 do
    local emptyPanelsInRow = 6
    for color = 1, #rowgrid[1] do
      emptyPanelsInRow = emptyPanelsInRow - rowgrid[row][color]
    end
    colorGridColumn[row] = {colorCount = rowgrid[row][color], emptyPanelsCount = emptyPanelsInRow}
  end
  return colorGridColumn
end

function StackExtensions.substractRowGridColumns(column1, column2)
  local columnDiff = {}
  for row = 1, #column1 do
    columnDiff[row].colorDiff = column1.colorCount - column2.colorCount
    columnDiff[row].emptyDiff = column1.emptyPanelsCount - column2.emptyPanelsCount
  end

  return columnDiff
end

function StackExtensions.getDownstackPanelVectors(stack)
  return StackExtensions.getDownstackPanelColumnsByPanels(stack.panels)
end

function StackExtensions.getDownstackPanelVectorsByPanels(panels)
  local downstackCoords = {}

  for column = 1, #panels[1] do
    for row = 1, #panels do
      local vector = GridVector(row, column)
      if StackExtensions.IsDownstackPanelByPanels(panels, vector) then
        table.insert(downstackCoords, vector)
      end
    end
  end

  return downstackCoords
end

function StackExtensions.getNonDownstackPanelVectors(stack)
  return StackExtensions.getNonDownstackPanelVectorsByPanels(stack.panels)
end

function StackExtensions.getNonDownstackPanelVectorsByPanels(panels)
  local downstackVectors = StackExtensions.getDownstackPanelVectorsByPanels(panels)
  local nonDownstackVectors = {}

  for row = 1, #panels do
    for column = 1, #panels[row] do
      local vector = GridVector(row, column)
      local IsDownstackVector = false
      for i = 1, #downstackVectors do
        if vector:equals(downstackVectors[i]) then
          IsDownstackVector = true
        end
      end
      if not IsDownstackVector then
        table.insert(nonDownstackVectors, vector)
      end
    end
  end

  return nonDownstackVectors
end

function StackExtensions.IsDownstackable(stack, vector)
  return StackExtensions.isDownstackableByPanels(stack.panels, vector)
end

--returns true if the panel can fall down rows by either swappig the panel itself once or one of the panels directly below
function StackExtensions.isDownstackableByPanels(panels, vector)
  if vector.row == 1 or panels[vector.row][vector.column].color == 0 then
    return false
  else
    return StackExtensions.IsDownstackPanelByPanels(panels, vector:substract(GridVector(1, 0)))
  end
end

function StackExtensions.IsDownstackPanel(stack, vector)
  return StackExtensions.IsDownstackPanelByPanels(stack.panels, vector)
end

--returns true if swapping the panel once may result in a different rowgrid representation of the stack
--returns false if not (including if the panel cannot be swapped because it is garbage)
function StackExtensions.IsDownstackPanelByPanels(panels, vector)
  if StackExtensions.isDownstackableByPanels(panels, vector) then
    return true
  else
    if
      panels[vector.row][vector.column].color ~= 0 and panels[vector.row][vector.column].color ~= 9 and
        panels[vector.row + 1][vector.column].color ~= 0
     then
      if vector.column == 1 then
        return panels[vector.row][vector.column + 1].color == 0
      elseif vector.column == 6 then
        return panels[vector.row][vector.column - 1].color == 0
      else
        return (panels[vector.row][vector.column + 1].color == 0 or panels[vector.row][vector.column - 1].color == 0)
      end
    else
      return false
    end
  end
end

function StackExtensions.findActions(cpuStack)
  local latentMatches = StackExtensions.findLatentMatchesFromCpuStack(cpuStack)
  return StackExtensions.evaluateLatentMatches(latentMatches, cpuStack:GetPanels())
end

--returns all actually possible matches for a latent match
--all actions returned from this have their estimatedCost and their targetVectors set
function StackExtensions.evaluateLatentMatches(latentMatches, panels)
  local possibleMatches = {}
  for i = 1, #latentMatches do
    local results = StackExtensions.evaluateLatentMatch(latentMatches[i], panels)
    for j = 1, #results do
      table.insert(possibleMatches, results[j])
    end
  end

  return possibleMatches
end

function StackExtensions.evaluateLatentMatch(latentMatch, panels)
  -- get concrete actions from ActionObject
  local concreteMatches = latentMatch:getConcreteMatchesFromLatentMatch()

  -- for each concrete action
  for i = #concreteMatches, 1, -1 do
    -- check if action is actually possible to execute (e.g. not switching with garbage)
    if StackExtensions.actionIsValidByPanels(panels, concreteMatches[i]) then
      -- if ActionValidator.ActionIsValid(cpuStack, concreteMatches[i]) then
      -- TODO Endaris
      -- check if action requires gap filling

      -- check if there are enough panels to fill the gap if it is required

      -- if yes or gap filling = false
      -- calculate estimated cost
      concreteMatches[i]:calculateCost()
    else
      table.remove(concreteMatches, i)
    end
  end

  return concreteMatches
end

function StackExtensions.getAllActionPanelsOfColorByRow(panels, color)
  local actionPanels = {}

  for row = 1, #panels do
    actionPanels[row] = {}
    for column = 1, #panels[row] do
      if panels[row][column].color == color then
        local actionPanel = ActionPanel(panels[row][column], row, column)
        table.insert(actionPanels[row], actionPanel)
      end
    end
  end

  return actionPanels
end

function StackExtensions.findLatentMatches(cpuStack)
  return StackExtensions.findLatentMatchesFromPanels(cpuStack:GetPanels())
end

function StackExtensions.findLatentMatchesFromCpuStack(cpuStack)
  local matches = {}
  local grid = RowGrid.FromPanels(cpuStack:GetPanels())

  for color = 1, 8 do
    local colorColumn = grid:GetColorColumn(color)
    local latentColorMatches = colorColumn:GetLatentMatches()
    local actionPanelsOfColor = cpuStack:GetPanelsOfColorByRow(color)

    for matchIndex = 1, #latentColorMatches do
      local match = latentColorMatches[matchIndex]
      if match.type == "H" then
        -- if there are 4 in the row, add 2 actions, there cannot be more than 4 (ignoring possible addition of 3D)
        for n = 1, #actionPanelsOfColor[match.row] - 2 do
          local actionPanels = {}

          table.insert(actionPanels, actionPanelsOfColor[match.row][n]:copy())
          table.insert(actionPanels, actionPanelsOfColor[match.row][n + 1]:copy())
          table.insert(actionPanels, actionPanelsOfColor[match.row][n + 2]:copy())

          CpuLog:log(6, "found horizontal 3 match in row " .. match.row .. " for color " .. color)
          --create the action and put it in our list
          table.insert(matches, H3Match(actionPanels))
        end
      else
        -- one possible match for each possible combination of panels in the 3 rows
        for q = 1, #actionPanelsOfColor[match.rows[1]] do
          for r = 1, #actionPanelsOfColor[match.rows[2]] do
            for s = 1, #actionPanelsOfColor[match.rows[3]] do
              local actionPanels = {}
              table.insert(actionPanels, actionPanelsOfColor[match.rows[1]][q]:copy())
              table.insert(actionPanels, actionPanelsOfColor[match.rows[2]][r]:copy())
              table.insert(actionPanels, actionPanelsOfColor[match.rows[3]][s]:copy())
              table.insert(matches, V3Match(actionPanels))
            end
          end
        end
      end
    end
  end
  return matches
end

-- finds all potential 3 matches on the board using the rowgrid scan
function StackExtensions.findLatentMatchesFromPanels(panels)
  local matches = {}
  local grid = RowGrid.FromPanels(panels)

  --iterating to 8 instead of #grid[1] because color 9 is garbage which is included in the rowGrid but cannot form matches
  for color = 1, 8 do
    local colorColumn = grid:GetColorColumn(color)
    local latentColorMatches = colorColumn:GetLatentMatches()
    local actionPanelsOfColor = cpuStack:GetPanelsOfColorByRow(color)

    for matchIndex = 1, #latentColorMatches do
      local match = latentColorMatches[matchIndex]
      if match.type == "H" then
        -- if there are 4 in the row, add 2 actions, there cannot be more than 4 (ignoring possible addition of 3D)
        for n = 1, #actionPanelsOfColor[match.row] - 2 do
          local actionPanels = {}

          table.insert(actionPanels, actionPanelsOfColor[match.row][n]:copy())
          table.insert(actionPanels, actionPanelsOfColor[match.row][n + 1]:copy())
          table.insert(actionPanels, actionPanelsOfColor[match.row][n + 2]:copy())

          CpuLog:log(6, "found horizontal 3 match in row " .. match.row .. " for color " .. color)
          --create the action and put it in our list
          table.insert(matches, H3Match(actionPanels))
        end
      else
        -- one possible match for each possible combination of panels in the 3 rows
        for q = 1, #actionPanelsOfColor[match.rows[1]] do
          for r = 1, #actionPanelsOfColor[match.rows[2]] do
            for s = 1, #actionPanelsOfColor[match.rows[3]] do
              local actionPanels = {}
              table.insert(actionPanels, actionPanelsOfColor[match.rows[1]][q]:copy())
              table.insert(actionPanels, actionPanelsOfColor[match.rows[2]][r]:copy())
              table.insert(actionPanels, actionPanelsOfColor[match.rows[3]][s]:copy())
              table.insert(matches, V3Match(actionPanels))
            end
          end
        end
      end
    end
  end
  return matches
end

function StackExtensions.swapIsValid(panel1, panel2)
  return not panel1.panel:exclude_swap() and not panel2.panel:exclude_swap()
end

function StackExtensions.moveIsValid(stack, panelId, targetVector)
  return StackExtensions.moveIsValidByPanels(stack.panels, panelId, targetVector)
end

function StackExtensions.moveIsValidByPanels(panels, panel, targetVector)
  if panel:row() < targetVector.row then
    return false
  else
    local panelAtTarget = StackExtensions.getPanelByVectorByPanels(panels, targetVector)
    -- TODO Endaris: check swapIsValid for every panel we need to swap with along the way
    if not StackExtensions.swapIsValid(panel, panelAtTarget) then
      --CpuLog:log(1, "swapping for one of the two panels is not valid")
      --CpuLog:log(1, "panel1 swappable: " .. tostring(not panel1:exclude_swap()))
      --CpuLog:log(1, "panel2 swappable: " .. tostring(not panel2:exclude_swap()))
      return false
    else
      -- this is very naive and certainly not true in some cases but should be fine for a start
      return true
    end
  end
end

function StackExtensions.getPanelById(stack, id)
  return StackExtensions.getPanelById(stack.panels, id)
end

function StackExtensions.getPanelByIdFromPanels(panels, id)
  for i = 1, #panels do
    for j = 1, #panels[1] do
      if panels[i][j].id == id then
        panels[i][j].height = i
        panels[i][j].width = j
        return panels[i][j]
      end
    end
  end

  return nil
end

function StackExtensions.getPanelByVector(stack, vector)
  return StackExtensions.getPanelByVectorByPanels(stack.panels, vector)
end

function StackExtensions.getPanelByVectorByPanels(panels, vector)
  CpuLog:log(5, "Attempting to get panel at vector " .. vector:toString())
  local panel = panels[vector.row][vector.column]
  CpuLog:log(5, "Turned up with panel " .. panel:toString())
  return panel
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
  CpuLog:log(5, "checking if action is valid " .. action:toString())

  for i = 1, #action.panels do
    if
      action.panels[i].panel.state == "matched" or action.panels[i].panel.state == "popping" or
        action.panels[i].panel.state == "popped" or
        action.panels[i].panel.state == "dimmed" or
        action.panels[i].panel.state == "falling" or
        action.panels[i].panel.state == "hovering" or
        action.panels[i].panel.state == "swapping"
     then --technically not necessary but probably still getting swapped by the last action
      CpuLog:log(5, "action marked invalid due to panelstate " .. action.panels[i].panel.state)
      return false
    end
  end

  for i = 1, #action.panels do
    CpuLog:log(5, "checking if move is valid for " .. action.panels[i]:toString())
    if not StackExtensions.moveIsValidByPanels(panels, action.panels[i], action.panels[i].targetVector) then
      return false
    end
  end

  return true
end

-- not really equal but sufficiently equal
function StackExtensions.stacksAreEqual(stack, otherStack)
  if stack and otherStack and stack.panels and otherStack.panels then
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

  for i = 1, #panels do
    for j = 1, #panels[i] do
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
  elseif self.id == otherPanel.id and self.state == otherPanel.state and self.chaining == otherPanel.chaining then
    return true
  else
    return false
  end
end

function Panel.toString(self)
  local stringRep = "Panel in state " .. self.state .. ""

  if self.width and self.height then
    stringRep = stringRep .. " at coordinate " .. GridVector(self.height, self.width):toString()
  end

  return stringRep
end

function StackExtensions.getGarbage(stack)
  return StackExtensions.getGarbageByPanels(stack.panels)
end

function StackExtensions.getGarbageByPanels(panels)
  local garbagePanels = {}
  for i = 1, #panels do
    for j = 1, #panels[i] do
      if panels[i][j].color == 9 and panels[i][j]:exclude_swap() and panels[i][j].state ~= "falling" then
        table.insert(garbagePanels, ActionPanel(panels[i][j], i, j))
      end
    end
  end

  return garbagePanels
end

function StackExtensions.getActionPanelsFromStack(stack)
  return StackExtensions.getActionPanelsFromPanels(stack.panels)
end

function StackExtensions.getActionPanelsFromPanels(panels)
  local actionPanels = {}

  for row = 1, #panels do
    actionPanels[row] = {}
    for column = 1, #panels[row] do
      actionPanels[row][column] = ActionPanel(panels[row][column], row, column)
    end
  end

  return actionPanels
end
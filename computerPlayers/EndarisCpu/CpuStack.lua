-- well shit²
-- this seeks to emulate stack transformations on a simplified level to evaluate Actions and aid in pathfinding

local CpuSwapDirection = { Right = 1, Left = -1}
local InputType = { Move = 1, Swap = 2}

CpuStack =
  class(
  function(self, stackRows, cursorPos, CLOCK, cpuConfig, level)
    self.rows = stackRows
    -- create columns
    self.columns = {}
    for column = 1, #self.rows[1].columns do
      self.columns[column] = CpuStackColumn(self.rows, column)
    end
    self.CLOCK = CLOCK
    self.cursorPos = cursorPos
    self.cpuConfig = cpuConfig
    self.lastInputType = InputType.Move
    if level then
      self.level = level
    else
      self.level = 5
    end
  end
)

function CpuStack.AsAprilStack(self)
  return StackExtensions.AsAprilStackByPanels(self:GetPanels())
end

function CpuStack.GetPanels(self)
  return table.map(self.rows, function (row) return row.columns end)
end

function CpuStack.Clone(self)
  return deepcopy(self)
end

function CpuStack.GetRow(self, row)
  return self.rows[row]
end

function CpuStack.GetColumn(self, column)
  return self.columns[column]
end

function CpuStack.GetPanelByVector(self, vector)
  return self:GetPanelByRowColumn(vector.row, vector.column)
end

function CpuStack.GetPanelByRowColumn(self, row, column)
  return self.rows[row]:GetPanelInColumn(column)
end

function CpuStack.GetPanelNeighboringPanel(self, panel, direction)
  if self.columns[panel:column() + direction] then
    return self:GetPanelByRowColumn(panel:row(), panel:column() + direction)
  else
    return nil
  end
end

-- returns the other swapped panel if the swap did something, false if not
function CpuStack.Swap(self, panel, direction)
  if panel.isSwappable then
    self:UpdateCursor(panel, direction)
    self:UpdateClockWithSwap()
    local otherSwappedPanel = self.rows[panel:row()]:Swap(panel, direction)
    if otherSwappedPanel then
      for _, value in pairs({panel, otherSwappedPanel}) do
        self:GetColumn(value.vector.column):DropPanels()
      end
      return otherSwappedPanel
    end
  end
  -- supposedly nothing happens at all because the swap attempt included a (clear)wall or garbage
  return nil
end

function CpuStack.UpdateCursor(self, panel, swapDirection)
  local cursorTarget = CpuStack.GetCursorTarget(panel, swapDirection)
  local numberOfInputs = cursorTarget:distance(self.cursorPos)
  self.cursorPos = cursorTarget
  self:UpdateClockWithCursorMovement(numberOfInputs)
end

function CpuStack.UpdateClockWithCursorMovement(self, numberOfInputs)
  for i=1, numberOfInputs do
    if self.lastInputType == InputType.Move then
      self.CLOCK = self.CLOCK + self.cpuConfig.MoveRateLimit
    else
      self.CLOCK = self.CLOCK + self.cpuConfig.MoveSwapRateLimit
      self.lastInputType = InputType.Move
    end
  end
end

function CpuStack.UpdateClockWithSwap(self)
  self.CLOCK = self.CLOCK + self.cpuConfig.MoveSwapRateLimit
  self.lastInputType = InputType.Swap
end

function CpuStack.GetCursorTarget(panel, swapDirection)
  if swapDirection == CpuSwapDirection.Right then
    return panel.vector
  else
    return panel.vector:substract(GridVector(0, 1))
  end
end

function CpuStack.GetSwapDirection(panel)
  if panel.vector.column > panel.targetVector.column then
    return CpuSwapDirection.Left
  elseif panel.vector.column < panel.targetVector.column then
    return CpuSwapDirection.Right
  else
    error("jokes on you, swapping vertically isn't going to work and a strategy for downstacking a panel to reinsert it into it's original row does not exist yet")
  end
end

function CpuStack.SimulatePanelAction(self, action)
  if action.panels then
    for i=1, #action.panels do
      local panel = action.panels[i]
      while not panel.vector:equals(panel.targetVector) do
        local swapDirection = CpuStack.GetSwapDirection(panel)
        local otherPanel = self:Swap(panel, swapDirection)

        local matchTypes = self:GetMatchTypes(panel)
        if matchTypes.Horizontal or matchTypes.Vertical then
          return
        end

        matchTypes = self:GetMatchTypes(otherPanel)
        if matchTypes.Horizontal then
          CpuStack:SimulateHorizontalMatch(otherPanel)
        elseif matchTypes.Vertical then
          CpuStack:SimulateVerticalMatch(otherPanel)
        end
      end
    end
  end
end

function CpuStack.SimulateHorizontalMatch(self, panel)
  -- this is probably stupid but for now i'm just going to transform them into unswappable panels and see what happens
  local row = self:GetRow(panel.vector.row)
  for _, direction in pairs(CpuSwapDirection) do
    local nextPanel = panel
    while (nextPanel.color == panel.color) do
      if nextPanel.color == panel.color then
        nextPanel.isSwappable = false
      end

      nextPanel = row:GetPanelNeighboringPanel(panel, direction)
    end
  end
end

function CpuStack.SimulateVerticalMatch(self, panel)
  -- this is probably stupid but for now i'm just going to transform them into unswappable panels and see what happens
  local column = self:GetColumn(panel.vector.column)
  for _, direction in pairs(CpuSwapDirection) do
    local nextPanel = panel
    while (nextPanel.color == panel.color) do
      if nextPanel.color == panel.color then
        nextPanel.isSwappable = false
      end

      nextPanel = column:GetPanelNeighboringPanel(panel, direction)
    end
  end
end

function CpuStack.GetMatchTypes(self, panel)
  local matches = { Horizontal = false, Vertical = false}

  -- horizontal
  local row = self:GetRow(panel.vector.row)
  if row:GetPanelNeighboringPanel(panel, CpuSwapDirection.Left).color == panel.color and
     row:GetPanelNeighboringPanel(panel, CpuSwapDirection.Right).color == panel.color then
    matches.Horizontal = true
  end

  -- vertical
  local column = self:GetColumn(panel.vector.column)
  if column:GetPanelNeighboringPanel(panel, CpuSwapDirection.Left).color == panel.color and
     column:GetPanelNeighboringPanel(panel, CpuSwapDirection.Right).color == panel.color then
      matches.Vertical = true
  end

  return matches
end

function CpuStack.GetColumnHeight(self, column)
  return self.columns[column]:GetHeight()
end

function CpuStack.GetTiers(self)
  local tiers = {}
  local firstGarbageRowIndex = 0
  local tierSeparatorReached = false
  local stackRowsForNewTier = {}
  for row = 1, #self.rows do
    if not tierSeparatorReached then
      if table.trueForAny(self.rows[row].columns, function(panel) return panel:isMatchable() end) then
        if firstGarbageRowIndex == 0 and
           table.trueForAny(self.rows[row].columns, function(panel) return panel.color == 9 end) then
          firstGarbageRowIndex = row
        end
      else
        if firstGarbageRowIndex == 0 then
          -- need to set this for single row tiers
          firstGarbageRowIndex = row
        end
        tierSeparatorReached = true
      end
      table.insert(stackRowsForNewTier, self.rows[row])
    else
      if table.trueForAll(self.rows[row].columns, function(panel) return not panel:isMatchable() end) then
        table.insert(stackRowsForNewTier, self.rows[row])
      else
        table.insert(tiers, CpuStackTier(stackRowsForNewTier, stackRowsForNewTier[1].rowIndex))
        tierSeparatorReached = false
        stackRowsForNewTier = {}
        for reRow = firstGarbageRowIndex, row - 1 do
          table.insert(stackRowsForNewTier, self.rows[reRow]:GetWithoutMatchablePanels())
        end
        -- last row is the new row that has matchable panels that are part of the tier so we want them of course
        table.insert(stackRowsForNewTier, self.rows[row])
        firstGarbageRowIndex = 0
      end
    end
  end
  -- insert the final tier manually
  table.insert(tiers, CpuStackTier(stackRowsForNewTier, stackRowsForNewTier[1].rowIndex))
  return tiers
end

function CpuStack.GetPanelsOfColorByRow(self, color)
  local rowPanels = {}
  for row = 1, #self.rows do
    table.insert(rowPanels, self.rows[row]:GetPanelsOfColor(color))
  end
  return rowPanels
end


CpuStackTier =
  class(
  function(cpuStack, stackRows, rowOffset)
    CpuStack.init(cpuStack, stackRows)
    cpuStack.rowOffset = rowOffset
  end,
  CpuStack
  )

function CpuStackTier.GetTiers(self)
  return {self}
end

CpuStackRow =
  class(
  function(self, columnArray, rowIndex)
    self.columns = columnArray
    self.rowIndex = rowIndex
  end
)

function CpuStackRow.GetStackRowsFromStack(stack)
  return CpuStackRow.GetStackRowsFromPanels(stack.panels)
end

function CpuStackRow.GetStackRowsFromPanels(panels)
  return CpuStackRow.GetStackRowsFromActionPanels(StackExtensions.getActionPanelsFromPanels(panels))
end

function CpuStackRow.GetStackRowsFromActionPanels(actionPanels)
  local independentActionPanels = deepcopy(actionPanels)
  -- create rows
  local stackRows = {}
  for row = 1, #independentActionPanels do
    stackRows[row] = CpuStackRow(independentActionPanels[row], row)
  end
  return stackRows
end

function CpuStackRow.GetWithoutMatchablePanels(self)
  local columns = table.filter(self.columns, function(panel) return not panel:isMatchable() end)
  return CpuStackRow(columns, self.rowIndex)
end

function CpuStackRow.GetPanelInColumn(self, column)
  return self.columns[column]
end

function CpuStackRow.GetPanelNeighboringPanel(self, panel, direction)
  if panel.vector.column + direction > 0 and panel.vector.column + direction < 7
  and self.columns[panel.vector.column + direction] then
    return self:GetPanelInColumn(panel.vector.column + direction)
  else
    local imaginaryPanel = ActionPanel(Panel(0), panel.vector.row, panel.vector.column + direction)
    imaginaryPanel.color = 0
    imaginaryPanel.isSwappable = false
    return imaginaryPanel
  end
end

-- returns other swapped panel if the swap is successful, nil if not
function CpuStackRow.Swap(self, panel, direction)
  if not panel.isSwappable then
    return nil
  end

  local otherPanel = self:GetPanelNeighboringPanel(panel, direction)
  if otherPanel and otherPanel.isSwappable then
    local vec = panel.vector:copy()
    panel:setVector(otherPanel.vector:copy())
    otherPanel:setVector(vec)
    table.sort(self.columns, function(a,b) return a.vector.column < b.vector.column end)
    return otherPanel
  else
    return nil
  end
end

function CpuStackRow.AddPanel(self, panel)
  assert(self.columns[panel:column()].color == 0)
  self.columns[panel:column()] = panel
end

function CpuStackRow.RemovePanel(self, panel)
  self.columns[panel.vector.column] = ActionPanel(Panel(0), panel.vector.row, panel.vector.column)
end

function CpuStackRow.GetMatchablePanelCount(self)
  return #table.filter(self.columns, function(panel) return panel:isMatchable() end)
end

function CpuStackRow.GetPanelsOfColor(self, color)
  local panels = {}
  for column=1, #self.columns do
    if self.columns[column].color == color then
      table.insert(panels, self.columns[column])
    end
  end
  return panels
end

CpuStackColumn =
  class(
  function(self, cpuStackRows, columnIndex)
    self.cpuStackRows = cpuStackRows
    self.columnIndex = columnIndex
  end
)

function CpuStackColumn.GetPanelInRow(self, row)
  return self.cpuStackRows[row].columns[self.columnIndex]
end

function CpuStackColumn.GetColumnArray(self)
  local columnArray = {}
  for row=1, #self.cpuStackRows do
    columnArray[row] = self.cpuStackRows[row][self.columnIndex]
  end
  return columnArray
end

-- TODO Endaris:
-- Consider the way garbage panels are connected with each other
-- Otherwise this will just drop down garbage panels as well when it shouldn't
function CpuStackColumn.DropPanels(self)
  local emptyRows = {}
  local floatingRows = {}
  for row = 1, #self.cpuStackRows do
    if self.cpuStackRows[row].columns[self.columnIndex].color == 0 then
      table.insert(emptyRows, row)
    else
      if #emptyRows > 0 then
        table.insert(floatingRows, row)
      end
    end
  end

  while #floatingRows > 0 do
    local floatingRow = table.remove(floatingRows, 1)
    local panel = self.cpuStackRows[floatingRow].columns[self.columnIndex]
    self.cpuStackRows[floatingRow]:RemovePanel(panel)
    table.insert(emptyRows, floatingRow)
    self.cpuStackRows[emptyRows[1]]:AddPanel(panel)
    panel.vector = GridVector(emptyRows[1], panel.vector.column)
    table.remove(emptyRows, 1)
    table.sort(emptyRows)
  end
end

function CpuStackColumn.GetMatchablePanelCount(self)
  local count = 0
  for row = 1, #self.cpuStackRows do
    local panel = self:GetPanelInRow(row)
    if panel:isMatchable() then
      count = count + 1
    end
  end
  return count
end

function CpuStackColumn.GetHeight(self)
  local remainingPanelCount = self:GetPanelCount()
  for row = 1, #self.cpuStackRows do
    local panel = self:GetPanelInRow(row)
    if remainingPanelCount > 0 then
      if panel:isMatchable() then
        remainingPanelCount = remainingPanelCount - 1
      end
    else
      if panel.color == 0 then
        return row
      end
    end
  end
end

function CpuStackColumn.GetHeightWithoutGarbage(self)
  for row = 1, #self.cpuStackRows do
    local panel = self:GetPanelAtRow(row)
    if panel.color == 0 or panel.color == 9 then
      return row - 1
    end
  end
end

function CpuStackColumn.GetPanelNeighboringPanel(self, panel, direction)
  if panel.vector.row + direction > 0 and self.cpuStackRows[panel.vector.row + direction] then
    return self:GetPanelInRow(panel.vector.row + direction)
  else
    local imaginaryPanel = ActionPanel(Panel(0), panel.vector.row + direction, self.columnIndex)
    imaginaryPanel.color = 0
    imaginaryPanel.isSwappable = false
    return imaginaryPanel
  end
end
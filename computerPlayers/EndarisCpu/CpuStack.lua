-- well shit²
-- this seeks to emulate stack transformations on a simplified level to evaluate Actions and aid in pathfinding
require("StackExtensions")

local CpuSwapDirection = { Right = 1, Left = -1}

CpuStack =
  class(
  function(self, stackRows)
    self.rows = stackRows
    -- create columns
    self.columns = {}
    for column = 1, #self.rows[1].panels do
      self.columns[column] = CpuStackColumn(self.rows, column)
    end
  end
)

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
  if self.columns[panel.column + direction] then
    return self:GetPanelByRowColumn(panel.row, panel.column + direction)
  else
    return nil
  end
end

-- returns the other swapped panel if the swap did something, false if not
function CpuStack.Swap(self, panel, direction)
  if not panel:exclude_swap() then
    local otherSwappedPanel = self.rows[panel.row]:Swap(panel, direction)
    if otherSwappedPanel then
      for _, value in pairs({panel, otherSwappedPanel}) do
        self:GetColumn(value.column):DropPanels()
      end
      return otherSwappedPanel
    end
  end
  -- supposedly nothing happens at all because the swap attempt included a (clear)wall or garbage
  return nil
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
      if table.trueForAny(self.rows[row], function(panel) return panel:isMatchable() end) then
        if firstGarbageRowIndex == 0 and
           table.trueForAny(self.rows[row], function(panel) return panel.color == 9 end) then
          firstGarbageRowIndex = row
        end
        table.insert(stackRowsForNewTier, self.rows[row])
      else
        tierSeparatorReached = true
      end
    else
      if table.trueForAll(self.rows[row], function(panel) return not panel:isMatchable() end) then
        table.insert(stackRowsForNewTier, self.rows[row])
      else
        table.insert(tiers, CpuStackTier(stackRowsForNewTier, stackRowsForNewTier[1].rowIndex))
        tierSeparatorReached = false
        stackRowsForNewTier = {}
        for reRow = firstGarbageRowIndex, row do
          table.insert(stackRowsForNewTier, self.rows[reRow]:GetWithoutMatchablePanels())
        end
        firstGarbageRowIndex = 0
      end
    end
  end
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
  local independentActionPanels = deepcopy(StackExtensions.getActionPanelsFromStack(stack))
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
  if self.columns[panel.column + direction] then
    return self:GetPanelInColumn(panel.column + direction)
  else
    return nil
  end
end

-- returns other swapped panel if the swap is successful, nil if not
function CpuStackRow.Swap(self, panel, direction)
  local otherPanel = self:GetPanelNeighboringPanel(panel, direction)
  if otherPanel and not otherPanel:exclude_swap() then
    local vec = panel.vector:copy()
    panel:setVector(otherPanel.vector:copy())
    otherPanel:setVector(vec)
    table.sort(self.panels, function(a,b) return a.column < b.column end)
    return otherPanel
  else
    return nil
  end
end

function CpuStackRow.AddPanel(self, panel)
  assert(self.columns[panel.column].color == 0)
  self.columns[panel.column] = panel
end

function CpuStackRow.RemovePanel(self, panel)
  self.columns[panel.column] = ActionPanel(Panel(0), panel.row, panel.column)
end

function CpuStackRow.GetMatchablePanelCount(self)
  return #table.filter(self.columns, function(panel) return panel:isMatchable() end)
end

CpuStackColumn =
  class(
  function(self, cpuStackRows, columnIndex)
    self.cpuStackRows = cpuStackRows
    self.columnIndex = columnIndex
  end
)

function CpuStackColumn.GetPanelInRow(self, row)
  return self.cpuStackRows[row][self.columnIndex]
end

function CpuStackColumn.GetColumnArray(self)
  local columnArray = {}
  for row=1, #self.cpuStackRows do
    columnArray[row] = self.cpuStackRows[row][self.columnIndex]
  end
  return columnArray
end

function CpuStackColumn.DropPanels(self)
  local emptyRows = {}
  local floatingRows = {}
  for row = 1, #self.cpuStackRows do
    if self.cpuStackRows[row][self.columnIndex].color == 0 then
      table.insert(emptyRows, row)
    else
      if #emptyRows > 0 then
        table.insert(floatingRows, row)
      end
    end
  end

  while #floatingRows > 0 do
    local floatingRow = table.remove(floatingRows, 1)
    local panel = self.cpuStackRows[floatingRow][self.columnIndex]
    self.cpuStackRows[floatingRow]:RemovePanel(panel)
    table.insert(emptyRows, floatingRow)
    self.cpuStackRows[emptyRows[1]]:AddPanel(panel)
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
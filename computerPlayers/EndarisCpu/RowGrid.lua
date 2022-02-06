require("computerPlayers.EndarisCpu.StackExtensions")

RowGrid = class(function(self, panels)
    self.panels = panels
    self.sourcePanelSection = nil
    self.gridRows = self:getGridRows()
end)

function RowGrid.getGridRows(self)
    local rowGridRows = {}
    StackExtensions.printAsAprilStack(self.panels)
    for rowIndex = 1, #self.panels do
        local rowPanels = {}
        for columnIndex = 1, #self.panels[rowIndex] do
            table.insert(rowPanels, self.panels[rowIndex][columnIndex])
        end

        table.insert(rowGridRows, RowGridRow(rowIndex, rowPanels))
    end

    return rowGridRows
end

function RowGrid.FromStack(stack)
    return RowGrid.FromPanels(stack.panels)
end

function RowGrid.FromPanels(panels)
    return RowGrid(panels)
end

function RowGrid.FromConnectedPanelSection(connectedPanelSection)
    return RowGrid.FromPanels(connectedPanelSection.panels)
end

function RowGrid.Subtract(rowgrid1, rowgrid2)

end

function RowGrid.MoveDownPanel(self, color, row)
    if self:DropIsValid(row) then
        local rowToDropFrom = self.gridRows[row]
        local receivingRow = self.gridRows[row - 1]
        rowToDropFrom:RemovePanel(color)
        receivingRow:AddPanel(color)
        return self
    else
        return nil
    end
end

function RowGrid.DropIsValid(self, row)
    if row <= 0 then
        return false
    else
    -- local rowsBelow = table.where(self.gridRows.rowIndex, function(gridRow) return gridRow.rowIndex < row end)
    -- return table.any(rowsBelow, function(gridRow) return gridRow.emptyPanelCount > 0 end)
    end
end

-- returns true if the rowGrid is valid
-- returns the index of the invalid row otherwise
function RowGrid.IsValid(self)
    -- local invalidRow = table.firstOrDefault(self.gridRows, function(row) return not row:IsValid() end)
    -- if invalidRow then
    --  return invalidRow.rowIndex
    -- else
    --    local emptyPanelsCount = gridRows[#gridRows].emptyPanelsCount
    --    for i = #gridRows - 1, 1 do
    --      if gridRows[i].emptyPanelsCount > emptyPanelsCount then
    --          return i
    --      end
    --    end
    --    return true
    -- end
end

function RowGrid.GetColorColumn(self, color)
    return ColorGridColumn(self, color)
end

function RowGrid.GetTotalEmptyPanelCountInRowAndBelow(self, rowIndex)
    -- measure the empty panels per row to see later how low the stack can potentially get
    local totalEmptyPanelCountInRowAndBelow = 0
    for row=1,rowIndex do
        totalEmptyPanelCountInRowAndBelow =
            totalEmptyPanelCountInRowAndBelow + self.gridRows[row].emptyPanelsCount
    end

    return totalEmptyPanelCountInRowAndBelow
end

function RowGrid.GetTotalPanelCountAboveRow(self, rowIndex)
    local totalPanelCountAboveRow = 0
    for row = rowIndex + 1, #self.gridRows do
        totalPanelCountAboveRow = totalPanelCountAboveRow + self.gridRows[row].panelCount
    end

    return totalPanelCountAboveRow
end

-- returns the minimum rowindex the rowgrid can be downstacked into
function RowGrid.GetMinimumTopRowIndex(self)

end

RowGridRow = class(function(self, rowIndex, panels)
    self.rowIndex = rowIndex
-- always use at least 9: shockpanels (8) and garbage (9) appear on every level
-- column 10 is for storing arbitrary panels during downstack analysis

            --color 1  2  3  4  5  6  7  8  9 10
    self.columns = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    for i = 1, #panels do
        -- the idea is that columnnumber=color number for readability
        self.columns[panels[i].color] = self.columns[panels[i].color] + 1
    end

    self.emptyPanelCount = 6 - #panels
    self.panelCount = #panels
end)

function RowGridRow.AddPanel(self, color)
    self.columns[color] = self.columns[color] + 1
    self.emptyPanelCount = self.emptyPanelCount - 1
    self.panelCount = self.panelCount + 1
end

function RowGridRow.RemovePanel(self, color)
    self.columns[color] = self.columns[color] - 1
    self.emptyPanelCount = self.emptyPanelCount + 1
    self.panelCount = self.panelCount - 1
end

function RowGridRow.GetCount(self, color)
    return self.columns[color]
end

function RowGridRow.IsValid(self)
    return self.emptyPanelCount >= 0
end

ColorGridColumn = class(function(self, rowGrid, color)
    self.sourceRowGrid = rowGrid
    self.color = color
end)

function ColorGridColumn.GetColumnRepresentation(self)
    local count = {}
    for row = 1, #self.sourceRowGrid.gridRows do
        count[row] = self.sourceRowGrid.gridRows[row]:GetCount(self.color)
    end
    return count
end

function ColorGridColumn.GetMatches(self)

end

-- drops one panel in the specified row by one row and returns the new column representation
function ColorGridColumn.DropPanel(self, row)
    local newRowGrid = self.sourceRowGrid:MoveDownPanel(self.color, row)
    if newRowGrid then
        return self:GetColumnRepresentation()
    else
        return nil
    end
end

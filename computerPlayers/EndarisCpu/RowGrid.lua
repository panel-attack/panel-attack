require("computerPlayers.EndarisCpu.StackExtensions")

RowGrid = class(function(self, gridRows)
    self.gridRows = gridRows
end)

function RowGrid.getGridRows(panels)
    local rowGridRows = {}
    StackExtensions.printAsAprilStack(panels)
    for rowIndex = 1, #panels do
        rowGridRows[rowIndex] = RowGridRow.FromPanels(rowIndex, panels[rowIndex])
    end

    return rowGridRows
end

function RowGrid.FromStack(stack)
    return RowGrid.FromPanels(stack.panels)
end

function RowGrid.FromPanels(panels)
    return RowGrid(RowGrid.getGridRows(panels))
end

function RowGrid.FromConnectedPanelSection(connectedPanelSection)
    return RowGrid.FromPanels(connectedPanelSection.panels)
end

function RowGrid.Subtract(rowgrid1, rowgrid2)
    local diffGridRows = {}

    for gridRowIndex = 1, #rowgrid1 do
        diffGridRows[gridRowIndex] = RowGridRow.Subtract(rowgrid1[gridRowIndex], rowgrid2[gridRowIndex])
    end

    return RowGrid(diffGridRows)
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
-- additionally returns the index of the invalid row if false
function RowGrid.IsValid(self)
    -- local invalidRow = table.firstOrDefault(self.gridRows, function(row) return not row:IsValid() end)
    -- if invalidRow then
    --  return false, invalidRow.rowIndex
    -- else
    --    local emptyPanelsCount = gridRows[#gridRows].emptyPanelsCount
    --    for i = #gridRows - 1, 1 do
    --      if gridRows[i].emptyPanelsCount > emptyPanelsCount then
    --          return false, i
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
    local totalEmptyPanelCountInRowAndBelow = 0
    local totalPanelCountAboveRow = self:GetTotalPanelCountAboveRow(0)
    for row = 1, #self.gridRows do
        totalEmptyPanelCountInRowAndBelow = totalEmptyPanelCountInRowAndBelow + self.gridRows[row].emptyPanelsCount
        totalPanelCountAboveRow = totalPanelCountAboveRow - self.gridRows[row].panelCount
        if totalEmptyPanelCountInRowAndBelow >= totalPanelCountAboveRow then
            return row
        end
    end
end

RowGridRow = class(function(self, rowIndex, colorColumns)
    self.rowIndex = rowIndex
    self.colorColumns = colorColumns
    self.panelCount = 0
    for column = 1, #self.colorColumns do
        self.panelCount = self.panelCount + self.colorColumns[column]
    end
    self.emptyPanelCount = 6 - self.panelCount
end)

function RowGridRow.FromPanels(rowIndex, rowPanels)
    -- always use at least 9: shockpanels (8) and garbage (9) appear on every level
    -- column 10 is for storing arbitrary panels during downstack analysis

                  --color 1  2  3  4  5  6  7  8  9 10
    local colorColumns = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    for column = 1, #rowPanels do
        -- the idea is that columnnumber=color number for readability
        colorColumns[rowPanels[column].color] = colorColumns[rowPanels[column].color] + 1
    end

    return RowGridRow(rowIndex, colorColumns)
end

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

function RowGridRow.GetColorCount(self, color)
    return self.columns[color]
end

function RowGridRow.IsValid(self)
    return self.emptyPanelCount >= 0
end

function RowGridRow.Subtract(gridrow1, gridrow2)
    assert(gridrow1.rowIndex == gridrow2.rowIndex, "Subtracting 2 completely different rows doesn't make sense")
    local diffGridRowColumns = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

    for column = 1, #gridrow1.columns do
        diffGridRowColumns[column] = gridrow1.columns[column] - gridrow2.columns[column]
    end

    return RowGridRow(gridrow1.rowIndex, diffGridRowColumns)
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

function ColorGridColumn.GetLatentMatches(self)
    local consecutiveRowCount = 0
    local columnRepresentation = self:GetColumnRepresentation()
    local matches = {}

    for row = 1, #columnRepresentation do
        -- horizontal 3 matches
        if columnRepresentation[row] >= 3 then
            table.insert(matches, {type = "H", row = row})
        -- vertical 3 matches
        elseif columnRepresentation[row] < 3 and columnRepresentation[row] > 0 then
            consecutiveRowCount = consecutiveRowCount + 1
            if consecutiveRowCount >= 3 then
                table.insert(matches, {type = "V", rows = {row - 2, row - 1, row}})
            end
        else
            consecutiveRowCount = 0
        end
    end

    return matches
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

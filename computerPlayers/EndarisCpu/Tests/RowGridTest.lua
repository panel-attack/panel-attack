require("computerPlayers.EndarisCpu.RowGrid")
require("computerPlayers.EndarisCpu.StackExtensions")

local RowGridTest = class(function(self) end)

function RowGridTest.getAprilStringSample1()
  return "000000000000000000000000000000000000999000030000140000330000550005130001"
end

function RowGridTest.testGetMinimumTopRowIndex1()
  local aprilString = RowGridTest.getAprilStringSample1()
  local panels = StackExtensions.aprilStackToPanels(aprilString)
  -- actually two but until the garbage puzzles are integrated, the extra garbage panels make it 3
  local expectedValue = 3
  local rowGrid = RowGrid.FromPanels(panels)
  assert(rowGrid:GetMinimumTopRowIndex() == expectedValue)
end


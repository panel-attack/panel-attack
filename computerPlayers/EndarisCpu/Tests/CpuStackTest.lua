require("computerPlayers.EndarisCpu.StackExtensions")
require("computerPlayers.EndarisCpu.CpuStack")
local logger = require("logger")


-- test through all samples of the document and verify the expected results

local CpuStackTest = class(function(self) end)

local CpuConfig = {
  ReadingBehaviour = 'WaitMatch',
  Log = 4,
  MoveRateLimit = 10,
  MoveSwapRateLimit = 10,
  DefragmentationPercentageThreshold = 0.3
}

-- Tier test
function CpuStackTest.getAprilStringSample1()
    return "999999999999532565999999999999999999313251999999999001044001226253686451"
end

function CpuStackTest.getAprilStringSample2()
    return "000000000000000000000000000000000000800000800008880008888808888808888888"
end

function CpuStackTest.getAprilStringSample4()
    return "000000999999303000212000144500134450453550245210544311335835211322455243"
end

function CpuStackTest.testGetTiers()
  local aprilString = CpuStackTest.getAprilStringSample1()
  local panels = StackExtensions.aprilStackToPanels(aprilString)
  local actionPanels = StackExtensions.getActionPanelsFromPanels(panels)
  local row4WithoutMatchable = table.filter(actionPanels[4], function(panel) return not panel:isMatchable() end)

  local expectedValue = {
    -- Tier 1
    { actionPanels[1], actionPanels[2], actionPanels[3], actionPanels[4], actionPanels[5]},
    -- Tier 2
    { row4WithoutMatchable, actionPanels[5], actionPanels[6], actionPanels[7], actionPanels[8], actionPanels[9]},
    -- Tier 3
    { actionPanels[7], actionPanels[8], actionPanels[9], actionPanels[10], actionPanels[11], actionPanels[12]}
  }

  local cpuStack = CpuStack(CpuStackRow.GetStackRowsFromPanels(panels), GridVector(7, 3), 0, CpuConfig)
  local tiers = cpuStack:GetTiers()

  assert(#tiers == #expectedValue, "Wrong amount of tiers detected, got " .. #tiers .. " (expected ".. #expectedValue ..")")

  for i=1, #tiers do
    assert(#tiers[i].rows == #expectedValue[i],
    "Amount of rows in tier "..i.." does not match: "..#tiers[i].rows.." (expected "..#expectedValue[i]..")")
    for j=1, #tiers[i].rows do
      for k=1, #tiers[i].columns do
        assert(tiers[i].rows[j]:GetPanelInColumn(k):equals(expectedValue[i][j][k]),
        "Panel in tier "..i.." at coord"..j.."|"..k.." does not match the expected panel")
      end
    end
  end
  logger.trace("passed test testGetTiers")
end

function CpuStackTest.testSimulatePanelAction1()
  local aprilString = CpuStackTest.getAprilStringSample4()
  local panels = StackExtensions.aprilStackToPanels(aprilString)
  local cpuStack = CpuStack(CpuStackRow.GetStackRowsFromPanels(panels), GridVector(7, 3), 0, CpuConfig)
  local action = MovePanel(cpuStack, cpuStack:GetRow(1):GetPanelInColumn(6), GridVector(1, 1))

  cpuStack:SimulatePanelAction(action)
  --8 moves moving to 1|5 to start swapping the panel
  local expectedClock = 8 * CpuConfig.MoveRateLimit
  --5 swaps and 4 moves, starting and ending on a swap respectively
  expectedClock = expectedClock + 9 * CpuConfig.MoveSwapRateLimit

  local expectedRow1 = StackExtensions.getActionPanelsFromPanels(panels)[1]
  expectedRow1 = { expectedRow1[6], expectedRow1[1], expectedRow1[2], expectedRow1[3], expectedRow1[4], expectedRow1[5]}
  expectedRow1[1].vector = GridVector(1, 1)
  expectedRow1[2].vector = GridVector(1, 2)
  expectedRow1[3].vector = GridVector(1, 3)
  expectedRow1[4].vector = GridVector(1, 4)
  expectedRow1[5].vector = GridVector(1, 5)
  expectedRow1[6].vector = GridVector(1, 6)

  assert(cpuStack.CLOCK == expectedClock)
  local row1 = cpuStack:GetRow(1)
  for column=1, #row1.columns do
    assert(row1.columns[column]:equals(expectedRow1[column]))
  end
  assert(cpuStack.cursorPos:equals(GridVector(1, 1)))

  logger.trace("passed test testSimulatePanelAction1")
end

function CpuStackTest.testSimulatePanelActionWithDrop1()
  local aprilString = CpuStackTest.getAprilStringSample4()
  local panels = StackExtensions.aprilStackToPanels(aprilString)
  local cpuStack = CpuStack(CpuStackRow.GetStackRowsFromPanels(panels), GridVector(7, 3), 0, CpuConfig)
  local action = MovePanel(cpuStack, cpuStack:GetRow(7):GetPanelInColumn(5), GridVector(5, 6))

  cpuStack:SimulatePanelAction(action)
  --2 moves moving to 7|5 to start swapping the panel
  local expectedClock = 2 * CpuConfig.MoveRateLimit
  --1 swap
  expectedClock = expectedClock + CpuConfig.MoveSwapRateLimit

  local actionPanels = StackExtensions.getActionPanelsFromPanels(panels)
  local expectedRow5 = { actionPanels[5][1], actionPanels[5][2], actionPanels[5][3], actionPanels[5][4], actionPanels[5][5], actionPanels[7][5]}
  expectedRow5[6].vector = GridVector(5, 6)

  local expectedRow6 = actionPanels[6]
  local expectedRow7 = actionPanels[7]
  expectedRow7[5] = expectedRow7[6]
  expectedRow7[5].vector = GridVector(7, 5)

  assert(cpuStack.CLOCK == expectedClock)
  local row5 = cpuStack:GetRow(5)
  for column=1, #row5.columns do
    assert(row5.columns[column]:equals(expectedRow5[column]))
  end
  local row6 = cpuStack:GetRow(6)
  for column=1, #row6.columns do
    assert(row6.columns[column]:equals(expectedRow6[column]))
  end
  local row7 = cpuStack:GetRow(7)
  for column=1, #row7.columns - 1 do
    assert(row7.columns[column]:equals(expectedRow7[column]))
  end
  assert(row7.columns[6].color == 0)

  assert(cpuStack.cursorPos:equals(GridVector(7, 5)))

  logger.trace("passed test testSimulatePanelActionWithDrop1")
end

function CpuStackTest.testGetPanelInColumn()
  local aprilString = CpuStackTest.getAprilStringSample4()
  local panels = StackExtensions.aprilStackToPanels(aprilString)
  local cpuStack = CpuStack(CpuStackRow.GetStackRowsFromPanels(panels), GridVector(7, 3), 0, CpuConfig)
  local panel = cpuStack:GetRow(1):GetPanelInColumn(6)

  assert(panel.id == 5)
  assert(panel.color == 3)
  assert(panel.vector:equals(GridVector(1, 6)))

  logger.trace("passed test testGetPanelInColumn")
end


CpuStackTest.testGetTiers()
CpuStackTest.testGetPanelInColumn()
--CpuStackTest.testSimulatePanelActionWithDrop1()
CpuStackTest.testSimulatePanelAction1()
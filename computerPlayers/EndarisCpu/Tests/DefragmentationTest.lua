require("computerPlayers.EndarisCpu.StackExtensions")
require("computerPlayers.EndarisCpu.Defragmentation")

-- test through all samples of the document and verify the expected results

DefragmentationTest = class(function(self) end)

function DefragmentationTest.testGetPanelsAsColumnsByPanels()
    local aprilString = "000000000000000000000000000000000000800000800008880008880088880888880888"
    local expectedValue = {}
    expectedValue[1] = {8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0}
    expectedValue[2] = {8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0}
    expectedValue[3] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    expectedValue[4] = {8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    expectedValue[5] = {8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    expectedValue[6] = {8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0}
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local panelsAsColumns = StackExtensions.getPanelsAsColumnsByPanels(panels)
    for i = 1, 6 do
        for j = 1, 12 do
            assert(panelsAsColumns[i][j].color == expectedValue[i][j],
            --by courtesy of busterbeachside
            "ayo, bruh, I think " ..
                panelsAsColumns[i][j].color ..
                  " might not be the same as " .. expectedValue[i][j] .. 
                ", think again!")
        end
    end
    print("passed test getPanelsAsColumns")
end

function DefragmentationTest.testMaxConnectedTier1PanelsCount()
    local aprilString = "000000000000000000000000000000000000800000800008880008880088880888880888"
    local expectedValue = 9
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local maxConnectedTier1PanelsCount = StackExtensions.getMaxConnectedTier1PanelsCountByPanels(panels)

    assert(maxConnectedTier1PanelsCount == expectedValue, "Value is " .. maxConnectedTier1PanelsCount .. " (should be " ..  expectedValue .. ")")
    print("passed test maxConnectedTier1PanelsCount")
end

function DefragmentationTest.testGetTotalTier1PanelsCountByPanels()
    local aprilString = "000000000000000000000000000000000000800000800008880008880088880888880888"
    local expectedValue = 20
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local totalTier1PanelsCount = StackExtensions.getTotalTier1PanelsCountByPanels(panels)

    assert(totalTier1PanelsCount == expectedValue, "Value is " .. totalTier1PanelsCount .. " (should be " ..  expectedValue .. ")")
    print("passed test getTotalTier1PanelsCountByPanels")
end

function DefragmentationTest.testFragmentationPercentage1()
    -- can't use garbagePanels because the fragmentationPercentage function tests for them
    local aprilString = "000000000000000000000000000000000000800000800008880008880088880888880888"
    local expectedValue = 0.55
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local fragmentationPercentage = StackExtensions.getFragmentationPercentageByPanels(panels)

    assert(fragmentationPercentage == expectedValue, "FragmentationPercentage calculation is faulty with value " .. fragmentationPercentage .. " (should be " ..  expectedValue .. ")")
    print("passed test fragmentation percentage 1")
end

function DefragmentationTest.testFragmentationPercentage2()
    -- can't use garbagePanels because the fragmentationPercentage function tests for them
    local aprilString = "000000000000000000000000000000000000800000800008880008888808888808888888"
    local expectedValue = 1 - 14 / 22
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local fragmentationPercentage = StackExtensions.getFragmentationPercentageByPanels(panels)

    assert(fragmentationPercentage == expectedValue, "FragmentationPercentage calculation is faulty with value " .. fragmentationPercentage .. " (should be " ..  expectedValue .. ")")
    print("passed test fragmentation percentage 2")
end

function DefragmentationTest.testFragmentationPercentage3()
    -- can't use garbagePanels because the fragmentationPercentage function tests for them
    local aprilString = "000000000000000000000000000000000000000000000000888000888880888888888888"
    local expectedValue = 1 - 18 / 20
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local fragmentationPercentage = StackExtensions.getFragmentationPercentageByPanels(panels)

    assert(fragmentationPercentage == expectedValue, "FragmentationPercentage calculation is faulty with value " .. fragmentationPercentage .. " (should be " ..  expectedValue .. ")")
    print("passed test fragmentation percentage 3")
end

function DefragmentationTest.testGetTier1ConnectedPanelSectionsByPanels1()
    -- can't use garbagePanels because the function tests for them
    local aprilString = "000000000000000000000000000000000000800000800008880008880088880888880888"
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local expectedValue = {}
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(5, 2), 9, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 2), 8, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 2), 6, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(3, 6), 8, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(3, 5), 5, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 5), GridVector(3, 6), 6, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 5), GridVector(4, 6), 7, panels))

    local connectedSections = StackExtensions.getTier1ConnectedPanelSectionsByPanels(panels)
    assert(#connectedSections == 7, "wrong amount of sections found")

    for i=1,#expectedValue do
        local matched = false
        for j=1,#connectedSections do
            if expectedValue[i]:equals(connectedSections[j]) then
                matched = true
                break
            end
        end
        assert(matched, "couldn\'t find a match for section" .. expectedValue[i]:toString())
    end

    print("passed test getTier1ConnectedPanelSectionsByPanels1 (or maybe it isn't good enough)")
end

function DefragmentationTest.testGetTier1ConnectedPanelSectionsByPanels2()
-- can't use garbagePanels because the function tests for them
local aprilString = "000000000000000000000000000000000000800000800008880008888808888808888888"
local panels = StackExtensions.aprilStackToPanels(aprilString)

local expectedValue = {}
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(5, 2), 9, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 2), 8, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 2), 6, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 3), 11, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 3), 9, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(4, 3), 7, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(3, 3), 6, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 4), 14, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 4), 12, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(4, 4), 10, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(3, 4), 9, panels))
table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(3, 4), 6, panels))

local connectedSections = StackExtensions.getTier1ConnectedPanelSectionsByPanels(panels)
assert(#connectedSections == 12, "wrong amount of sections found (" .. #connectedSections .. ")")
-- test fails at the moment, reason:
-- false positive: ConnectedPanelSection with anchors 1|3, 4|4 containing a total of 6 panels
-- -> that section is not 4 rows high and therefore the same as 1|3 -> 4|3

for i=1,#connectedSections do
    print(connectedSections[i]:toString())
end

for i=1,#expectedValue do
    local matched = false
    for j=1,#connectedSections do
        if expectedValue[i]:equals(connectedSections[j]) then
            matched = true
            break
        end
    end
    assert(matched, "couldn\'t find a match for section" .. expectedValue[i]:toString())
end

print("passed test getTier1ConnectedPanelSectionsByPanels2 (or maybe it isn't good enough)")
end

DefragmentationTest.testGetPanelsAsColumnsByPanels()
DefragmentationTest.testGetTotalTier1PanelsCountByPanels()
DefragmentationTest.testMaxConnectedTier1PanelsCount()
DefragmentationTest.testFragmentationPercentage1()
DefragmentationTest.testFragmentationPercentage2()
DefragmentationTest.testFragmentationPercentage3()
DefragmentationTest.testGetTier1ConnectedPanelSectionsByPanels1()
DefragmentationTest.testGetTier1ConnectedPanelSectionsByPanels2()


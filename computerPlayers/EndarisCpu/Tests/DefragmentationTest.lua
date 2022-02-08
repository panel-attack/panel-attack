require("computerPlayers.EndarisCpu.StackExtensions")
require("computerPlayers.EndarisCpu.Defragmentation")

-- test through all samples of the document and verify the expected results

local DefragmentationTest = class(function(self) end)

function DefragmentationTest.getAprilStringSample1()
    return "000000000000000000000000000000000000800000800008880008880088880888880888"
end

function DefragmentationTest.getAprilStringSample2()
    return "000000000000000000000000000000000000800000800008880008888808888808888888"
end

function DefragmentationTest.getAprilStringSample4()
    return "000000999999303000212000144500134450453550245210544311335835211322455243"
end

function DefragmentationTest.getConnectedPanelSectionsSample1()
    local aprilString = DefragmentationTest.getAprilStringSample1()
    local panels = StackExtensions.aprilStackToPanels(aprilString)
    local expectedValue = {}
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(5, 2), 9, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 2), 8, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 2), 6, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(3, 6), 8, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(3, 5), 5, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 5), GridVector(3, 6), 6, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 5), GridVector(4, 6), 7, panels))
    return expectedValue
end

function DefragmentationTest.getConnectedPanelSectionsSample2()
    local aprilString = DefragmentationTest.getAprilStringSample2()
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
    return expectedValue
end

function DefragmentationTest.getConnectedPanelSectionsSample4()
    local aprilString = DefragmentationTest.getAprilStringSample4()
    local panels = StackExtensions.aprilStackToPanels(aprilString)
    local expectedValue = {}
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(10, 2), 19, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(9, 2), 18, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(8, 2), 16, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(7, 2), 14, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(6, 2), 12, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(5, 2), 10, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 2), 8, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 2), 6, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(10, 3), 29, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(9, 3), 27, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(8, 3), 24, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(7, 3), 21, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(6, 3), 18, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(5, 3), 15, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 3), 12, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 3), 9, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(9, 4), 35, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(8, 4), 32, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(7, 4), 28, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(6, 4), 24, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(5, 4), 20, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 4), 16, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 4), 12, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(8, 5), 39, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(7, 5), 35, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(6, 5), 30, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(5, 5), 25, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 5), 20, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 5), 15, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(5, 6), 29, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(4, 6), 24, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 1), GridVector(3, 6), 18, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(10, 3), 19, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(9, 3), 18, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(8, 3), 16, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(7, 3), 14, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(6, 3), 12, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(5, 3), 10, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(4, 3), 8, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(3, 3), 6, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(9, 4), 26, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(8, 4), 24, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(7, 4), 21, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(6, 4), 18, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(5, 4), 15, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(4, 4), 12, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(3, 4), 9, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(8, 5), 31, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(7, 5), 28, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(6, 5), 24, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(5, 5), 20, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(4, 5), 16, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(3, 5), 12, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(5, 6), 24, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(4, 6), 20, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 2), GridVector(3, 6), 15, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(9, 4), 17, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(8, 4), 16, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(7, 4), 14, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(6, 4), 12, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(5, 4), 10, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(4, 4), 8, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(3, 4), 6, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(8, 5), 23, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(7, 5), 21, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(6, 5), 18, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(5, 5), 15, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(4, 5), 12, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(3, 5), 9, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(5, 6), 19, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(4, 6), 16, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 3), GridVector(3, 6), 12, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(8, 5), 15, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(7, 5), 14, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(6, 5), 12, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(5, 5), 10, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(4, 5), 8, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(3, 5), 6, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(5, 6), 14, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(4, 6), 12, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 4), GridVector(3, 6), 9, panels))

    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 5), GridVector(5, 6), 9, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 5), GridVector(4, 6), 8, panels))
    table.insert(expectedValue, ConnectedPanelSection(GridVector(1, 5), GridVector(3, 6), 6, panels))

    return expectedValue
end

function DefragmentationTest.testGetPanelsAsColumnsByPanels()
    local aprilString = DefragmentationTest.getAprilStringSample1()
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
    local aprilString = DefragmentationTest.getAprilStringSample1()
    local expectedValue = 9
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local maxConnectedTier1PanelsCount = StackExtensions.getMaxConnectedTier1PanelsCountByPanels(panels)

    assert(maxConnectedTier1PanelsCount == expectedValue, "Value is " .. maxConnectedTier1PanelsCount .. " (should be " ..  expectedValue .. ")")
    print("passed test maxConnectedTier1PanelsCount")
end

function DefragmentationTest.testGetTotalTier1PanelsCountByPanels()
    local aprilString = DefragmentationTest.getAprilStringSample1()
    local expectedValue = 20
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local totalTier1PanelsCount = StackExtensions.getTotalTier1PanelsCountByPanels(panels)

    assert(totalTier1PanelsCount == expectedValue, "Value is " .. totalTier1PanelsCount .. " (should be " ..  expectedValue .. ")")
    print("passed test getTotalTier1PanelsCountByPanels")
end

function DefragmentationTest.testFragmentationPercentage1()
    -- can't use garbagePanels because the fragmentationPercentage function tests for them
    local aprilString = DefragmentationTest.getAprilStringSample1()
    local expectedValue = 0.55
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local fragmentationPercentage = StackExtensions.getFragmentationPercentageByPanels(panels)

    assert(fragmentationPercentage == expectedValue, "FragmentationPercentage calculation is faulty with value " .. fragmentationPercentage .. " (should be " ..  expectedValue .. ")")
    print("passed test fragmentation percentage 1")
end

function DefragmentationTest.testFragmentationPercentage2()
    -- can't use garbagePanels because the fragmentationPercentage function tests for them
    local aprilString = DefragmentationTest.getAprilStringSample2()
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
    local aprilString = DefragmentationTest.getAprilStringSample1()
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local expectedValue = DefragmentationTest.getConnectedPanelSectionsSample1()

    local connectedSections = StackExtensions.getTier1ConnectedPanelSectionsByPanels(panels)
    assert(#connectedSections == #expectedValue, "wrong amount of sections found (" .. #connectedSections .. ", should be " .. #expectedValue .. ")")

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
    local aprilString = DefragmentationTest.getAprilStringSample2()
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local expectedValue = DefragmentationTest.getConnectedPanelSectionsSample2()

    local connectedSections = StackExtensions.getTier1ConnectedPanelSectionsByPanels(panels)
    assert(#connectedSections == #expectedValue, "wrong amount of sections found (" .. #connectedSections .. ", should be " .. #expectedValue .. ")")

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

function DefragmentationTest.testGetTier1ConnectedPanelSectionsByPanels4()
    -- can't use garbagePanels because the function tests for them
    local aprilString = DefragmentationTest.getAprilStringSample4()
    local panels = StackExtensions.aprilStackToPanels(aprilString)

    local expectedValue = DefragmentationTest.getConnectedPanelSectionsSample4()

    local connectedSections = StackExtensions.getTier1ConnectedPanelSectionsByPanels(panels)
    assert(#connectedSections == #expectedValue, "wrong amount of sections found (" .. #connectedSections .. ", should be " .. #expectedValue .. ")")

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

    print("passed test getTier1ConnectedPanelSectionsByPanels4 (or maybe it isn't good enough)")
end

function DefragmentationTest.testGetScoredPanelTable1()
    local aprilString = DefragmentationTest.getAprilStringSample1()
    local panels = StackExtensions.aprilStackToPanels(aprilString)
    local connectedPanelSections = DefragmentationTest.getConnectedPanelSectionsSample1()
    local columns = StackExtensions.getTier1PanelsAsColumnsByPanels(panels)
    local scoredPanels = Defragment.GetScoredPanelTable(columns, connectedPanelSections)

    for i=1, #scoredPanels do
        CpuLog:log(5, scoredPanels[i].panel:toString() .. " with score of " .. scoredPanels[i].score)
    end

    local expectedValue = {}
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 2, 1), score = 23})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 3, 1), score = 23})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 2, 2), score = 23})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 3, 2), score = 23})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 4, 1), score = 17})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 4, 2), score = 17})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 5, 1), score = 9})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 6, 1), score = 0})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 2, 4), score = 13})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 2, 5), score = 26})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 3, 5), score = 26})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 2, 6), score = 21})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 3, 6), score = 21})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 4, 6), score = 7})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=8}, 5, 6), score = 0})

    assert(#scoredPanels == #expectedValue, "wrong amount of emptySpaces found (" .. #scoredPanels .. ", should be " .. #expectedValue .. ")")

    for i=1,#expectedValue do
        local matched = false
        for j=1,#scoredPanels do
            if expectedValue[i].panel.vector:equals(scoredPanels[j].panel.vector) and
               expectedValue[i].score == scoredPanels[j].score then
                matched = true
                break
            end
        end
        assert(matched, "couldn\'t find a match for panel+score" .. expectedValue[i].panel:toString() .. " with score " .. expectedValue[i].score)
    end

    print("passed test getScoredPanelTable1")
end

function DefragmentationTest.testGetScoredEmptySpaceTable1()
    local aprilString = DefragmentationTest.getAprilStringSample1()
    local panels = StackExtensions.aprilStackToPanels(aprilString)
    local connectedPanelSections = DefragmentationTest.getConnectedPanelSectionsSample1()
    local columns = StackExtensions.getTier1PanelsAsColumnsByPanels(panels)
    local scoredEmptySpaces = Defragment.getScoredEmptySpaceTable(panels, columns, connectedPanelSections)

    for i=1, #scoredEmptySpaces do
        CpuLog:log(5, scoredEmptySpaces[i].panel:toString() .. " with score of " .. scoredEmptySpaces[i].score)
    end

    local expectedValue = {}
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 1, 3), score = 5})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 2, 3), score = 5})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 3, 3), score = 5})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 4, 3), score = 2})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 4, 4), score = 1})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 4, 5), score = 1})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 3, 4), score = 4})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 5, 2), score = 1})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 5, 3), score = 1})


    assert(#scoredEmptySpaces == #expectedValue, "wrong amount of emptySpaces found (" .. #scoredEmptySpaces .. ", should be " .. #expectedValue .. ")")

    for i=1,#expectedValue do
        local matched = false
        for j=1,#scoredEmptySpaces do
            if expectedValue[i].panel.vector:equals(scoredEmptySpaces[j].panel.vector) and
               expectedValue[i].score == scoredEmptySpaces[j].score then
                matched = true
                break
            end
        end
        assert(matched, "couldn\'t find a match for panel+score" .. expectedValue[i].panel:toString() .. " with score " .. expectedValue[i].score)
    end

    print("passed test getScoredEmptySpaceTable1")
end

function DefragmentationTest.testFilterEmptySpaces1()
    --this stack crashed on me when trying to access the first element in the emptyspaces collection
    local aprilString = "000000000000000000000000000000999999999999999000100000500000200255524233"
    local panels = StackExtensions.aprilStackToPanels(aprilString)
    local connectedPanelSections = DefragmentationTest.getConnectedPanelSectionsSample1()
    local columns = StackExtensions.getTier1PanelsAsColumnsByPanels(panels)
    local scoredEmptySpaces = Defragment.getScoredEmptySpaceTable(panels, columns, connectedPanelSections)

    for i=1, #scoredEmptySpaces do
       CpuLog:log(5, scoredEmptySpaces[i].panel:toString() .. " with score of " .. scoredEmptySpaces[i].score)
    end

    local filteredEmptySpaces = Defragment.FilterEmptySpaces(scoredEmptySpaces)

    CpuLog:log(1,"'passed' test FilterEmptySpaces1")
end

function DefragmentationTest.testGetScoredEmptySpaceTable2()
    local aprilString = "000000999999303000212000144500134450453550245210544311335835211322455243"
    local panels = StackExtensions.aprilStackToPanels(aprilString)
    local connectedPanelSections = StackExtensions.getTier1ConnectedPanelSectionsByPanels(panels)

    for i=1, #connectedPanelSections do
        CpuLog:log(1, connectedPanelSections[i]:toString())
    end

    local columns = StackExtensions.getTier1PanelsAsColumnsByPanels(panels)
    local scoredEmptySpaces = Defragment.getScoredEmptySpaceTable(panels, columns, connectedPanelSections)

    for i=1, #scoredEmptySpaces do
        CpuLog:log(1, scoredEmptySpaces[i].panel:toString() .. " with score of " .. scoredEmptySpaces[i].score)
    end

    local expectedValue = {}
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 5, 6), score = 21})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 6, 6), score = 12})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 7, 6), score = 8})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 8, 6), score = 4})
    --table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 9, 6), score = 0})
    --table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 10, 6), score = 0})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 8, 5), score = 10})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 9, 5), score = 3})
    --table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 10, 5), score = 0})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 9, 4), score = 7})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 10, 4), score = 2})
    table.insert(expectedValue, {panel = ActionPanel({id=0, color=0}, 10, 2), score = 3})

    assert(#scoredEmptySpaces == #expectedValue, "wrong amount of emptySpaces found (" .. #scoredEmptySpaces .. ", should be " .. #expectedValue .. ")")

    for i=1,#expectedValue do
        local matched = false
        for j=1,#scoredEmptySpaces do
            if expectedValue[i].panel.vector:equals(scoredEmptySpaces[j].panel.vector) and
               expectedValue[i].score == scoredEmptySpaces[j].score then
                matched = true
                break
            end
        end
        assert(matched, "couldn\'t find a match for panel+score" .. expectedValue[i].panel:toString() .. " with score " .. expectedValue[i].score)
    end

    print("passed test getScoredEmptySpaceTable2")
end

DefragmentationTest.testGetPanelsAsColumnsByPanels()
DefragmentationTest.testGetTotalTier1PanelsCountByPanels()
DefragmentationTest.testMaxConnectedTier1PanelsCount()
DefragmentationTest.testFragmentationPercentage1()
DefragmentationTest.testFragmentationPercentage2()
DefragmentationTest.testFragmentationPercentage3()
DefragmentationTest.testGetTier1ConnectedPanelSectionsByPanels1()
DefragmentationTest.testGetTier1ConnectedPanelSectionsByPanels2()
DefragmentationTest.testGetTier1ConnectedPanelSectionsByPanels4()
DefragmentationTest.testGetScoredPanelTable1()
DefragmentationTest.testGetScoredEmptySpaceTable1()
DefragmentationTest.testGetScoredEmptySpaceTable2()
DefragmentationTest.testFilterEmptySpaces1()
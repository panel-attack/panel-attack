require("computerPlayers.EndarisCpu.StackExtensions")

StackExtensionsTest = class(function(self) end)

function StackExtensionsTest.aprilStackToPanelsAndBack()
    local aprilString = "000000000000000000000000000000000000900000900009990009990099990999990999"
    local panels = StackExtensions.aprilStackToPanels(aprilString)
    local reString = StackExtensions.AsAprilStackByPanels(panels)

    assert(aprilString == reString, "String is " .. reString .. " instead of " .. aprilString)
    print("passed test panelsToAprilStack")
end

function StackExtensionsTest.stacksAreEqual()
    local aprilString = "000000000000000000000000000000000000900000900009990009990099990999990999"
    local panels = StackExtensions.aprilStackToPanels(aprilString)
    local otherPanels = deepcopy(panels)

    assert(StackExtensions.panelsAreEqualByPanels(panels, otherPanels), "panels are not equal")
    print("passed test stacksAreEqual")
end

function StackExtensionsTest.toRowGrid()

end

function StackExtensionsTest.findActions()

end

function StackExtensionsTest.swapIsValid()

end

function StackExtensionsTest.moveIsValidByPanels()

end

StackExtensionsTest.aprilStackToPanelsAndBack()
StackExtensionsTest.stacksAreEqual()
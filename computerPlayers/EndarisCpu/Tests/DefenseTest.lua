require("computerPlayers.EndarisCpu.StackExtensions")
require("computerPlayers.EndarisCpu.Defense")

local DefenseTest = class(function(self) end)

function DefenseTest.getAprilStringSample1()
    return "000000000000000000000000000000000000999000030000140000330000550005130001"
end

function DefenseTest.testGetDownstackableVectors1()
    local aprilString = DefenseTest.getAprilStringSample1()
    local panels = StackExtensions.aprilStackToPanels(aprilString)
    local expectedValue = {}

    table.insert(expectedValue, GridVector(1, 2))
    table.insert(expectedValue, GridVector(2, 2))
    table.insert(expectedValue, GridVector(3, 2))
    table.insert(expectedValue, GridVector(4, 2))
    table.insert(expectedValue, GridVector(5, 2))
    table.insert(expectedValue, GridVector(6, 2))
    table.insert(expectedValue, GridVector(1, 6))
    table.insert(expectedValue, GridVector(2, 6))

    local downstackableVectors = StackExtensions.getDownstackPanelVectorsByPanels(panels)

    for i=1, #downstackableVectors do
        print(downstackableVectors[i]:toString())
    end

    assert(#expectedValue == #downstackableVectors, "mismatch, found " .. #downstackableVectors .. " (expected " .. #expectedValue .. ")")

    for i=1,#expectedValue do
        local matched = false
        for j=1,#downstackableVectors do
            if expectedValue[i]:equals(downstackableVectors[j]) then
                matched = true
                break
            end
        end
        assert(matched, "couldn\'t find a match for downstackable vector" .. expectedValue[i]:toString())
    end

    print("passed test testGetDownstackableVectors1")
end

function DefenseTest.testGetPotentialClearColors1()
  local aprilString = DefenseTest.getAprilStringSample1()
  local panels = StackExtensions.aprilStackToPanels(aprilString)
  local expectedValue = {3, 5}
  local rowGrid = RowGrid.FromPanels(panels)
  local potentialClearColors = Defend.getPotentialClearColors(rowGrid)

  assert(#expectedValue == #potentialClearColors)
  for i=1, #expectedValue do
    assert(table.trueForAny(potentialClearColors), function(colorId) return colorId == expectedValue[i] end)
  end

  print("passed test testGetDownstackableVectors1")
end

DefenseTest.testGetDownstackableVectors1()
DefenseTest.testGetPotentialClearColors1()
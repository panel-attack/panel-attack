--local PanelGenerator = require("gen_panels")
require("gen_panels")
require("engine")
--local GameModes = require("GameModes")

local function testPanelGenForGarbage1()
  PanelGenerator.setSeed(1)
  local panelbuffer = PanelGenerator.privateGeneratePanels(20, 6, "", true)
  print("t1 buffer: " .. panelbuffer)
end

testPanelGenForGarbage1()

local function testPanelGenForGarbage2()
  PanelGenerator.setSeed(2)
  local panelbuffer = PanelGenerator.privateGeneratePanels(20, 5, "", false)
  print("t2 buffer: " .. panelbuffer)

end

testPanelGenForGarbage2()

local function  testPanelGenForStartingBoard1()
  PanelGenerator.setSeed(3)
  local panelbuffer = PanelGenerator.privateGeneratePanels(7, 6, "", true)
  print("t3_1 buffer: " .. panelbuffer)
  panelbuffer = PanelGenerator.makePanels(3, 6, "I99i99", "vs", 10):sub(7)
  print("t3_2 buffer: " .. panelbuffer)

end

testPanelGenForStartingBoard1()

local function  testPanelGenForStartingBoard2()
PanelGenerator.setSeed(4)
local panelbuffer = PanelGenerator.privateGeneratePanels(7, 5, "", false)
print("t4_1 buffer: " .. panelbuffer)

panelbuffer = PanelGenerator.makePanels(4, 5, "I99i99", "endless"):sub(7)
print("t4_2 buffer: " .. panelbuffer)

end

testPanelGenForStartingBoard2()

local function testPanelGenForRegularBoard1()
  PanelGenerator.setSeed(5)
  local panelbuffer = PanelGenerator.privateGeneratePanels(100, 6, "", true)
  print("t5_1 buffer: " .. panelbuffer)

  panelbuffer = PanelGenerator.makePanels(5, 6, "I99i99", "vs", 10):sub(7)
  print("t5_2 buffer: " .. panelbuffer)

end

testPanelGenForRegularBoard1()

local function testPanelGenForRegularBoard2()
  PanelGenerator.setSeed(6)
  local panelbuffer = PanelGenerator.privateGeneratePanels(100, 5, "", false)
  print("t6_1 buffer: " .. panelbuffer)

  panelbuffer = PanelGenerator.makePanels(6, 5, "I99i99", "endless"):sub(7)
  print("t6_2 buffer: " .. panelbuffer)

end

testPanelGenForRegularBoard2()

local function testStackStartingBoard1()
  local panelbuffer = PanelGenerator.makePanels(7, 5, "", "endless")
  print("t7_1 buffer: " .. panelbuffer)

  panelbuffer = PanelGenerator.makePanels(7, 5, panelbuffer:sub(7), "endless")
  print("t7_2 buffer: " .. panelbuffer)
end

testStackStartingBoard1()


local function testStackStartingBoard2()
  local panelbuffer = PanelGenerator.makePanels(8, 6, "", "vs", 10)
  print("t8_1 buffer: " .. panelbuffer)

  panelbuffer = PanelGenerator.makePanels(8, 6, panelbuffer:sub(7), "vs", 10)
  print("t8_2 buffer: " .. panelbuffer)
end

testStackStartingBoard2()
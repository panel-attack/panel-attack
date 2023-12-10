local PanelGenerator = require("gen_panels")
require("engine")
local GameModes = require("GameModes")

local function testPanelGenForGarbage1()
  PanelGenerator:setSeed(1)
  local panelbuffer = PanelGenerator.privateGeneratePanels(20, 6, 6, "", true)
  assert(panelbuffer == "")
end

testPanelGenForGarbage1()

local function testPanelGenForGarbage2()
  PanelGenerator:setSeed(2)
  local panelbuffer = PanelGenerator.privateGeneratePanels(20, 6, 5, "", false)
  assert(panelbuffer == "")
end

testPanelGenForGarbage2()

local function  testPanelGenForStartingBoard1()
  PanelGenerator:setSeed(3)
  local panelbuffer = PanelGenerator.privateGeneratePanels(7, 6, 6, "", true)
  assert(panelbuffer == "")
  panelbuffer = PanelGenerator.assignMetalLocations(panelbuffer, 6)
  assert(panelbuffer == "")
end

testPanelGenForStartingBoard1()

local function  testPanelGenForStartingBoard2()
  PanelGenerator:setSeed(4)
  local panelbuffer = PanelGenerator.privateGeneratePanels(7, 6, 5, "", false)
  assert(panelbuffer == "")
  panelbuffer = PanelGenerator.assignMetalLocations(panelbuffer, 6)
  assert(panelbuffer == "")
end

testPanelGenForStartingBoard2()

local function testPanelGenForRegularBoard1()
  PanelGenerator:setSeed(5)
  local panelbuffer = PanelGenerator.privateGeneratePanels(100, 6, 6, "", true)
  assert(panelbuffer == "")
  panelbuffer = PanelGenerator.assignMetalLocations(panelbuffer, 6)
  assert(panelbuffer == "")
end

testPanelGenForRegularBoard1()

local function testPanelGenForRegularBoard2()
  PanelGenerator:setSeed(6)
  local panelbuffer = PanelGenerator.privateGeneratePanels(100, 6, 5, "", false)
  assert(panelbuffer == "")
  panelbuffer = PanelGenerator.assignMetalLocations(panelbuffer, 6)
  assert(panelbuffer == "")
end

testPanelGenForRegularBoard2()

local function testStackStartingBoard1()
  local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.ONE_PLAYER_ENDLESS)
  local player = battleRoom.players[1]
  player.settings.speed = 1
  player.settings.difficulty = 1
  player.settings.style = GameModes.Styles.CLASSIC

  local stack = player:createStackFromSettings(battleRoom:createMatch())
  stack.match:setSeed(7)
  local panelbuffer = stack:makeStartingBoardPanels()
  assert(panelbuffer == "")
  panelbuffer = stack:makePanels()
  assert(panelbuffer == "")
end

testStackStartingBoard1()


local function testStackStartingBoard2()
  local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.ONE_PLAYER_VS_SELF)
  local player = battleRoom.players[1]
  player.settings.level = 10
  player.settings.style = GameModes.Styles.MODERN

  local stack = player:createStackFromSettings(battleRoom:createMatch())
  stack.match:setSeed(8)
  local panelbuffer = stack:makeStartingBoardPanels()
  assert(panelbuffer == "")
  panelbuffer = stack:makePanels()
  assert(panelbuffer == "")
end

testStackStartingBoard2()
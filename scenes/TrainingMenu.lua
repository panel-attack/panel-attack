local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local MenuItem = require("ui.MenuItem")
local Label = require("ui.Label")
local TextButton = require("ui.TextButton")
local Stepper = require("ui.Stepper")
local Slider = require("ui.Slider")
local class = require("class")
local tableUtils = require("tableUtils")
local CharacterSelectVsSelf = require("scenes.CharacterSelectVsSelf")
local GameModes = require("GameModes")

--@module TrainingMenu
-- 
local TrainingMenu = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self.menu = nil -- set in load
    self:load(sceneParams)
  end,
  Scene
)

TrainingMenu.name = "TrainingMenu"
sceneManager:addScene(TrainingMenu)

local function exitMenu()
  SoundController:playSfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
end

local function createBasicTrainingMode(name, width, height)
  local delayBeforeStart = 150
  local delayBeforeRepeat = 900
  local attacksPerVolley = 50
  local attackPatterns = {}

  for i = 1, attacksPerVolley do
    table.insert(attackPatterns, {width = width, height = height, startTime = i, metal = false, chain = false, endsChain = false})
  end

  local customTrainingModeData = {delayBeforeStart = delayBeforeStart, delayBeforeRepeat = delayBeforeRepeat, attackPatterns = attackPatterns}

  return customTrainingModeData
end

function TrainingMenu:goToCharacterSelect(value, width, height)
  if value == nil then
    value = createBasicTrainingMode("", width, height)
  end
  GAME.localPlayer:setAttackEngineSettings(value)
  sceneManager:switchToScene(CharacterSelectVsSelf())
end

function TrainingMenu:load(sceneParams)
  local garbagePatternNames = {"Custom", "combo_storm", "factory", "large_garbage"}
  local garbagePatternValues = {
    nil,
    createBasicTrainingMode(loc("combo_storm"), 4, 1),
    createBasicTrainingMode(loc("factory"), 6, 2),
    createBasicTrainingMode(loc("large_garbage"), 6, 12),
  }
  local translatableGarbagePatternNames = {"combo_storm", "factory", "large_garbage"}
  for _, value in ipairs(readAttackFiles("training")) do
    table.insert(garbagePatternNames, value.name)
    table.insert(garbagePatternValues, value)
  end
  
  local garbagePatternLabels = {}
  for _, garbagepatternName in ipairs(garbagePatternNames) do
    table.insert(garbagePatternLabels, Label({
        text = garbagepatternName,
        translate = tableUtils.contains(translatableGarbagePatternNames, garbagepatternName),
        width = 70,
        height = 25}))
  end

  local garbagePatternStepper = Stepper({
      labels = garbagePatternLabels,
      values = garbagePatternValues,
      selectedIndex = 1,
      onChange = function(value)
        GAME.theme:playMoveSfx()
      end
    }
  )

  local widthSlider = Slider({
    min = 1, 
    max = 6, 
    value = 1,
    tickLength = 15,
    onValueChange = function() garbagePatternStepper:setState(1) end
  })

  local heightSlider = Slider({
    min = 1, 
    max = 99, 
    value = 1,
    onValueChange = function() garbagePatternStepper:setState(1) end
  })

  local menuItems = {
    MenuItem.createStepperMenuItem("Garbage Pattern", nil, false, garbagePatternStepper),
    MenuItem.createSliderMenuItem("width", nil, nil, widthSlider),
    MenuItem.createSliderMenuItem("height", nil, nil, heightSlider),
    MenuItem.createButtonMenuItem("go_", nil, nil, function() self:goToCharacterSelect(garbagePatternStepper.value, widthSlider.value, heightSlider.value) end),
    MenuItem.createButtonMenuItem("back", nil, nil, exitMenu)
  }

  self.menu = Menu.createCenteredMenu(menuItems)
  self.uiRoot:addChild(self.menu)
end

function TrainingMenu:update(dt)
  self.backgroundImg:update(dt)
  self.menu:update(dt)
end

function TrainingMenu:draw()
  self.backgroundImg:draw()
  self.uiRoot:draw()
end

return TrainingMenu
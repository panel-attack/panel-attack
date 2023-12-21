local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local Label = require("ui.Label")
local TextButton = require("ui.TextButton")
local Stepper = require("ui.Stepper")
local Slider = require("ui.Slider")
local class = require("class")
local tableUtils = require("tableUtils")
local CharacterSelectTraining = require("scenes.CharacterSelectTraining")

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
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
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

  local customTrainingModeData = {name = name, attackSettings = {delayBeforeStart = delayBeforeStart, delayBeforeRepeat = delayBeforeRepeat, attackPatterns = attackPatterns}}

  return customTrainingModeData
end

function TrainingMenu:goToCharacterSelect(value, width, height)
  if value == nil then
    value = createBasicTrainingMode("", width, height)
  end
  sceneManager:switchToScene(CharacterSelectTraining({value}))
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

  local widthLabel = Label({text = "width"})
  local heightLabel = Label({text = "height"})

  local lightBlue = {.7, .7, 1, .7}
  local darkBlue = {.5, .5, 1, .7}
  local lightRed = {.7, .7, .7, .7}
  local darkRed = {.5, .5, .5, .7}

  local garbagePatternStepper = Stepper({
      labels = garbagePatternLabels,
      values = garbagePatternValues,
      selectedIndex = 1,
      onChange = function(value)
        Menu.playMoveSfx()
        
        if value == nil then
          widthLabel.color = darkBlue
          widthLabel.borderColor = lightBlue
          heightLabel.color = darkBlue
          heightLabel.borderColor = lightBlue
        else
          widthLabel.color = darkRed
          widthLabel.borderColor = lightRed
          heightLabel.color = darkRed
          heightLabel.borderColor = lightRed
        end
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
    {Label({text = "Garbage Pattern", translate = false,}), garbagePatternStepper},
    {widthLabel, widthSlider},
    {heightLabel, heightSlider},
    {TextButton({label = Label({text = "go_"}), onClick = function() self:goToCharacterSelect(garbagePatternStepper.value, widthSlider.value, heightSlider.value) end})},
    {TextButton({label = Label({text = "back"}), onClick = exitMenu})},
  }

  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  y = y + 100
  self.menu = Menu({
    x = x,
    y = y,
    menuItems = menuItems,
  })
end

function TrainingMenu:update(dt)
  self.backgroundImg:update(dt)
  self.menu:update(dt)
end

function TrainingMenu:draw()
  self.backgroundImg:draw()
  self.menu.draw()
end

function TrainingMenu:unload()
  self.menu:setVisibility(false)
end

return TrainingMenu
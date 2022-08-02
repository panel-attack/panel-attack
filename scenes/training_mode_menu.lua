local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local Stepper = require("ui.Stepper")
local Menu = require("ui.Menu")
local scene_manager = require("scenes.scene_manager")
local input = require("inputManager")
local save = require("save")

--@module MainMenu
local training_mode_menu = Scene("training_mode_menu")

local function createBasicTrainingMode(name, width, height) 
  local delayBeforeStart = 150
  local delayBeforeRepeat = 900
  local attacksPerVolley = 50
  local attackPatterns = {}

  for i = 1, attacksPerVolley do
    attackPatterns[#attackPatterns+1] = {width = width, height = height, startTime = i, metal = false, chain = false, endsChain = false}
  end

  local customTrainingModeData = {name = name, delayBeforeStart = delayBeforeStart, delayBeforeRepeat = delayBeforeRepeat, attackPatterns = attackPatterns}

  return customTrainingModeData
end

local trainingStepper

local width_slider = Slider({
    min = 1, 
    max = 6, 
    tick_length = 15,
    value = 6,
    onValueChange = function()
      trainingStepper:setState(1)
    end,
    is_visible = false
})

local height_slider = Slider({
    min = 1, 
    max = 100, 
    value = 1,
    onValueChange = function()
      trainingStepper:setState(1)
    end,
    is_visible = false
})

local function startGame()
  stop_the_music()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  GAME.battleRoom = BattleRoom()
  if trainingStepper.value.name ~= "None" then
    GAME.battleRoom.trainingModeSettings = trainingStepper.value
  else
    GAME.battleRoom.trainingModeSettings = createBasicTrainingMode("", width_slider.value, height_slider.value)
  end
  scene_manager:switchScene("training_mode_character_select")
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end

function training_mode_menu:init()
  if #love.filesystem.getDirectoryItems("training") == 0 then
    recursive_copy("default_data/training", "training")
  end
  save.read_attack_files("training")
  
  local trainingLabels = {
    Label({label = "Custom", translate = false}),
    Label({label = "combo_storm"}),
    Label({label = "factory"}),
    Label({label = "large_garbage"})
  }
  local trainingValues = {
    {name = "None"},
    createBasicTrainingMode(loc("combo_storm"), 4, 1),
    createBasicTrainingMode(loc("factory"), 6, 2),
    createBasicTrainingMode(loc("large_garbage"), 6, 12)
  }
  for customfile, value in ipairs(trainings) do
    trainingLabels[#trainingLabels + 1] =  Label({label = value.name, translate = false})
    trainingValues[#trainingValues + 1] = value
  end
  
  trainingStepper = Stepper(
    trainingLabels,
    trainingValues,
    {
      selected_index = 1,
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    }
  )
  
  local menu_options = {
    {Label({label = "Custom", translate = false, is_visible = false}), trainingStepper},
    {Label({label = "width", is_visible = false}), width_slider},
    {Label({label = "height", is_visible = false}), height_slider},
    {Button({label = "go_", onClick = startGame, is_visible = false})},
    {Button({label = "back", onClick = exitMenu, is_visible = false})},
  }

  local x, y = unpack(main_menu_screen_pos)
  y = y + 100
  self.menu = Menu(menu_options, {x = x, y = y})
  self.menu:setVisibility(false)
  scene_manager:addScene(training_mode_menu)
end

function training_mode_menu:load()
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  
  self.menu:setVisibility(true)
end

function training_mode_menu:update()
  self.menu:update()
  self.menu:draw()
end

function training_mode_menu:unload()
  self.menu:setVisibility(false)
end

return training_mode_menu
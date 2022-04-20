local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
local select_screen = require("select_screen")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local Menu = require("ui.Menu")
local scene_manager = require("scenes.scene_manager")
local input = require("input2")

--@module MainMenu
local training_mode_menu = Scene("training_mode_menu")

-- TODO make "illegal garbage blocks" possible again in telegraph.
local trainingModeSettings = {
  height = 1,
  width = 6
}
local ret = nil
local menu_x, menu_y = unpack(main_menu_screen_pos)
menu_y = menu_y + 70

local selected_id = 1

local width_slider = Slider({
    min = 1, 
    max = 6, 
    tick_length = 15,
    value = trainingModeSettings.width, 
    is_visible = false
})

local height_slider = Slider({
    min = 1, 
    max = 100, 
    value = trainingModeSettings.height, 
    is_visible = false
})

local function factorySettings()
  width_slider:setValue(6)
  height_slider:setValue(2)
end

local function comboStormSettings()
  width_slider:setValue(4)
  height_slider:setValue(1)
end

local function largeGarbageSettings()
  width_slider:setValue(6)
  height_slider:setValue(12)
end

local function startGame()
  stop_the_music()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  GAME.battleRoom = BattleRoom()
  GAME.battleRoom.trainingModeSettings = {width = width_slider.value, height = height_slider.value}
  scene_manager:switchScene("training_mode_character_select")
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end

local font = love.graphics.getFont()
local menu_options = {
  Button({text = love.graphics.newText(font, loc("factory")), onClick = factorySettings, is_visible = false}),
  Button({text = love.graphics.newText(font, loc("combo_storm")), onClick = comboStormSettings, is_visible = false}),
  Button({text = love.graphics.newText(font, loc("large_garbage")), onClick = largeGarbageSettings, is_visible = false}),
  Label({text = love.graphics.newText(font, loc("width")), is_visible = false}),
  Label({text = love.graphics.newText(font, loc("height")), is_visible = false}),
  Button({text = love.graphics.newText(font, loc("go_")), onClick = startGame, is_visible = false}),
  Button({text = love.graphics.newText(font, loc("back")), onClick = exitMenu, is_visible = false}),
}

function training_mode_menu:init()
  local x, y = unpack(main_menu_screen_pos)
  y = y + 100
  self.menu = Menu({
      {menu_options[1]},
      {menu_options[2]},
      {menu_options[3]},
      {menu_options[4], width_slider},
      {menu_options[5], height_slider},
      {menu_options[6]},
      {menu_options[7]},
      }, {x = x, y = y})
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
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

local font = love.graphics.getFont()
local arrow = love.graphics.newText(font, ">")

local function startGame()
  stop_the_music()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene(nil)
  
  func = main_local_vs_yourself_setup
  arg = {{width = width_slider.value, height = height_slider.value}}
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end

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
  local menu_x, menu_y = unpack(main_menu_screen_pos)
  menu_y = menu_y + 100
  
  for i, button in ipairs(menu_options) do
    button.x = menu_x + 25
    button.y = i > 1 and menu_options[i - 1].y + menu_options[i - 1].height + 5 or menu_y
    button.width = 110
    button.height = 25
  end
  width_slider.x = menu_x + 110 + 25 + 20
  width_slider.y = menu_options[4].y + menu_options[4].height / 2
  height_slider.x = menu_x + 110 + 25 + 20
  height_slider.y = menu_options[5].y + menu_options[5].height / 2
  
  scene_manager:addScene(training_mode_menu)
end

function training_mode_menu:load()
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  
  width_slider.is_visible = true
  height_slider.is_visible = true
  for i, button in ipairs(menu_options) do
    button.is_visible = true
  end
end

function training_mode_menu:update()    
  if input:isPressedWithRepeat("down", .25, .05) then
    selected_id = (selected_id % #menu_options) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  
  if input:isPressedWithRepeat("up", .25, .05) then
    selected_id = ((selected_id - 2) % #menu_options) + 1
    play_optional_sfx(themes[config.theme].sounds.menu_move)
  end
  
  if input:isPressedWithRepeat("left", .25, .05) then
    if selected_id == 4 then
      width_slider:setValue(width_slider.value - 1)
    elseif selected_id == 5 then
      height_slider:setValue(height_slider.value - 1)
    end
  end

  if input:isPressedWithRepeat("right", .25, .05) then
    if selected_id == 4 then
      width_slider:setValue(width_slider.value + 1)
    elseif selected_id == 5 then
      height_slider:setValue(height_slider.value + 1)
    end
  end
  
  if input.isDown["return"] and selected_id ~= 4 and selected_id ~= 5 then
    menu_options[selected_id].onClick()
  end
  
  for i = 4, 5 do
    menu_options[i]:draw()
  end
  
  local animationX = (math.cos(6 * love.timer.getTime()) * 5) - 9
  local arrowx = menu_options[selected_id].x - 10 + animationX
  local arrowy = menu_options[selected_id].y + menu_options[selected_id].height / 4
  GAME.gfx_q:push({love.graphics.draw, {arrow, arrowx, arrowy, 0, 1, 1, 0, 0}})
end

function training_mode_menu:unload()
  for i, button in ipairs(menu_options) do
    button.is_visible = false
  end
  width_slider.is_visible = false
  height_slider.is_visible = false
end

return training_mode_menu
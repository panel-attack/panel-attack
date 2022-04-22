local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local scene_manager = require("scenes.scene_manager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local consts = require("consts")
local input = require("input2")

--@module BasicMenu
local input_config_menu = Scene("input_config_menu")

input_config_menu.setting_key = false

local font = love.graphics.getFont() 
local pretty_names = {loc("up"), loc("down"), loc("left"), loc("right"), "A", "B", "X", "Y", "L", "R", loc("start")}
local pending_input_text = love.graphics.newText(font, "__")
local config_index = 1

function input_config_menu:updateInputConfigSet(value)
  config_index = value
  play_optional_sfx(themes[config.theme].sounds.menu_move)
  for i, key in ipairs(consts.KEY_NAMES) do
    local key_name = GAME.input:cleanNameForButton(GAME.input.inputConfigurations[config_index][key]) or loc("op_none")
    self.menu.menu_items[i + 1][2].text = love.graphics.newText(font, key_name)
  end
end

function input_config_menu:setKeyFn(key, index)
  coroutine.yield()
  local pressed_key = nil
  while not pressed_key do
    for p, _ in pairs(input.isDown) do
      pressed_key = p
      break
    end
    coroutine.yield()
  end
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  GAME.input.inputConfigurations[config_index][key] = pressed_key
  self.menu.menu_items[index + 1][2].text = love.graphics.newText(font, pressed_key)
  write_key_file()
  self.setting_key = false
end

function input_config_menu:setAllKeysFn()
    coroutine.yield()
    
  for i, key in ipairs(consts.KEY_NAMES) do
    self.menu.menu_items[i + 1][2].text = pending_input_text
    self.menu.selected_id = i + 1
    local pressed_key = nil
    while not pressed_key do
      for p, _ in pairs(input.isDown) do
        pressed_key = p
        break
      end
      coroutine.yield()
    end
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    GAME.input.inputConfigurations[config_index][key] = pressed_key
    self.menu.menu_items[i + 1][2].text = love.graphics.newText(font, pressed_key)
    coroutine.yield()
  end

  write_key_file()
  self.setting_key = false
end

function input_config_menu:setKey(key)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  local index = nil
  for i, k in ipairs(consts.KEY_NAMES) do
    if k == key then
      index = i
      break
    end
  end
  self.menu.menu_items[index + 1][2].text = pending_input_text
  self.setting_key = true
  self.set_key_co = coroutine.create(function(key) self:setKeyFn(key, index) end)
  coroutine.resume(self.set_key_co, key, index)
end



function input_config_menu:setAllKeys() 
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  self.setting_key = true
  self.set_key_co = coroutine.create(function() self:setAllKeysFn() end)
  coroutine.resume(self.set_key_co)
end

local function clearAllInputs(menu_options)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  for i, key in ipairs(consts.KEY_NAMES) do
    GAME.input.inputConfigurations[config_index][key] = nil
    local key_name = loc("op_none")
    menu_options[i + 1][2].text = love.graphics.newText(font, key_name)
  end
  write_key_file()
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end

function input_config_menu:init()
  scene_manager:addScene(input_config_menu)
  
  local menu_options = {}
  menu_options[1] = {
      Label({text = love.graphics.newText(font, loc("configuration"))}), 
      Slider({
          min = 1,
          max = GAME.input.maxConfigurations,
          value = 1,
          tick_length = 10,
          onValueChange = function(slider) input_config_menu:updateInputConfigSet(slider.value) end})
    }
  for i, key in ipairs(consts.KEY_NAMES) do
    local key_name = GAME.input:cleanNameForButton(GAME.input.inputConfigurations[config_index][key]) or loc("op_none")
    local label = Label({text = love.graphics.newText(font, key_name)})
    menu_options[#menu_options + 1] = {
      Button({
          text = love.graphics.newText(font, key),
          onClick = function() 
            if not self.setting_key then
              self:setKey(key)
            end
          end}), 
      label}
  end
  menu_options[#menu_options + 1] = {
    Button({text = love.graphics.newText(font, loc("op_all_keys")),
    onClick = function() input_config_menu:setAllKeys() end})}
  menu_options[#menu_options + 1] = {
    Button({text = love.graphics.newText(font, "Clear All Inputs"), 
    onClick = function() clearAllInputs(menu_options) end})}
  menu_options[#menu_options + 1] = {Button({text = love.graphics.newText(font, loc("back")), onClick = exitMenu})}
  
  local x, y = unpack(main_menu_screen_pos)
  self.menu = Menu(menu_options, {x = x, y = y})
  self.menu:setVisibility(false)
end

function input_config_menu:load()
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  
  self.menu:setVisibility(true)
end

function input_config_menu:update()
  if self.setting_key then
    coroutine.resume(self.set_key_co)
  end
  self.menu:update()
  self.menu:draw()
end

function input_config_menu:unload()  
  self.menu:setVisibility(false)
end

return input_config_menu
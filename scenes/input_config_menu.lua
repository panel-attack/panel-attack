local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local scene_manager = require("scenes.scene_manager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local consts = require("consts")
local input = require("inputManager")
local joystickManager = require("joystickManager")
local util = require("util")

--@module input_config_menu
local input_config_menu = Scene("input_config_menu")

input_config_menu.setting_key = false

local font = love.graphics.getFont() 
local pretty_names = {loc("up"), loc("down"), loc("left"), loc("right"), "A", "B", "X", "Y", "L", "R", loc("start")}
local pending_input_text = "__"
local config_index = 1

local function shorten_controller_name(name)
  local name_to_short_names = {
    ["Nintendo Switch Pro Controller"] = "Switch Pro Con"
  }
  return name_to_short_names[name] or name
end

function input_config_menu:updateInputConfigSet(value)
  config_index = value
  play_optional_sfx(themes[config.theme].sounds.menu_move)
  for i, key in ipairs(consts.KEY_NAMES) do
    local key_name = GAME.input:cleanNameForButton(GAME.input.inputConfigurations[config_index][key]) or loc("op_none")
    if string.match(key_name, ":") then
      local controller_key_split = util.split(key_name, ":")
      local controller_name = shorten_controller_name(joystickManager.guidToName[controller_key_split[2]])
      key_name = string.format("%s (%s-%s)", controller_key_split[1], controller_name, controller_key_split[3])
    end
    self.menu.menuItems[i + 1].children[1]:updateLabel(key_name)
  end
end

function input_config_menu:pollAndSetKey(key, index)
  coroutine.yield()
  self.menu.menuItems[index + 1].children[1]:updateLabel(pending_input_text)
  self.menu.selected_id = index + 1
  local pressed_key = nil
  while not pressed_key do
    for p, _ in pairs(input.allKeys.isDown) do
      pressed_key = p
      break
    end
    coroutine.yield()
  end
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  local key_display_name = pressed_key
  if string.match(pressed_key, ":") then
    local controller_key_split = util.split(pressed_key, ":")
    local controller_name = shorten_controller_name(joystickManager.guidToName[controller_key_split[2]])
    key_display_name = string.format("%s (%s-%s)", controller_key_split[1], controller_name, controller_key_split[3])
  end
  GAME.input.inputConfigurations[config_index][key] = pressed_key
  self.menu.menuItems[index + 1].children[1]:updateLabel(key_display_name)
end

function input_config_menu:setKeyFn(key, index)
  self:pollAndSetKey(key, index)
  write_key_file()
  self.setting_key = false
end

function input_config_menu:setAllKeysFn()
    coroutine.yield()
    
  for i, key in ipairs(consts.KEY_NAMES) do
    self:pollAndSetKey(key, i)
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
    menu_options[i + 1][2]:updateLabel(key_name)
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
      Label({label = "configuration"}), 
      Slider({
          min = 1,
          max = GAME.input.maxConfigurations,
          value = 1,
          tickLength = 10,
          onValueChange = function(slider) input_config_menu:updateInputConfigSet(slider.value) end})
    }
  for i, key in ipairs(consts.KEY_NAMES) do
    local key_name = GAME.input:cleanNameForButton(GAME.input.inputConfigurations[config_index][key]) or loc("op_none")
    local label = Label({label = key_name, translate = false, width = 200})
    menu_options[#menu_options + 1] = {
      Button({
          label = key,
          translate = false,
          onClick = function() 
            if not self.setting_key then
              self:setKey(key)
            end
          end}), 
      label}
  end
  menu_options[#menu_options + 1] = {
    Button({label = "op_all_keys",
    onClick = function() input_config_menu:setAllKeys() end})}
  menu_options[#menu_options + 1] = {
    Button({label = "Clear All Inputs", translate = false,
    onClick = function() clearAllInputs(menu_options) end})}
  menu_options[#menu_options + 1] = {Button({label = "back", onClick = exitMenu})}
  
  local x, y = unpack(main_menu_screen_pos)
  self.menu = Menu({menuItems = menu_options, x = x, y = y})
  self.menu:setVisibility(false)
end

function input_config_menu:load()
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  
  self.menu:updateLabel()
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
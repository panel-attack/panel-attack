local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local consts = require("consts")
local input = require("inputManager")
local joystickManager = require("joystickManager")
local util = require("util")

--@module inputConfigMenu
local inputConfigMenu = Scene("inputConfigMenu")

inputConfigMenu.settingKey = false
inputConfigMenu.menu = nil -- set in load

local font = love.graphics.getFont()
local pendingInputText = "__"
local configIndex = 1

local function shortenControllerName(name)
  local nameToShortName = {
    ["Nintendo Switch Pro Controller"] = "Switch Pro Con"
  }
  return nameToShortName[name] or name
end

function inputConfigMenu:setSettingKeyState(settingKey)
  self.settingKey = settingKey
  self.menu:setEnabled(not settingKey)
end

function inputConfigMenu:updateInputConfigSet(value)
  configIndex = value
  play_optional_sfx(themes[config.theme].sounds.menu_move)
  for i, key in ipairs(consts.KEY_NAMES) do
    local keyName = GAME.input:cleanNameForButton(GAME.input.inputConfigurations[configIndex][key]) or loc("op_none")
    if string.match(keyName, ":") then
      local controllerKeySplit = util.split(keyName, ":")
      local controllerName = shortenControllerName(joystickManager.guidToName[controllerKeySplit[2]])
      keyName = string.format("%s (%s-%s)", controllerKeySplit[1], controllerName, controllerKeySplit[3])
    end
    self.menu.menuItems[i + 1].children[1]:updateLabel(keyName)
  end
end

function inputConfigMenu:pollAndSetKey(key, index)
  coroutine.yield()
  self.menu.menuItems[index + 1].children[1]:updateLabel(pendingInputText)
  self.menu.selectedId = index + 1
  local pressedKey = nil
  while not pressedKey do
    for p, _ in pairs(input.allKeys.isDown) do
      pressedKey = p
      break
    end
    coroutine.yield()
  end
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  local keyDisplayName = pressedKey
  if string.match(pressedKey, ":") then
    local controllerKeySplit = util.split(pressedKey, ":")
    local controllerName = shortenControllerName(joystickManager.guidToName[controllerKeySplit[2]])
    keyDisplayName = string.format("%s (%s-%s)", controllerKeySplit[1], controllerName, controllerKeySplit[3])
  end
  GAME.input.inputConfigurations[configIndex][key] = pressedKey
  self.menu.menuItems[index + 1].children[1]:updateLabel(keyDisplayName)
end

function inputConfigMenu:setKeyFn(key, index)
  self:pollAndSetKey(key, index)
  write_key_file()
  self:setSettingKeyState(false)
end

function inputConfigMenu:setAllKeysFn()
    coroutine.yield()
    
  for i, key in ipairs(consts.KEY_NAMES) do
    self:pollAndSetKey(key, i)
  end

  write_key_file()
  self:setSettingKeyState(false)
end

function inputConfigMenu:setKey(key)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  local index = nil
  for i, k in ipairs(consts.KEY_NAMES) do
    if k == key then
      index = i
      break
    end
  end
  self:setSettingKeyState(true)
  self.setKeyCo = coroutine.create(function(key) self:setKeyFn(key, index) end)
  coroutine.resume(self.setKeyCo, key, index)
end



function inputConfigMenu:setAllKeys() 
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  self:setSettingKeyState(true)
  self.setKeyCo = coroutine.create(function() self:setAllKeysFn() end)
  coroutine.resume(self.setKeyCo)
end

local function clearAllInputs(menuOptions)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  for i, key in ipairs(consts.KEY_NAMES) do
    GAME.input.inputConfigurations[configIndex][key] = nil
    local keyName = loc("op_none")
    menuOptions[i + 1][2]:updateLabel(keyName)
  end
  write_key_file()
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("mainMenu")
end

function inputConfigMenu:init()
  sceneManager:addScene(inputConfigMenu)
  
  local menuOptions = {}
  menuOptions[1] = {
      Label({label = "configuration"}), 
      Slider({
          min = 1,
          max = GAME.input.maxConfigurations,
          value = 1,
          tickLength = 10,
          onValueChange = function(slider) inputConfigMenu:updateInputConfigSet(slider.value) end})
    }
  for i, key in ipairs(consts.KEY_NAMES) do
    local keyName = GAME.input:cleanNameForButton(GAME.input.inputConfigurations[configIndex][key]) or loc("op_none")
    local label = Label({label = keyName, translate = false, width = 200})
    menuOptions[#menuOptions + 1] = {
      Button({
          label = key,
          translate = false,
          onClick = function() 
            if not self.settingKey then
              self:setKey(key)
            end
          end}), 
      label}
  end
  menuOptions[#menuOptions + 1] = {
    Button({label = "op_all_keys",
    onClick = function() inputConfigMenu:setAllKeys() end})}
  menuOptions[#menuOptions + 1] = {
    Button({label = "Clear All Inputs", translate = false,
    onClick = function() clearAllInputs(menuOptions) end})}
  menuOptions[#menuOptions + 1] = {Button({label = "back", onClick = exitMenu})}
  
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  self.menu = Menu({menuItems = menuOptions, x = x, y = y})
  self.menu:setVisibility(false)
end

function inputConfigMenu:load()
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  
  self.menu:updateLabel()
  self.menu:setVisibility(true)
end

function inputConfigMenu:drawBackground()
  themes[config.theme].images.bg_main:draw()
end

function inputConfigMenu:update()
  if self.settingKey then
    coroutine.resume(self.setKeyCo)
  end
  self.menu:update()
  self.menu:draw()
end

function inputConfigMenu:unload()  
  self.menu:setVisibility(false)
end

return inputConfigMenu
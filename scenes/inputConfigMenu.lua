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
local GraphicsUtil = require("graphics_util")

--@module inputConfigMenu
local inputConfigMenu = Scene("inputConfigMenu")

inputConfigMenu.settingKey = false
inputConfigMenu.menu = nil -- set in load

local font = GraphicsUtil.getGlobalFont()
local pendingInputText = "__"
local configIndex = 1

local function shortenControllerName(name)
  local nameToShortName = {
    ["Nintendo Switch Pro Controller"] = "Switch Pro Con"
  }
  return nameToShortName[name] or name
end

-- Represents the state of love.run while the key in isDown/isUp is active
-- NOT_SETTING: when we are not polling for a new key
-- SETTING_KEY_TRANSITION: skip a frame so we don't use the button activation key as the configured key
-- SETTING_KEY: currently polling for a single key
-- SETTING_ALL_KEY_TRANSITION: skip a frame so we don't use the button activation key as the configured key
-- SETTING_ALL_KEYS: currently polling for all keys
-- This is only used within this file, external users should simply treat isDown/isUp as a boolean
local KEY_SETTING_STATE = { NOT_SETTING = nil, SETTING_KEY_TRANSITION = 1, SETTING_KEY = 2, SETTING_ALL_KEYS_TRANSITION = 3, SETTING_ALL_KEYS = 4 }

function inputConfigMenu:setSettingKeyState(keySettingState)
  self.settingKey = keySettingState ~= KEY_SETTING_STATE.NOT_SETTING
  self.settingKeyState = keySettingState
  self.menu:setEnabled(not self.settingKey)
end

function inputConfigMenu:getKeyDisplayName(key)
  local keyDisplayName = key
  if key and string.match(key, ":") then
    local controllerKeySplit = util.split(key, ":")
    local controllerName = shortenControllerName(joystickManager.guidToName[controllerKeySplit[1]] or "Unplugged Controller")
    keyDisplayName = string.format("%s (%s-%s)", controllerKeySplit[3], controllerName, controllerKeySplit[2])
  end
  return keyDisplayName or loc("op_none")
end

function inputConfigMenu:updateInputConfigMenuLabels(index)
  configIndex = index
  Menu.playMoveSfx()
  for i, key in ipairs(consts.KEY_NAMES) do
    local keyDisplayName = inputConfigMenu:getKeyDisplayName(GAME.input.inputConfigurations[configIndex][key])
    self.menu.menuItems[i + 1].children[1]:updateLabel(keyDisplayName)
  end
end

function inputConfigMenu:updateKey(key, pressedKey, index)
  Menu.playValidationSfx()
  GAME.input.inputConfigurations[configIndex][key] = pressedKey
  local keyDisplayName = inputConfigMenu:getKeyDisplayName(pressedKey)
  self.menu.menuItems[index + 1].children[1]:updateLabel(keyDisplayName)
  write_key_file()
end

function inputConfigMenu:setKey(key, index)
  local pressedKey = next(input.allKeys.isDown)
  if pressedKey then
    self:updateKey(key, pressedKey, index)
    self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
  end
end

function inputConfigMenu:setAllKeys()
  local pressedKey = next(input.allKeys.isDown)
  if pressedKey then
    inputConfigMenu:updateKey(consts.KEY_NAMES[self.index], pressedKey, self.index)
    if self.index < #consts.KEY_NAMES then
      self.index = self.index + 1
      self.menu.menuItems[self.index + 1].children[1]:updateLabel(pendingInputText)
      self.menu.selectedIndex = self.index + 1
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION)
    else
      self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
    end
  end
end

function inputConfigMenu:setKeyStart(key)
  Menu.playValidationSfx()
  self.key = key
  self.index = nil
  for i, k in ipairs(consts.KEY_NAMES) do
    if k == key then
      self.index = i
      break
    end
  end
  self.menu.menuItems[self.index + 1].children[1]:updateLabel(pendingInputText)
  self.menu.selectedIndex = self.index + 1
  self:setSettingKeyState(KEY_SETTING_STATE.SETTING_KEY_TRANSITION)
end

function inputConfigMenu:setAllKeysStart()
  Menu.playValidationSfx()
  self.index = 1
  self.menu.menuItems[self.index + 1].children[1]:updateLabel(pendingInputText)
  self.menu.selectedIndex = self.index + 1
  self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION)
end

local function clearAllInputs(menuOptions)
  Menu.playValidationSfx()
  for i, key in ipairs(consts.KEY_NAMES) do
    GAME.input.inputConfigurations[configIndex][key] = nil
    local keyName = loc("op_none")
    menuOptions[i + 1][2]:updateLabel(keyName)
  end
  write_key_file()
end

local function exitMenu()
  Menu.playValidationSfx()
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
          onValueChange = function(slider) inputConfigMenu:updateInputConfigMenuLabels(slider.value) end})
    }
  for i, key in ipairs(consts.KEY_NAMES) do
    local keyName = inputConfigMenu:getKeyDisplayName(GAME.input.inputConfigurations[configIndex][key])
    local label = Label({label = keyName, translate = false, width = 200})
    menuOptions[#menuOptions + 1] = {
      Button({
          label = key,
          translate = false,
          onClick = function() 
            if not self.settingKey then
              self:setKeyStart(key)
            end
          end}), 
      label}
  end
  menuOptions[#menuOptions + 1] = {
    Button({label = "op_all_keys",
    onClick = function() inputConfigMenu:setAllKeysStart() end})}
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

function inputConfigMenu:update(dt)
  self.menu:update()
  self.menu:draw()

  local noKeysHeld = next(input.allKeys.isDown) == nil and next(input.allKeys.isPressed) == nil

  if self.settingKeyState == KEY_SETTING_STATE.SETTING_KEY_TRANSITION then
    if noKeysHeld then
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_KEY)
    end
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION then
    if noKeysHeld then
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS)
    end
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_KEY then
    inputConfigMenu:setKey(self.key, self.index)
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_ALL_KEYS then
    inputConfigMenu:setAllKeys()
  end
end

function inputConfigMenu:unload()  
  self.menu:setVisibility(false)
end

return inputConfigMenu
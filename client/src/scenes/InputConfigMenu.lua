local Scene = require("client.src.scenes.Scene")
local tableUtils = require("common.lib.tableUtils")
local Slider = require("client.src.ui.Slider")
local Menu = require("client.src.ui.Menu")
local MenuItem = require("client.src.ui.MenuItem")
local consts = require("common.engine.consts")
local input = require("common.lib.inputManager")
local joystickManager = require("common.lib.joystickManager")
local util = require("common.lib.util")
local class = require("common.lib.class")

--@module inputConfigMenu
-- Scene for configuring input
local InputConfigMenu = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    self.music = "main"
    self.settingKey = false
    self.menu = nil -- set in load
    
    self:load(sceneParams)
  end,
  Scene
)

InputConfigMenu.name = "InputConfigMenu"

-- Sometimes controllers register buttons as "pressed" even though they aren't. If they have been pressed longer than this they don't count.
local MAX_PRESS_DURATION = 0.5
local KEY_NAME_LABEL_WIDTH = 180
local PADDING = 8
local pendingInputText = "__"

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
-- SETTING_ALL_KEYS: currently polling for all keys
-- This is only used within this file, external users should simply treat isDown/isUp as a boolean
local KEY_SETTING_STATE = { NOT_SETTING = nil, SETTING_KEY_TRANSITION = 1, SETTING_KEY = 2, SETTING_ALL_KEYS_TRANSITION = 3, SETTING_ALL_KEYS = 4 }

function InputConfigMenu:setSettingKeyState(keySettingState)
  self.settingKey = keySettingState ~= KEY_SETTING_STATE.NOT_SETTING
  self.settingKeyState = keySettingState
  self.menu:setEnabled(not self.settingKey)
end

function InputConfigMenu:getKeyDisplayName(key)
  local keyDisplayName = key
  if key and string.match(key, ":") then
    local controllerKeySplit = util.split(key, ":")
    local controllerName = shortenControllerName(joystickManager.guidToName[controllerKeySplit[1]] or "Unplugged Controller")
    keyDisplayName = string.format("%s (%s-%s)", controllerKeySplit[3], controllerName, controllerKeySplit[2])
  end
  return keyDisplayName or loc("op_none")
end

function InputConfigMenu:updateInputConfigMenuLabels(index)
  self.configIndex = index
  for i, key in ipairs(consts.KEY_NAMES) do
    local keyDisplayName = self:getKeyDisplayName(GAME.input.inputConfigurations[self.configIndex][key])
    self:currentKeyLabelForIndex(i + 1):setText(keyDisplayName)
  end
end

function InputConfigMenu:updateKey(key, pressedKey, index)
  GAME.theme:playValidationSfx()
  GAME.input.inputConfigurations[self.configIndex][key] = pressedKey
  local keyDisplayName = self:getKeyDisplayName(pressedKey)
  self:currentKeyLabelForIndex(index + 1):setText(keyDisplayName)
  write_key_file()
end

function InputConfigMenu:setKey(key, index)
  local pressedKey = next(input.allKeys.isDown)
  if pressedKey then
    self:updateKey(key, pressedKey, index)
    self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
  end
end

function InputConfigMenu:setAllKeys()
  local pressedKey = next(input.allKeys.isDown)
  if pressedKey then
    self:updateKey(consts.KEY_NAMES[self.index], pressedKey, self.index)
    if self.index < #consts.KEY_NAMES then
      self.index = self.index + 1
      self:currentKeyLabelForIndex(self.index + 1):setText(pendingInputText)
      self.menu.selectedIndex = self.index + 1
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION)
    else
      self:setSettingKeyState(KEY_SETTING_STATE.NOT_SETTING)
    end
  end
end

function InputConfigMenu:currentKeyLabelForIndex(index)
  return self.menu.menuItems[index].textButton.children[1]
end

function InputConfigMenu:setKeyStart(key)
  GAME.theme:playValidationSfx()
  self.key = key
  self.index = nil
  for i, k in ipairs(consts.KEY_NAMES) do
    if k == key then
      self.index = i
      break
    end
  end
  self:currentKeyLabelForIndex(self.index + 1):setText(pendingInputText)
  self.menu.selectedIndex = self.index + 1
  self:setSettingKeyState(KEY_SETTING_STATE.SETTING_KEY_TRANSITION)
end

function InputConfigMenu:setAllKeysStart()
  GAME.theme:playValidationSfx()
  self.index = 1
  self:currentKeyLabelForIndex(self.index + 1):setText(pendingInputText)
  self.menu:setSelectedIndex(self.index + 1)
  self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION)
end

function InputConfigMenu:clearAllInputs()
  GAME.theme:playValidationSfx()
  for i, key in ipairs(consts.KEY_NAMES) do
    GAME.input.inputConfigurations[self.configIndex][key] = nil
    local keyName = loc("op_none")
    self:currentKeyLabelForIndex(i + 1):setText(keyName)
  end
  write_key_file()
end

function InputConfigMenu:resetToDefault(menuOptions) 
  GAME.theme:playValidationSfx() 
  local i = 1 
  for keyName, key in pairs(input.defaultKeys) do 
    GAME.input.inputConfigurations[1][keyName] = key
    self:currentKeyLabelForIndex(i + 1):setText(GAME.input.inputConfigurations[1][keyName])
    i = i + 1 
  end
  for j = 2, input.maxConfigurations do
    for _, key in ipairs(consts.KEY_NAMES) do
      GAME.input.inputConfigurations[j][key] = nil
    end
  end
  GAME.theme:playMoveSfx()
  self.slider:setValue(1)
  self:updateInputConfigMenuLabels(1)
  write_key_file() 
end

local function exitMenu()
  GAME.theme:playValidationSfx()
  GAME.navigationStack:pop()
end

function InputConfigMenu:load(sceneParams)
  self.configIndex = 1
  local menuOptions = {}
  self.slider = Slider({
    min = 1,
    max = input.maxConfigurations,
    value = 1,
    tickLength = 10,
    onValueChange = function(slider) self:updateInputConfigMenuLabels(slider.value) end})
  menuOptions[1] = MenuItem.createSliderMenuItem("configuration", nil, nil, self.slider)
  for i, key in ipairs(consts.KEY_NAMES) do
    local clickFunction = function() 
      if not self.settingKey then
        self:setKeyStart(key)
      end
    end
    local keyName = self:getKeyDisplayName(GAME.input.inputConfigurations[self.configIndex][key])
    menuOptions[#menuOptions + 1] = MenuItem.createLabeledButtonMenuItem(key, nil, false, keyName, nil, false, clickFunction)
  end
  menuOptions[#menuOptions + 1] = MenuItem.createButtonMenuItem("op_all_keys", nil, nil, function() self:setAllKeysStart() end)
  menuOptions[#menuOptions + 1] = MenuItem.createButtonMenuItem("Clear All Inputs", nil, false, function() self:clearAllInputs() end)
  menuOptions[#menuOptions + 1] = MenuItem.createButtonMenuItem("Reset Keys To Default", nil, false, function() self:resetToDefault(menuOptions) end)
  menuOptions[#menuOptions + 1] = MenuItem.createButtonMenuItem("back", nil, nil, exitMenu)

  self.menu = Menu.createCenteredMenu(menuOptions)

  self.uiRoot:addChild(self.menu)
end

function InputConfigMenu:update(dt)
  self.backgroundImg:update(dt)
  self.menu:update(dt)

  local noKeysHeld = (tableUtils.first(input.allKeys.isPressed, function (value)
    return value < MAX_PRESS_DURATION
  end)) == nil

  if self.settingKeyState == KEY_SETTING_STATE.SETTING_KEY_TRANSITION then
    if noKeysHeld then
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_KEY)
    end
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_ALL_KEYS_TRANSITION then
    if noKeysHeld then
      self:setSettingKeyState(KEY_SETTING_STATE.SETTING_ALL_KEYS)
    end
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_KEY then
    self:setKey(self.key, self.index)
  elseif self.settingKeyState == KEY_SETTING_STATE.SETTING_ALL_KEYS then
    self:setAllKeys()
  end
end

function InputConfigMenu:draw()
  themes[config.theme].images.bg_main:draw()
  self.uiRoot:draw()
end

return InputConfigMenu
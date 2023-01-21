local tableUtils = require("tableUtils")
local joystickManager = require("joystickManager")
local consts = require("consts")
 
--@module inputManager 
-- table containing the set of keys in various states 
-- base structure: 
--   isDown: table of {key: true} pairs if the key was pressed in the current frame 
--   isUp: table of {key: true} pairs if the key was released in the current frame 
--   isPressed: table of {key: time} pairs if the key is currently being held down where total duration held down is stored as time
--   Caveats:
--     isUp/isDown is set to one of the KEY_CHANGE enum values, see that definition for details
-- Key groups: 
--   allKeys: every key read in by LOVE (includes keyboard, controller, and joystick) 
--   base (top level): all keys mapped by the input.configuration aliased to the consts.KEY_NAMES 
--   player: list of individual input.configuration mappings also aliased by consts.KEY_NAMES 
--   mouse: all mouse buttons and the position of the mouse
local inputManager = { 
  isDown = {}, 
  isPressed = {}, 
  isUp = {}, 
  allKeys = { 
    isDown = {}, 
    isPressed = {}, 
    isUp = {} 
  },
  player = {},
  mouse = {
    isDown = {}, 
    isPressed = {}, 
    isUp = {},
    x = 0,
    y = 0
  },
  maxConfigurations = 8 
} 

-- Represents the state of love.run while the key in isDown/isUp is active
-- DETECTED: set when the key state is first changed within the event handler
-- APPLIED: set in update immediately after the key state was just DETECTED 
-- This is only used within this file, external users should simply treat isDown/isUp as a boolean
local KEY_CHANGE = { NONE = nil, DETECTED = 1, APPLIED = 2 }
 
local currentDt
 
for i = 1, inputManager.maxConfigurations do 
  inputManager.player[i] = { 
    isDown = {}, 
    isPressed = {}, 
    isUp = {} 
  } 
end

-- map of menu key names (used in inputManager.isDown/Up/Pressed & isPressedWithRepeat)
-- and a tuple of {list of reserved keys, configured game key}
local menuReservedKeysMap = {
  MenuUp = {{"up"}, "Up"}, 
  MenuDown = {{"down"}, "Down"}, 
  MenuLeft = {{"left"}, "Left"}, 
  MenuRight = {{"right"}, "Right"}, 
  MenuEsc = {{"escape", "x"}, "Swap2"},
  MenuNextPage = {{"pageup"}, "Raise1"}, 
  MenuPrevPage = {{"pagedown"}, "Raise2"}, 
  MenuBack = {{"backspace"}, ""}, 
  MenuSelect = {{"return", "kpenter", "z"}, "Swap1"},
}

-- useful alternate representations of the above information
local menuKeyNames = {}
local menuReservedKeys = {}
local keyNameToMenuKeys = {}

for menuKeyName, keys in pairs(menuReservedKeysMap) do
  menuKeyNames[#menuKeyNames + 1] = menuKeyName
  for _, key in ipairs(keys[1]) do
    menuReservedKeys[key] = true
  end
end

for menuKeyName, keyName in pairs(menuReservedKeysMap) do
  keyNameToMenuKeys[keyName[2]] = menuKeyName
end
 
function inputManager:keyPressed(key, scancode, isrepeat) 
  self.allKeys.isDown[key] = KEY_CHANGE.DETECTED
end 
 
function inputManager:keyReleased(key, scancode) 
  self.allKeys.isDown[key] = KEY_CHANGE.NONE
  self.allKeys.isPressed[key] = KEY_CHANGE.NONE 
  self.allKeys.isUp[key] = KEY_CHANGE.DETECTED
end 
 
function inputManager:joystickPressed(joystick, button) 
  self.allKeys.isDown[joystickManager:getJoystickButtonName(joystick, button)] = KEY_CHANGE.DETECTED
end 
 
function inputManager:joystickReleased(joystick, button) 
  local key = joystickManager:getJoystickButtonName(joystick, button) 
  self.allKeys.isDown[key] = KEY_CHANGE.NONE  
  self.allKeys.isPressed[key] = KEY_CHANGE.NONE  
  self.allKeys.isUp[key] = KEY_CHANGE.DETECTED
end 
 
 -- maps joysticks' analog sticks state to the appropriate input maps
function inputManager:joystickToButtons()
  for _, joystick in ipairs(love.joystick.getJoysticks()) do 
    for axisIndex = 1, joystick:getAxisCount() / 2 do
      local dpadState = joystickManager:joystickToDPad(joystick, axisIndex * 2 - 1, axisIndex * 2)
      for key, isPressed in pairs(dpadState) do 
        if isPressed then 
          if not self.allKeys.isDown[key] and not self.allKeys.isPressed[key] then 
            self.allKeys.isDown[key] = KEY_CHANGE.DETECTED 
          end 
        else 
          if self.allKeys.isDown[key] or self.allKeys.isPressed[key] then 
            self.allKeys.isDown[key] = KEY_CHANGE.NONE  
            self.allKeys.isPressed[key] = KEY_CHANGE.NONE  
            self.allKeys.isUp[key] = KEY_CHANGE.DETECTED 
          end 
        end 
      end
    end 
  end 
end

 -- maps joysticks' dpad to the appropriate input maps
function inputManager:dPadToButtons()
  for _, joystick in ipairs(love.joystick.getJoysticks()) do
    for hatIndex = 1, joystick:getHatCount() do
      local dpadState = joystickManager:getDPadState(joystick, hatIndex)
      for key, isPressed in pairs(dpadState) do 
        if isPressed then 
          if not self.allKeys.isDown[key] and not self.allKeys.isPressed[key] then 
            self.allKeys.isDown[key] = KEY_CHANGE.DETECTED 
          end 
        else 
          if self.allKeys.isDown[key] or self.allKeys.isPressed[key] then 
            self.allKeys.isDown[key] = KEY_CHANGE.NONE  
            self.allKeys.isPressed[key] = KEY_CHANGE.NONE  
            self.allKeys.isUp[key] = KEY_CHANGE.DETECTED 
          end 
        end 
      end
    end 
  end 
end 

function inputManager:updateKeyStates(dt, keys)
  currentDt = dt 
  for key, _ in pairs(keys.isDown) do 
    if keys.isDown[key] == KEY_CHANGE.DETECTED then 
      keys.isDown[key] = KEY_CHANGE.APPLIED  
    else 
      keys.isDown[key] = KEY_CHANGE.NONE 
      keys.isPressed[key] = dt 
    end 
  end 
 
  for key, _ in pairs(keys.isPressed) do 
    keys.isPressed[key] = keys.isPressed[key] + dt 
  end 
   
  for key, _ in pairs(keys.isUp) do 
    if keys.isUp[key] == KEY_CHANGE.DETECTED then 
      keys.isUp[key] = KEY_CHANGE.APPLIED   
    else 
      keys.isUp[key] = KEY_CHANGE.NONE 
    end 
  end 
end

function inputManager:aliasKey(key, keyAlias)
  self.isDown[keyAlias] = self.isDown[keyAlias] or self.allKeys.isDown[key] 
  self.isUp[keyAlias] = self.isUp[keyAlias] or self.allKeys.isUp[key] 
  if self.allKeys.isPressed[key] and (not self.isPressed[keyAlias] or self.allKeys.isPressed[key] > self.isPressed[keyAlias]) then  
    self.isPressed[keyAlias] = self.allKeys.isPressed[key] 
  end 
end

-- copy over specific raw key states into the custom input structures defined in the header
function inputManager:updateKeyMaps()
  -- set the reserved key aliases
  for keyAlias, keys in pairs(menuReservedKeysMap) do 
    self.isDown[keyAlias] = KEY_CHANGE.NONE 
    self.isUp[keyAlias] = KEY_CHANGE.NONE 
    self.isPressed[keyAlias] = KEY_CHANGE.NONE 
    for _, key in ipairs(keys[1]) do
      self:aliasKey(key, keyAlias)
    end 
  end

  for _, keyAlias in ipairs(consts.KEY_NAMES) do 
    self.isDown[keyAlias] = KEY_CHANGE.NONE 
    self.isUp[keyAlias] = KEY_CHANGE.NONE 
    self.isPressed[keyAlias] = KEY_CHANGE.NONE 
    for i = 1, GAME.input.maxConfigurations do
      local key = GAME.input.inputConfigurations[i][keyAlias]
      self.player[i].isDown[keyAlias] = self.allKeys.isDown[key] 
      self.player[i].isUp[keyAlias] = self.allKeys.isUp[key] 
      self.player[i].isPressed[keyAlias] = self.allKeys.isPressed[key] 
      
      self:aliasKey(key, keyAlias)
      
      -- copy over configured keys into the menu reserved key aliases if they are not menu reserved keys themselves
      if keyNameToMenuKeys[keyAlias] and not menuReservedKeys[key] then
        local menuKeyAlias = keyNameToMenuKeys[keyAlias]
        self:aliasKey(key, menuKeyAlias)
      end
    end 
  end
end
 
function inputManager:update(dt) 
  self:joystickToButtons()
  self:dPadToButtons()
  self:updateKeyStates(dt, self.allKeys)
  self:updateKeyStates(dt, self.mouse)
  self:updateKeyMaps()
end 

function inputManager:mousePressed(x, y, button)
  if not self.mouse.isDown[button] and not self.mouse.isPressed[button] then
    self.mouse.isDown[button] = KEY_CHANGE.DETECTED
  end
  -- is it intentional we're never setting mouse.isPressed?
  self.mouse.x = x
  self.mouse.y = y
end

function inputManager:mouseReleased(x, y, button)
  self.mouse.isDown[button] = KEY_CHANGE.NONE
  self.mouse.isPressed[button] = KEY_CHANGE.NONE
  self.mouse.isUp[button] = KEY_CHANGE.DETECTED
  self.mouse.x = x
  self.mouse.y = y
end

function inputManager:mouseMoved(x, y)
  self.mouse.x = x
  self.mouse.y = y
end
 
local function quantize(x, period) 
  return math.floor(x / period) * period 
end 
 
function inputManager:isPressedWithRepeat(key, delay, repeatPeriod)
  local inputs = self.allKeys 
  if tableUtils.trueForAny(consts.KEY_NAMES, function(k) return k == key end) or 
     tableUtils.trueForAny(menuKeyNames, function(k) return k == key end) then 
    inputs = inputManager 
  end 
  if inputs.isPressed[key] then 
    local prevDuration = quantize(inputs.isPressed[key] - currentDt, repeatPeriod) 
    local currDuration = quantize(inputs.isPressed[key], repeatPeriod) 
    return inputs.isPressed[key] > delay and prevDuration ~= currDuration 
  else 
    return inputs.isDown[key] 
  end 
end

-- input migration utils
local function convertButton(rawButton)
  local letterToDir = {
    u = "up",
    d = "down",
    l = "left",
    r = "right",
  }
  local button = {rawButton:match("hat(%d+)-(%l+)")}
  if #button ~= 0 then
    return string.format("%s%d", letterToDir[button[2]], button[1])
  end
  
  button = {rawButton:match("axis(%d+)([%+|%-])")}
  if #button ~= 0 then
    return string.format("%s%s%d", button[2] == "+" and "-"  or "+", button[1] % 2 == 0 and "y"  or "x", math.ceil(button[1] / 2.0))
  end
  
  return rawButton
end

local function convertKey(key)
  if not key then
    return nil
  end
  
  local joystickNameParts = {key:match("(.*)#([^-]*)-(.*)")}
  if #joystickNameParts ~= 0 then
    return string.format("%s:%s:%s", joystickNameParts[1], joystickNameParts[2], convertButton(joystickNameParts[3]))
  end
  
  joystickNameParts = {key:match("([^-]*)-(.*)")}
  if #joystickNameParts ~= 0 then
    return string.format("%s:0:%s", joystickNameParts[1], convertButton(joystickNameParts[2]))
  end
  
  return key
end

function inputManager:migrateInputConfigs(inputConfigs)
  local oldToNewKeyMap = {
    up = "Up",
    down = "Down",
    left = "Left",
    right = "Right",
    swap1 = "Swap1",
    swap2 = "Swap2",
    taunt_up = "TauntUp",
    taunt_down = "TauntDown",
    raise1 = "Raise1",
    raise2 = "Raise2",
    pause = "Start",
  }
  if tableUtils.trueForAll(inputConfigs, function(inputConfig) return not inputConfig["Start"] end) then
    for i, inputConfig in ipairs(inputConfigs) do
      for oldKey, newKey in pairs(oldToNewKeyMap) do
        inputConfigs[i][newKey] = convertKey(inputConfig[oldKey])
      end
    end
  end
  return inputConfigs
end
 
return inputManager
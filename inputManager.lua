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
 
 -- maps joysticks' dpad state to the appropriate input maps
function inputManager:joystickToButtons()
  for _, joystick in ipairs(love.joystick.getJoysticks()) do 
    for _, axis in ipairs({"left", "right"}) do
      local dpadState = joystickManager:joystickToDPad(joystick, axis)
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
    if self.allKeys.isDown[key] == KEY_CHANGE.DETECTED then 
      self.allKeys.isDown[key] = KEY_CHANGE.APPLIED  
    else 
      self.allKeys.isDown[key] = KEY_CHANGE.NONE 
      self.allKeys.isPressed[key] = dt 
    end 
  end 
 
  for key, _ in pairs(keys.isPressed) do 
    self.allKeys.isPressed[key] = self.allKeys.isPressed[key] + dt 
  end 
   
  for key, _ in pairs(keys.isUp) do 
    if self.allKeys.isUp[key] == KEY_CHANGE.DETECTED then 
      self.allKeys.isUp[key] = KEY_CHANGE.APPLIED   
    else 
      self.allKeys.isUp[key] = KEY_CHANGE.NONE 
    end 
  end 
end

-- copy over specific raw key states into the custom input structures defined in the header
function inputManager:updateKeyMaps()
  for _, key in ipairs(consts.KEY_NAMES) do 
    self.isDown[key] = KEY_CHANGE.NONE 
    self.isUp[key] = KEY_CHANGE.NONE 
    self.isPressed[key] = KEY_CHANGE.NONE 
    for i = 1, GAME.input.maxConfigurations do
      self.player[i].isDown[key] = self.allKeys.isDown[GAME.input.inputConfigurations[i][key]] 
      self.player[i].isUp[key] = self.allKeys.isUp[GAME.input.inputConfigurations[i][key]] 
      self.player[i].isPressed[key] = self.allKeys.isPressed[GAME.input.inputConfigurations[i][key]] 
       
      self.isDown[key] = self.isDown[key] or self.allKeys.isDown[GAME.input.inputConfigurations[i][key]] 
      self.isUp[key] = self.isUp[key] or self.allKeys.isUp[GAME.input.inputConfigurations[i][key]] 
      if self.allKeys.isPressed[GAME.input.inputConfigurations[i][key]] and (not self.isPressed[key] or self.allKeys.isPressed[GAME.input.inputConfigurations[i][key]] > self.isPressed[key]) then  
        self.isPressed[key] = self.allKeys.isPressed[GAME.input.inputConfigurations[i][key]] 
      end 
    end 
  end 
end
 
function inputManager:update(dt) 
  self:joystickToButtons() 
  self:updateKeyStates(dt, self.allKeys)
  self:updateKeyStates(dt, self.mouse)
  self:updateKeyMaps()
end 

function inputManager:mousePressed(x, y, button)
  self.mouse.isDown[button] = KEY_CHANGE.DETECTED
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
  if tableUtils.trueForAny(consts.KEY_NAMES, function(k) return k == key end) then 
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
 
return inputManager
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
--     the value of isDown & isUp is actually set to one of the following values: (1, 2, nil)
--     This is because the event handlers happen before update, so in order to hold on to the state for one full frame before wiping it
--     there needs to be a marker value which update can track to see if the state has already lasted for a full frame or not
-- Key groups: 
--   allKeys: every key read in by LOVE (includes keyboard, controller, and joystick) 
--   base (top level): all keys mapped by the input.configuration aliased to the consts.KEY_NAMES 
--   player: list of individual input.configuration mappings also aliased by consts.KEY_NAMES 
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
  -- TODO: Convert this into a list of sensitivities per player
  joystickSensitivity = .5,
  maxConfigurations = 8 
} 

-- Represents the state of love.run while the key in isDown/isUp is active
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
 
 -- maps joysticks to buttons by converting the {x, y} axis values to {direction, magnitude} pair
 -- this will give more even mapping along the diagonals when thresholded by a single value (joystickSensitivity)
function inputManager:joystickToButtons()
  for _, joystick in ipairs(love.joystick.getJoysticks()) do 
    for _, axis in ipairs({"left", "right"}) do
      local magSquared, quantizedDir = joystickManager:getQuantizedState(joystick, axis)
      for _, button in ipairs(joystickManager.stickMap[quantizedDir]) do 
        local key = joystickManager:getJoystickButtonName(joystick, button[1]..axis..button[2]) 
        if magSquared > self.joystickSensitivity * self.joystickSensitivity then 
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
      for _, button in ipairs(joystickManager.antiStickMap[quantizedDir]) do 
        local key = joystickManager:getJoystickButtonName(joystick, button[1]..axis..button[2]) 
        if self.allKeys.isDown[key] or self.allKeys.isPressed[key] then 
          self.allKeys.isDown[key] = KEY_CHANGE.NONE  
          self.allKeys.isPressed[key] = KEY_CHANGE.NONE  
          self.allKeys.isUp[key] = KEY_CHANGE.DETECTED  
        end 
      end 
    end 
  end 
end 

function inputManager:updateKeyStates()
  currentDt = dt 
  for key, value in pairs(self.allKeys.isDown) do 
    if self.allKeys.isDown[key] == KEY_CHANGE.DETECTED then 
      self.allKeys.isDown[key] = KEY_CHANGE.APPLIED  
    else 
      self.allKeys.isDown[key] = KEY_CHANGE.NONE 
      self.allKeys.isPressed[key] = dt 
    end 
  end 
 
  for key, value in pairs(self.allKeys.isPressed) do 
    self.allKeys.isPressed[key] = self.allKeys.isPressed[key] + dt 
  end 
   
  for key, value in pairs(self.allKeys.isUp) do 
    if self.allKeys.isUp[key] == KEY_CHANGE.DETECTED   then 
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
  self:updateKeyStates()
  self:updateKeyMaps()
end 
 
local function quantize(x, period) 
  return math.floor(x / period) * period 
end 
 
function inputManager:isPressedWithRepeat(key, delay, repeatPeriod) 
  local inputs = self.allKeys 
  if table.trueForAny(consts.KEY_NAMES, function(k) return k == key end) then 
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
local tableUtils = require("tableUtils") 
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
--   raw: every key read in by LOVE (includes keyboard, controller, and joystick) 
--   base (top level): all keys mapped by the input.configuration aliased to the consts.KEY_NAMES 
--   player: list of individual input.configuration mappings also aliased by consts.KEY_NAMES 
local inputManager = { 
  isDown = {}, 
  isPressed = {}, 
  isUp = {}, 
  raw = { 
    isDown = {}, 
    isPressed = {}, 
    isUp = {} 
  }, 
  player = {}, 
  guidToName = {}, 
  joystickSensitivity = .5, 
  joysticks = {}, 
  maxConfigurations = 8 
} 
 
local currentDt

-- mapping of GUID to map of joysticks under that GUID (GUIDs are unique per controller type)
-- the joystick map is a list of {joystickID: customJoystickID}
-- the custom joystick id is a number starting at 0 and increases by 1 for each new joystick of that type
-- this is to give each joystick an id that will remain consistant over multiple sessions (the joystick IDs can change per session)
local guidsToJoysticks = {}

-- list of {directions, axis} pairs for the 8 cardinal directions
local stickMap = { 
    {{"-", "x"}}, 
    {{"-", "x"}, {"-", "y"}}, 
    {{"-", "y"}}, 
    {{"+", "x"}, {"-", "y"}}, 
    {{"+", "x"}}, 
    {{"+", "x"}, {"+", "y"}}, 
    {{"+", "y"}}, 
    {{"-", "x"}, {"+", "y"}} 
  }
  
-- list of {directions, axis} pairs that need to be cleared for the 8 cardinal directions refrenced in stickMap
local antiStickMap = { 
    {{"+", "x"}, {"+", "y"}, {"-", "y"}}, 
    {{"+", "x"}, {"+", "y"}}, 
    {{"+", "y"}, {"+", "x"}, {"-", "x"}}, 
    {{"-", "x"}, {"+", "y"}}, 
    {{"-", "x"}, {"+", "y"}, {"-", "y"}}, 
    {{"-", "x"}, {"-", "y"}}, 
    {{"-", "y"}, {"+", "x"}, {"-", "x"}}, 
    {{"+", "x"}, {"-", "y"}} 
  } 
 
for i = 1, inputManager.maxConfigurations do 
  inputManager.player[i] = { 
    isDown = {}, 
    isPressed = {}, 
    isUp = {} 
  } 
end 
 
function inputManager:getJoystickButtonName(joystick, button) 
  if not guidsToJoysticks[joystick:getGUID()] then 
    guidsToJoysticks[joystick:getGUID()] = {} 
    self.guidToName[joystick:getGUID()] = joystick:getName() 
  end 
  if not guidsToJoysticks[joystick:getGUID()][joystick:getID()] then 
    guidsToJoysticks[joystick:getGUID()][joystick:getID()] = tableUtils.length(guidsToJoysticks[joystick:getGUID()]) 
  end 
  return string.format("%s:%s:%s", button, joystick:getGUID(), guidsToJoysticks[joystick:getGUID()][joystick:getID()]) 
end 
 
function inputManager:keyPressed(key, scancode, isrepeat) 
  self.raw.isDown[key] = 1 
end 
 
function inputManager:keyReleased(key, scancode) 
  self.raw.isDown[key] = nil 
  self.raw.isPressed[key] = nil 
  self.raw.isUp[key] = 1 
end 
 
function inputManager:gamepadPressed(joystick, button) 
  self.raw.isDown[self:getJoystickButtonName(joystick, button)] = 1 
end 
 
function inputManager:gamepadReleased(joystick, button) 
  local key = self:getJoystickButtonName(joystick, button) 
  self.raw.isDown[key] = nil 
  self.raw.isPressed[key] = nil 
  self.raw.isUp[key] = 1 
end 
 
 -- maps joysticks to buttons by converting the {x, y} axis values to {direction, magnitude} pair
 -- this will give more even mapping along the diagonals when thresholded by a single value (joystickSensitivity)
function inputManager:joystickToButtons() 
  local joysticks2 = love.joystick.getJoysticks() 
  for _, joystick in ipairs(love.joystick.getJoysticks()) do 
    for _, axis in ipairs({"left", "right"}) do 
      local x = axis.."x" 
      local y = axis.."y"

      -- not taking the square root to get the magnitude since it's it more expensive than squaring the joystickSensitivity
      local magSquared = joystick:getGamepadAxis(x) * joystick:getGamepadAxis(x) + joystick:getGamepadAxis(y) * joystick:getGamepadAxis(y)
      local dir = math.atan2(joystick:getGamepadAxis(y), joystick:getGamepadAxis(x)) * 180.0 / math.pi
      -- atan2 maps to [-180, 180] the quantizedDir equation prefers positive numbers (due to modulo) so mapping to [0, 360]
      dir = dir + 180
      -- number of segments we are quantizing the joystick values to
      local numDirSegments = #stickMap
      -- the minimum angle we care to detect
      local quantizationAngle = 360.0 / numDirSegments
      -- if we quantized the raw direction the direction wouldn't register until you are greater than the direction
      -- Ex: quantizedDir would be 0 (left) until you hit exactly 45deg before it changes to 1 (left, up) and would stay there until you are at 90deg
      -- adding this offset so the transition is equidistant from both sides of the direction
      -- Ex: quantizedDir is 1 (left, up) from the range [22.5, 67.5]
      local angleOffset = quantizationAngle / 2
      -- convert the continuous direction value into 8 quantized values which map to the stickMap & antiStickMap indexes
      local quantizedDir = math.floor(((dir + angleOffset) / quantizationAngle) % numDirSegments) + 1 
      for _, button in ipairs(stickMap[quantizedDir]) do 
        local key = self:getJoystickButtonName(joystick, button[1]..axis..button[2]) 
        if magSquared > self.joystickSensitivity * self.joystickSensitivity then 
          if not self.raw.isDown[key] and not self.raw.isPressed[key] then 
            self.raw.isDown[key] = 1 
          end 
        else 
          if self.raw.isDown[key] or self.raw.isPressed[key] then 
            self.raw.isDown[key] = nil 
            self.raw.isPressed[key] = nil 
            self.raw.isUp[key] = 1 
          end 
        end 
      end 
      for _, button in ipairs(antiStickMap[quantizedDir]) do 
        local key = self:getJoystickButtonName(joystick, button[1]..axis..button[2]) 
        if self.raw.isDown[key] or self.raw.isPressed[key] then 
          self.raw.isDown[key] = nil 
          self.raw.isPressed[key] = nil 
          self.raw.isUp[key] = 1 
        end 
      end 
    end 
  end 
end 
 
function inputManager:update(dt) 
  self:joystickToButtons() 
   
  currentDt = dt 
  for key, value in pairs(self.raw.isDown) do 
    if self.raw.isDown[key] == 1 then 
      self.raw.isDown[key] = 2 
    else 
      self.raw.isDown[key] = nil 
      self.raw.isPressed[key] = dt 
    end 
  end 
 
  for key, value in pairs(self.raw.isPressed) do 
    self.raw.isPressed[key] = self.raw.isPressed[key] + dt 
  end 
   
  for key, value in pairs(self.raw.isUp) do 
    if self.raw.isUp[key] == 1 then 
      self.raw.isUp[key] = 2 
    else 
      self.raw.isUp[key] = nil 
    end 
  end 
  
  -- copy over specific raw key states into the custom input structures defined in the header
  for _, key in ipairs(consts.KEY_NAMES) do 
    self.isDown[key] = nil 
    self.isUp[key] = nil 
    self.isPressed[key] = nil 
    for i = 1, GAME.input.maxConfigurations do
      self.player[i].isDown[key] = self.raw.isDown[GAME.input.inputConfigurations[i][key]] 
      self.player[i].isUp[key] = self.raw.isUp[GAME.input.inputConfigurations[i][key]] 
      self.player[i].isPressed[key] = self.raw.isPressed[GAME.input.inputConfigurations[i][key]] 
       
      self.isDown[key] = self.isDown[key] or self.raw.isDown[GAME.input.inputConfigurations[i][key]] 
      self.isUp[key] = self.isUp[key] or self.raw.isUp[GAME.input.inputConfigurations[i][key]] 
      if self.raw.isPressed[GAME.input.inputConfigurations[i][key]] and (not self.isPressed[key] or self.raw.isPressed[GAME.input.inputConfigurations[i][key]] > self.isPressed[key]) then  
        self.isPressed[key] = self.raw.isPressed[GAME.input.inputConfigurations[i][key]] 
      end 
    end 
  end 
end 
 
local function quantize(x, period) 
  return math.floor(x / period) * period 
end 
 
function inputManager:isPressedWithRepeat(key, delay, repeatPeriod) 
  local inputs = self.raw 
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
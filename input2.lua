local tableUtils = require("tableUtils")
local consts = require("consts")

--@module input2
-- table containing the set of keys in various states
-- base structure:
--   isDown: table of {key: true} pairs if the key was pressed in the current frame
--   isUp: table of {key: true} pairs if the key was released in the current frame
--   isPressed: table of {key: time} pairs if the key is currently being held down where total duration held down is stored as time
-- Key groups:
--   raw: every key read in by LOVE (includes keyboard, controller, and joystick)
--   base (top level): all keys mapped by the input.configuration aliased to the consts.KEY_NAMES
--   player: list of individual input.configuration mappings also aliased by consts.KEY_NAMES
local input2 = {
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
local guidsToJoysticks = {}
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

for i = 1, input2.maxConfigurations do
  input2.player[i] = {
    isDown = {},
    isPressed = {},
    isUp = {}
  }
end

function input2:getJoystickButtonName(joystick, button)
  if not guidsToJoysticks[joystick:getGUID()] then
    guidsToJoysticks[joystick:getGUID()] = {}
    self.guidToName[joystick:getGUID()] = joystick:getName()
  end
  if not guidsToJoysticks[joystick:getGUID()][joystick:getID()] then
    guidsToJoysticks[joystick:getGUID()][joystick:getID()] = tableUtils.length(guidsToJoysticks[joystick:getGUID()])
  end
  return string.format("%s:%s:%s", button, joystick:getGUID(), guidsToJoysticks[joystick:getGUID()][joystick:getID()])
end

function input2:keyPressed(key, scancode, isrepeat)
  self.raw.isDown[key] = 1
end

function input2:keyReleased(key, scancode)
  self.raw.isDown[key] = nil
  self.raw.isPressed[key] = nil
  self.raw.isUp[key] = 1
end

function input2:gamepadPressed(joystick, button)
  self.raw.isDown[self:getJoystickButtonName(joystick, button)] = 1
end

function input2:gamepadReleased(joystick, button)
  local key = self:getJoystickButtonName(joystick, button)
  self.raw.isDown[key] = nil
  self.raw.isPressed[key] = nil
  self.raw.isUp[key] = 1
end

function input2:joystickToButtons()
  local joysticks2 = love.joystick.getJoysticks()
  for _, joystick in ipairs(love.joystick.getJoysticks()) do
    for _, axis in ipairs({"left", "right"}) do
      local x = axis.."x"
      local y = axis.."y"
      local mag = math.sqrt(joystick:getGamepadAxis(x) * joystick:getGamepadAxis(x) + joystick:getGamepadAxis(y) * joystick:getGamepadAxis(y))
      local dir = math.atan2(joystick:getGamepadAxis(y), joystick:getGamepadAxis(x)) * 180.0 / math.pi
      local quantizedDir = math.floor(((dir + 180 + 45 / 2) / 45.0) % 8) + 1
      for _, button in ipairs(stickMap[quantizedDir]) do
        local key = self:getJoystickButtonName(joystick, button[1]..axis..button[2])
        if mag > self.joystickSensitivity then
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

function input2:update(dt)
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

function input2:isPressedWithRepeat(key, delay, repeatPeriod)
  local inputs = self.raw
  if tableUtils.trueForAny(consts.KEY_NAMES, function(k) return k == key end) then
    inputs = input2
  end
  if inputs.isPressed[key] then
    local prevDuration = quantize(inputs.isPressed[key] - currentDt, repeatPeriod)
    local currDuration = quantize(inputs.isPressed[key], repeatPeriod)
    return inputs.isPressed[key] > delay and prevDuration ~= currDuration
  else
    return inputs.isDown[key]
  end
end

return input2
local table_utils = require("table_utils")
local consts = require("consts")

--@module input2
local input2 = {
  isDown = {},
  isPressed = {},
  isUp = {},
  raw = {
    isDown = {},
    isPressed = {},
    isUp = {}
  },
  guid_to_name = {},
  sensitivity = .75
}

local current_dt
local guids_to_joysticks = {}

function input2:getJoystickButtonName(joystick, button)
  if not guids_to_joysticks[joystick:getGUID()] then
    guids_to_joysticks[joystick:getGUID()] = {}
    self.guid_to_name[joystick:getGUID()] = joystick:getName()
  end
  if not guids_to_joysticks[joystick:getGUID()][joystick:getID()] then
    guids_to_joysticks[joystick:getGUID()][joystick:getID()] = table_utils.length(guids_to_joysticks[joystick:getGUID()])
  end
  return string.format("%s:%s:%s", button, joystick:getGUID(), guids_to_joysticks[joystick:getGUID()][joystick:getID()])
end

function input2:keyPressed(key, scancode, isrepeat)
  self.raw.isDown[key] = 1
end

function input2:keyReleased(key, scancode)
  self.raw.isPressed[key] = nil
  self.raw.isUp[key] = 1
end

function input2:gamepadPressed(joystick, button)
  self.raw.isDown[self:getJoystickButtonName(joystick, button)] = 1
end

function input2:gamepadReleased(joystick, button)
  self.raw.isPressed[self:getJoystickButtonName(joystick, button)] = nil
  self.raw.isUp[self:getJoystickButtonName(joystick, button)] = 1
end

function input2:gamepadAxis(joystick, axis, value)
  local sign = value > 0 and "+" or "-"
  local axis_name = sign..axis
  local axis_keys = {
    {self:getJoystickButtonName(joystick, "+"..axis), math.abs(math.max(value, 0))},
    {self:getJoystickButtonName(joystick, "-"..axis), math.abs(math.min(value, 0))}
  }
  for _, key_value in ipairs(axis_keys) do
    local key, value = unpack(key_value)
    if value > self.sensitivity then
      if not self.raw.isDown[key] and not self.raw.isPressed[key] then
        self.raw.isDown[key] = 1
      end
    else
      if self.raw.isDown[key] or self.raw.isPressed[key] then
        self.raw.isPressed[key] = nil
        self.raw.isUp[key] = 1
      end
    end
  end
  
end

function input2:update(dt)
  current_dt = dt
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

-- FIX THIS!
function input2:isPressedWithRepeat(key, delay, repeat_period)
  local inputs = self.raw
  if table.trueForAny(consts.KEY_NAMES, function(k) return k == key end) then
    inputs = input2
  end
  if inputs.isPressed[key] then
    local prev_duration = quantize(inputs.isPressed[key] - current_dt, repeat_period)
    local curr_duration = quantize(inputs.isPressed[key], repeat_period)
    return inputs.isPressed[key] > delay and prev_duration ~= curr_duration
  else
    return inputs.isDown[key]
  end
end

return input2
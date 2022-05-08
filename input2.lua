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
  sensitivity = .5,
  joysticks = {}
}

local current_dt
local guids_to_joysticks = {}
local stick_map = {
    {{"-", "x"}},
    {{"-", "x"}, {"-", "y"}},
    {{"-", "y"}},
    {{"+", "x"}, {"-", "y"}},
    {{"+", "x"}},
    {{"+", "x"}, {"+", "y"}},
    {{"+", "y"}},
    {{"-", "x"}, {"+", "y"}}
  }
local anti_stick_map = {
    {{"+", "x"}, {"+", "y"}, {"-", "y"}},
    {{"+", "x"}, {"+", "y"}},
    {{"+", "y"}, {"+", "x"}, {"-", "x"}},
    {{"-", "x"}, {"+", "y"}},
    {{"-", "x"}, {"+", "y"}, {"-", "y"}},
    {{"-", "x"}, {"-", "y"}},
    {{"-", "y"}, {"+", "x"}, {"-", "x"}},
    {{"+", "x"}, {"-", "y"}}
  }

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
      local quantized_dir = math.floor(((dir + 180 + 45 / 2) / 45.0) % 8) + 1
      for _, button in ipairs(stick_map[quantized_dir]) do
        local key = self:getJoystickButtonName(joystick, button[1]..axis..button[2])
        if mag > self.sensitivity then
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
      for _, button in ipairs(anti_stick_map[quantized_dir]) do
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
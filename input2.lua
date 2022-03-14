--@module input2
local input2 = {
  isDown = {},
  isPressed = {},
  isUp = {}
}

local current_dt

function input2:keyPressed(key, scancode, isrepeat)
  -- print(key)
  self.isDown[key] = 1
end

function input2:keyReleased(key, scancode)
  self.isPressed[key] = nil
  self.isUp[key] = 1
end

function input2:update(dt)
  current_dt = dt
  for key, value in pairs(self.isDown) do
    if self.isDown[key] == 1 then
      self.isDown[key] = 2
    else
      self.isDown[key] = nil
      self.isPressed[key] = dt
    end
  end

  for key, value in pairs(self.isPressed) do
    self.isPressed[key] = self.isPressed[key] + dt
  end
  
  for key, value in pairs(self.isUp) do
    if self.isUp[key] == 1 then
      self.isUp[key] = 2
    else
      self.isUp[key] = nil
    end
  end
end

local function quantize(x, period)
  return math.floor(x / period) * period
end

function input2:isPressedWithRepeat(key, delay, repeat_period)
  if self.isPressed[key] then
    local prev_duration = quantize(self.isPressed[key] - current_dt, repeat_period)
    local curr_duration = quantize(self.isPressed[key], repeat_period)
    return self.isPressed[key] > delay and prev_duration ~= curr_duration
  else
    return self.isDown[key]
  end
end

return input2
--@module input2
local input2 = {
  isDown = {},
  isPressed = {},
  isUp = {}
}

function input2:keypressed(key, scancode, isrepeat)
  -- print(key)
  self.isDown[key] = 1
end

function input2:keyreleased(key, scancode)
  self.isPressed[key] = nil
  self.isUp[key] = 1
end

function input2:update()
  for key, value in pairs(self.isDown) do
    if self.isDown[key] == 1 then
      self.isDown[key] = 2
    else
      self.isDown[key] = nil
      self.isPressed[key] = 1
    end
  end

  for key, value in pairs(self.isPressed) do
    self.isPressed[key] = self.isPressed[key] + 1
  end
  
  for key, value in pairs(self.isUp) do
    if self.isUp[key] == 1 then
      self.isUp[key] = 2
    else
      self.isUp[key] = nil
    end
  end
end


return input2
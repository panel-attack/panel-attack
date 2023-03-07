local loadingIndicator = {}

loadingIndicator.timer = 0
loadingIndicator.indicators = { false, false, false}

function loadingIndicator.setDrawPosition(self, width, height)
  self.width = width
  self.height = height
end

function loadingIndicator.setFont(self, font)
  self.font = font
end

function loadingIndicator.draw(self)
  -- draw an indicator to indicate that the window is alive and kicking even during a download
  self.timer = self.timer + 1
  if self.timer % 60 == 20 then
    self.indicators[1] = not self.indicators[1]
  elseif self.timer % 60 == 40 then
    self.indicators[2] = not self.indicators[2]
  elseif self.timer % 60 == 0 then
    self.indicators[3] = not self.indicators[3]
  end

  if self.indicators[1] then
    love.graphics.print(".", self.font, self.width / 2 - 15, self.height * 0.75)
  end
  if self.indicators[2] then
    love.graphics.print(".", self.font, self.width / 2     , self.height * 0.75)
  end
  if self.indicators[3] then
    love.graphics.print(".", self.font, self.width / 2 + 15, self.height * 0.75)
  end
end

return loadingIndicator
local class = require("class")
local UIElement = require("ui.UIElement")

--@module Label
local Label = class(
  function(self, options)
    self.width = options.width or 110
    self.height = options.height or 25
    
    local textWidth, textHeight = self.text:getDimensions()
    self.width = math.max(textWidth + 6, self.width)
    self.height = math.max(textHeight + 6, self.height)
    self.TYPE = "Label"
  end,
  UIElement
)

function Label:draw()
  local screenX, screenY = self:getScreenPos()
  
  local darkGray = .5
  local lightGray = .7
  local alpha = .7
  GAME.gfx_q:push({love.graphics.setColor, {darkGray, darkGray, 1, alpha}})
  GAME.gfx_q:push({love.graphics.rectangle, {"fill", screenX, screenY, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, {lightGray, lightGray, 1, alpha}})
  GAME.gfx_q:push({love.graphics.rectangle, {"line", screenX, screenY, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  
  local textWidth, textHeight = self.text:getDimensions()
  GAME.gfx_q:push({love.graphics.draw, {self.text, screenX + self.width / 2, screenY + self.height / 2, 0, 1, 1, textWidth / 2, textHeight / 2}})
end

return Label
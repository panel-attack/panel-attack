local class = require("class")
local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")

--@module Label
local Label = class(
  function(self, options)
    -- stretch to fit text
    local textWidth, textHeight = self.text:getDimensions()
    self.width = math.max(textWidth + 15, self.width)
    self.height = math.max(textHeight + 15, self.height)
    self.TYPE = "Label"
  end,
  UIElement
)

function Label:draw()
  if not self.isVisible then
    return
  end

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
  GraphicsUtil.drawClearText(self.text, screenX + self.width / 2, screenY + self.height / 2, textWidth / 2, textHeight / 2)
  
  -- draw children
  UIElement.draw(self)
end

return Label
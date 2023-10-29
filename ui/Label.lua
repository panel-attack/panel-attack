local class = require("class")
local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")

local TEXT_WIDTH_PADDING = 15
local TEXT_HEIGHT_PADDING = 6
--@module Label
local Label = class(
  function(self, options)
    -- stretch to fit text
    local textWidth, textHeight = self.text:getDimensions()
    self.width = math.max(textWidth + TEXT_WIDTH_PADDING, self.width)
    self.height = math.max(textHeight + TEXT_HEIGHT_PADDING, self.height)
    self.color = {.5, .5, 1, .7}
    self.borderColor = {.7, .7, 1, .7}
    self.TYPE = "Label"
  end,
  UIElement
)

function Label:draw()
  if not self.isVisible then
    return
  end

  local screenX, screenY = self:getScreenPos()
  
  GAME.gfx_q:push({love.graphics.setColor, self.color})
  GAME.gfx_q:push({love.graphics.rectangle, {"fill", screenX, screenY, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, self.borderColor})
  GAME.gfx_q:push({love.graphics.rectangle, {"line", screenX, screenY, self.width, self.height}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  
  local textWidth, textHeight = self.text:getDimensions()
  GraphicsUtil.drawClearText(self.text, screenX + self.width / 2, screenY + self.height / 2, textWidth / 2, textHeight / 2)
  
  -- draw children
  UIElement.draw(self)
end

return Label
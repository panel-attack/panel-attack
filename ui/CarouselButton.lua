local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")
local Button = require("ui.Button")
local class = require("class")

local CarouselButton = class(
  function(self, options)
    self.containerHeight = options.containerHeight
    self.direction = options.direction
  end,
  Button
)

-- x, width: x-offset and width of the passenger element
function CarouselButton:draw(width)
  if not self.isVisible then
    return
  end

  self.width = (self.parent.width - width) / 2
  self.height = self.parent.height
  if self.direction == "left" then
    self.x = 0
  elseif self.direction == "right" then
    self.x = self.parent.width - self.width
  else
    error("carousels only know left and right for their buttons")
  end
  local boxOffsetX, boxOffsetY = self:getScreenPos()
  local textWidth, textHeight = self.text:getDimensions()

  local xPosAlign, xOffset = self.width / 2, textWidth / 2
  local yPosAlign, yOffset = self.height / 2, textHeight / 2

  GraphicsUtil.drawClearText(self.text, boxOffsetX + xPosAlign, boxOffsetY + yPosAlign, xOffset, yOffset)
end

return CarouselButton
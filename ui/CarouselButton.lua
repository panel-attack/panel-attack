local GraphicsUtil = require("graphics_util")
local TextButton = require("ui.TextButton")
local class = require("class")

local CarouselButton = class(
  function(self, options)
    self.direction = options.direction
  end,
  TextButton
)

function CarouselButton:updatePosition(width)
  self.width = (self.parent.width - width) / 2
  self.height = self.parent.height
  if self.direction == "left" then
    self.x = 0
  elseif self.direction == "right" then
    self.x = self.parent.width - self.width
  else
    error("carousels only know left and right for their buttons")
  end
end

-- width: width of the passenger element
function CarouselButton:draw()
  if not self.isVisible then
    return
  end

  local boxOffsetX, boxOffsetY = self:getScreenPos()
  local textWidth, textHeight = self.label.width, self.label.height

  local xPosAlign, xOffset = self.width / 2, textWidth / 2
  local yPosAlign, yOffset = self.height / 2, textHeight / 2

  --GraphicsUtil.drawClearText(self.label, boxOffsetX + xPosAlign, boxOffsetY + yPosAlign, xOffset, yOffset)
  self:drawChildren()
end

return CarouselButton
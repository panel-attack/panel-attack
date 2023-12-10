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
  self.label.width = self.width
  self.label.height = self.height
  if self.direction == "left" then
    self.x = 0
  elseif self.direction == "right" then
    self.x = self.parent.width - self.width
  else
    error("carousels only know left and right for their buttons")
  end
end

return CarouselButton
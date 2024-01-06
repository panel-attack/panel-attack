local GraphicsUtil = require("graphics_util")
local TextButton = require("ui.TextButton")
local class = require("class")

local CarouselButton = class(
  function(self, options)
    self.direction = options.direction
  end,
  TextButton
)

return CarouselButton
local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local ValueLabel = class(function(self, options)
  assert(options.valueFunction, "Value labels need a function to poll the value!")
  self.valueFunction = options.valueFunction
end,
UiElement)

function ValueLabel:drawSelf()
  love.graphics.print(self.valueFunction(), self.x, self.y)
end

return ValueLabel
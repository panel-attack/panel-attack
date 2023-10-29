local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")
local Button = require("ui.Button")
local class = require("class")

local ArrowButton = class(
  function(self, options)

  end,
  Button
)
function ArrowButton:draw()
  if not self.isVisible then
    return
  end

  local screenX, screenY = self:getScreenPos()

  local textWidth, textHeight = self.text:getDimensions()
  local xAlignments = {
    center = {self.width / 2, textWidth / 2},
    left = {0, 0},
    right = {self.width, textWidth},
  }
  local yAlignments = {
    center = {self.height / 2, textHeight / 2},
    top = {0, 0},
    bottom = {self.height, textHeight},
  }
  local xPosAlign, xOffset = unpack(xAlignments[self.halign])
  local yPosAlign, yOffset = unpack(yAlignments[self.valign])

  GraphicsUtil.drawClearText(self.text, screenX + xPosAlign, screenY + yPosAlign, xOffset, yOffset)
end

return ArrowButton
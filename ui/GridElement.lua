local class = require("class")
local UiElement = require("ui.UIElement")
local util = require("util")
local GraphicsUtil = require("graphics_util")
local input = require("inputManager")

local GridElement = class(function(gridElement, options)
  if options.content then
    gridElement.content = options.content
    -- we still need to add it for the relative offset
    gridElement:addChild(gridElement.content)
  end
  gridElement.description = options.description
end, UiElement)

function GridElement:getScreenPos()
  local x, y = self.parent:getScreenPos()
  return x + self.x + self.parent.unitPadding, y + self.y + self.parent.unitPadding
end

function GridElement:drawBorders()
  local x, y = self:getScreenPos()
  grectangle("line", x, y, self.width - self.parent.unitPadding * 2, self.height - self.parent.unitPadding * 2)
end

function GridElement:draw()
  self:drawBorders()
  -- TODO match size of contents to the available space
  if self.content then
    if self.content.draw then
      self.content:draw()
    elseif self.content:typeOf("Drawable") then
      draw(self.content, self:getScreenPos())
    end
  end
end

return GridElement

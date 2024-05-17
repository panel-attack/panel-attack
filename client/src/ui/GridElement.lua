local class = require("class")
local UiElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")

local GridElement = class(function(gridElement, options)
  if options.content then
    gridElement.content = options.content
    -- we still need to add it for the relative offset
    gridElement:addChild(gridElement.content)
  end
  gridElement.description = options.description
  gridElement.gridOriginX = options.gridOriginX
  gridElement.gridOriginY = options.gridOriginY
  gridElement.gridWidth = options.gridWidth
  gridElement.gridHeight = options.gridHeight
  gridElement.TYPE = "GridElement"
end, UiElement)

function GridElement:drawBorders()
  GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
end

function GridElement:drawSelf()
  if DEBUG_ENABLED or ((self.gridWidth ~= 1 or self.gridHeight ~= 1) and (self.x % self.parent.unitSize > 0 or self.y % self.parent.unitSize > 0)) then
    self:drawBorders()
  end
end

return GridElement

local class = require("class")
local UiElement = require("ui.UIElement")

local GridElement = class(function(gridElement, options)
  if options.content then
    gridElement.content = options.content
    gridElement.content.width = options.width
    gridElement.content.height = options.height
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

function GridElement:getScreenPos()
  local x, y = self.parent:getScreenPos()
  return x + self.x, y + self.y
end

function GridElement:drawBorders()
  grectangle("line", self.x, self.y, self.width, self.height)
end

function GridElement:drawSelf()
  if DEBUG_ENABLED then
    self:drawBorders()
  end
end

return GridElement

local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")

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
  if options.drawBorders ~= nil then
    gridElement.drawBorders = options.drawBorders
  elseif DEBUG_ENABLED then
    gridElement.drawBorders = true
  else
    gridElement.drawBorders = false
  end
  gridElement.TYPE = "GridElement"
end, UiElement)

function GridElement:drawSelf()
  if self.drawBorders then
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
  end
end

return GridElement

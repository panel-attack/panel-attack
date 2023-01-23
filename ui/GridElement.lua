local class = require("class")
local UiElement = require("ui.UIElement")
local util = require("util")
local GraphicsUtil = require("graphics_util")
local input = require("inputManager")

local GridElement = class(
  function(gridElement, options)
    gridElement.content = options.content
  end,
  UiElement
)

function GridElement:drawBorders()
  local x, y = self:getScreenPos()
  grectangle("line", x, y, self.width, self.height)
end

function GridElement:draw()
  self:drawBorders()
  -- TODO match size of contents to the available space
  self.content:draw()
end

return GridElement
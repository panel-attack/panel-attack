local class = require("class")
local UiElement = require("ui.UIElement")
local GridElement = require("ui.GridElement")
local GraphicsUtil = require("graphics_util")

local Grid = class(function(self, options)
  self.unitSize = options.unitSize
  self.unitMargin = options.unitMargin or 0
  self.gridHeight = options.gridHeight
  self.gridWidth = options.gridWidth
  self.width = self.gridWidth * self.unitSize
  self.height = self.gridHeight * self.unitSize
  self.grid = {}
  for row = 1, options.gridHeight do
    self.grid[row] = {}
    -- for col = 1, options.gridWidth do
    --   self.grid[row][col] = {}
    -- end
  end
  self.TYPE = "Grid"
end, UiElement)

-- width and height are sizes relative to the unitSize of the grid
-- id is a string identificator to indiate what kind of uiElement resides here
-- uiElement is the actual element on display that will perform user interaction when selected
function Grid:createElementAt(x, y, width, height, description, uiElement, noPadding)
  local unitMargin = self.unitMargin
  if noPadding then
    unitMargin = 0
  end
  local gridElement = GridElement({
    x = (x - 1) * self.unitSize + unitMargin,
    y = (y - 1) * self.unitSize + unitMargin,
    width = width * self.unitSize - unitMargin * 2,
    height = height * self.unitSize - unitMargin * 2,
    gridOriginX = x,
    gridOriginY = y,
    gridWidth = width,
    gridHeight = height,
    description = description,
    content = uiElement
  })
  self:addChild(gridElement)

  for row = y, y + (height - 1) do
    for col = x, x + (width - 1) do
      -- ensure the area is still free
      if self.grid[row][col] then
        error("Error trying to create a grid element:\n" .. "There is already element " .. self.grid[row][col].id .. " at coordinate " ..
                  row .. "|" .. col)
      else
        -- assign the gridElement to the respective areas to make sure they are blocked
        self.grid[row][col] = gridElement
      end
    end
  end

  if gridElement.content.onSelect or gridElement.content.isFocusable then
    gridElement.onSelect = function(self, selector)
      if selector.setFocus and self.content.isFocusable then
        selector:setFocus(self.content)
      else
        self.content:onSelect(selector)
      end
    end
  end

  return gridElement
end

function Grid:drawSelf()
  if DEBUG_ENABLED then
    GraphicsUtil.setColor(1, 1, 1, 0.5)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
    -- draw all units
    local right = self.x + self.width
    local bottom = self.y + self.height
    for i = 1, self.gridHeight - 1 do
      local y = self.y + self.unitSize * i
      GraphicsUtil.drawStraightLine(self.x, y, right, y, 1, 1, 1, 0.5)
    end
    for i = 1, self.gridWidth - 1 do
      local x = self.x + self.unitSize * i
      GraphicsUtil.drawStraightLine(x, self.y, x, bottom, 1, 1, 1, 0.5)
    end
  end
end

function Grid:getElementAt(row, column)
  if self.grid[row][column] then
    return self.grid[row][column]
  else
    -- return a placeholder element that represents where the element *would* be
    local placeholder =
    {
      width = self.unitSize - self.unitMargin * 2,
      height = self.unitSize - self.unitMargin * 2,
      gridOriginX = column,
      gridOriginY = row,
      gridWidth = 1,
      gridHeight = 1,
      x = (column - 1) * self.unitSize + self.unitMargin,
      y = (row - 1) * self.unitSize + self.unitMargin,
      content = { TYPE = "GridPlaceholder"}
    }
    placeholder.getScreenPos = function ()
      local cX, cY = self:getScreenPos()
      return cX + placeholder.x, cY + placeholder.y
    end
    return placeholder
  end
end

return Grid

local class = require("class")
local UiElement = require("ui.UIElement")
local tableUtils = require("tableUtils")
local GridElement = require("ui.GridElement")
local directsFocus = require("ui.FocusDirector")

local Grid = class(function(self, options)
  directsFocus(self)
  self.unitSize = options.unitSize
  self.unitPadding = options.unitPadding or 0
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
  local unitPadding = self.unitPadding
  if noPadding then
    unitPadding = 0
  end
  local gridElement = GridElement({
    x = (x - 1) * self.unitSize + unitPadding,
    y = (y - 1) * self.unitSize + unitPadding,
    width = width * self.unitSize - unitPadding * 2,
    height = height * self.unitSize - unitPadding * 2,
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

  gridElement.onSelect = function()
    if gridElement.content.isFocusable then
      self:setFocus(gridElement.content)
    else
      gridElement.content:onSelect()
    end
  end

end

function Grid.onSelect()

end

function Grid.onMove(x, y)

end

function Grid.onBack()

end

function Grid:draw()
  if DEBUG_ENABLED then
    local left, top = self:getScreenPos()

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", left, top, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
    -- draw all units
    local right = left + self.width
    local bottom = top + self.height
    for i = 1, self.gridHeight - 1 do
      local y = top + self.unitSize * i
      drawStraightLine(left, y, right, y, 1, 1, 1, 0.5)
    end
    for i = 1, self.gridWidth - 1 do
      local x = left + self.unitSize * i
      drawStraightLine(x, top, x, bottom, 1, 1, 1, 0.5)
    end
  end

  for _, gridElement in ipairs(self.children) do
    if gridElement.isVisible then
      gridElement:draw()
    end
  end
end

return Grid

local class = require("class")
local UiElement = require("ui.UIElement")
local tableUtils = require("tableUtils")
local GridElement = require("ui.GridElement")
local directsFocus = require("ui.FocusDirector")

local Grid = class(function(self, options)
  directsFocus(self)
  self.unitSize = options.unitSize
  self.grid = {}
  for row = 1, options.gridHeight do
    self.grid[row] = {}
    for col = 1, options.gridWidth do
      self.grid[row][col] = {}
    end
  end
end, UiElement)

-- width and height are sizes relative to the unitSize of the grid
-- id is a string identificator to indiate what kind of uiElement resides here
-- uiElement is the actual element on display that will perform user interaction when selected
function Grid:createElementAt(x, y, width, height, id, uiElement)
  local gridElement = GridElement({width = width * self.unitSize, height = height * self.unitSize, id = id, content = uiElement})
  self:addChild(gridElement)

  for row = y, y + height do
    for col = x, x + width do
      -- ensure the area is still free
      if tableUtils.length(self.grid[row][col]) > 0 then
        error("Error trying to create a grid element:\n" .. "There is already element " .. self.grid[row][col].id .. " at coordinate " .. row .. "|" .. col)
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

-- default draw func works
-- function Grid.draw() end

function Grid.onSelect()

end

function Grid.onMove(x, y)

end

function Grid.onBack()

end

return Grid


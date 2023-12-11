local UiElement = require("ui.UIElement")
local Grid = require("ui.Grid")
local class = require("class")

local function addNewPage(pagedUniGrid)
  local grid = Grid({
    unitSize = pagedUniGrid.unitSize,
    unitMargin = pagedUniGrid.unitMargin,
    gridWidth = pagedUniGrid.gridWidth,
    gridHeight = pagedUniGrid.gridHeight
  })
  pagedUniGrid.pages[#pagedUniGrid.pages + 1] = grid
  pagedUniGrid.lastFilledUnit = {x = 0, y = 0}
  pagedUniGrid:addChild(grid)
  pagedUniGrid.TYPE = "PagedUniGrid"
end

local function goToPage(pagedUniGrid, pageNumber)
  pagedUniGrid.currentPage = pageNumber
  local elementsPerPage = pagedUniGrid.gridHeight * pagedUniGrid.gridWidth
  for i = 1, #pagedUniGrid.elements do
    if i <= pageNumber * elementsPerPage and i > (pageNumber - 1) * elementsPerPage then
      -- is on current page
      pagedUniGrid.elements[i]:setVisibility(true)
    else
      -- is not on current page
      pagedUniGrid.elements[i]:setVisibility(false)
    end
  end
end

-- A paged uniform grid is a grid that only has grid elements of constant size
-- elements are added left to right, top to bottom
-- Once full, it creates however many pages are necessary to store all elements added to it
-- the main thing it shares with the regular grid is the cursor navigation
local PagedUniGrid = class(function(self, options)
  self.unitSize = options.unitSize
  self.unitMargin = options.unitMargin or 0
  self.gridHeight = options.gridHeight
  self.gridWidth = options.gridWidth
  self.elements = {}
  self.pages = {}
  addNewPage(self)
  goToPage(self, 1)
end, UiElement)

function PagedUniGrid:addElement(element)
  if self.lastFilledUnit.x == self.gridWidth and self.lastFilledUnit.y == self.gridHeight then
    addNewPage(self)
    self.lastFilledUnit.x = 0
    self.lastFilledUnit.y = 0
  end

  self.elements[#self.elements+1] = element

  -- determining the next free position on the current page
  if self.lastFilledUnit.x == 0 or self.lastFilledUnit.x == self.gridWidth then
    self.lastFilledUnit.x = 1
    self.lastFilledUnit.y = self.lastFilledUnit.y + 1
  else
    self.lastFilledUnit.x = self.lastFilledUnit.x + 1
  end

  self.pages[#self.pages]:createElementAt(self.lastFilledUnit.x, self.lastFilledUnit.y, 1, 1, #self.elements, element)
  if self.currentPage ~= #self.pages then
    element:setVisibility(false)
  end
end

function PagedUniGrid:turnPage(sign)
  local newPageNumber = wrap(1, self.currentPage + math.sign(sign), #self.pages)
  goToPage(self, newPageNumber)
end

function PagedUniGrid:drawSelf()
  if DEBUG_ENABLED then
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function PagedUniGrid:getElementAt(row, column)
  return self.pages[self.currentPage]:getElementAt(row, column)
end

return PagedUniGrid

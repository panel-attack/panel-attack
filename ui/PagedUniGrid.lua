local UiElement = require("ui.UIElement")
local Grid = require("ui.Grid")
local class = require("class")

local function addNewPage(pagedUniGrid)
  local grid = Grid({
    unitSize = pagedUniGrid.unitSize,
    unitPadding = pagedUniGrid.unitPadding,
    gridWidth = pagedUniGrid.gridWidth,
    gridHeight = pagedUniGrid.gridHeight
  })
  pagedUniGrid.pages[#pagedUniGrid.pages + 1] = grid
  pagedUniGrid.currentPage = #pagedUniGrid.pages
  pagedUniGrid.lastFilledUnit = {x = 0, y = 0}
  pagedUniGrid:addChild(grid)
  pagedUniGrid.TYPE = "PagedUniGrid"
end

-- A paged uniform grid is a grid that only has grid elements of constant size
-- elements are added left to right, top to bottom
-- Once full, it creates however many pages are necessary to store all elements added to it
-- the main thing it shares with the regular grid is the cursor navigation
local PagedUniGrid = class(function(self, options)
  self.unitSize = options.unitSize
  self.unitPadding = options.unitPadding or 0
  self.gridHeight = options.gridHeight
  self.gridWidth = options.gridWidth
  self.elements = {}
  self.pages = {}
  addNewPage(self)
end, UiElement)

function PagedUniGrid:addElement(element)
  if self.lastFilledUnit.x == self.gridWidth and self.lastFilledUnit.y == self.gridHeight then
    addNewPage(self)
    self.currentPage = #self.pages
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

  self.pages[self.currentPage]:createElementAt(self.lastFilledUnit.x, self.lastFilledUnit.y, 1, 1, #self.elements, element)
end

function PagedUniGrid:turnPage(sign)
  self.currentPage = wrap(1, self.currentPage + math.sign(sign), #self.pages)
end

function PagedUniGrid:draw()
  self.pages[self.currentPage]:draw()
end

return PagedUniGrid

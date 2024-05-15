local UiElement = require("ui.UIElement")
local Grid = require("ui.Grid")
local class = require("class")
local TextButton = require("ui.TextButton")
local Label = require("ui.Label")
local Signal = require("helpers.signal")
local GraphicsUtil = require("graphics_util")

local function addNewPage(pagedUniGrid)
  local grid = Grid({
    unitSize = pagedUniGrid.unitSize,
    unitMargin = pagedUniGrid.unitMargin,
    gridWidth = pagedUniGrid.gridWidth,
    gridHeight = pagedUniGrid.gridHeight
  })
  pagedUniGrid.pages[#pagedUniGrid.pages + 1] = grid
  pagedUniGrid.lastFilledUnit = {x = 0, y = 0}
  pagedUniGrid:refreshPageTurnButtonVisibility()
end

local function goToPage(pagedUniGrid, pageNumber)
  if pagedUniGrid.currentPage then
    pagedUniGrid.pages[pagedUniGrid.currentPage]:detach()
  end
  pagedUniGrid:addChild(pagedUniGrid.pages[pageNumber])
  pagedUniGrid.currentPage = pageNumber
  pagedUniGrid:refreshPageTurnButtonVisibility()
end

-- A paged uniform grid is a grid that only has grid elements of constant size
-- elements are added left to right, top to bottom
-- Once full, it creates however many pages are necessary to store all elements added to it
-- the main thing it shares with the regular grid is the cursor navigation
local PagedUniGrid = class(function(self, options)
  self.TYPE = "PagedUniGrid"

  self.unitSize = options.unitSize
  self.unitMargin = options.unitMargin or 0
  self.gridHeight = options.gridHeight
  self.gridWidth = options.gridWidth
  self.width = self.unitSize * self.gridWidth
  self.height = self.unitSize * self.gridHeight
  self.elements = {}
  self.pages = {}
  self.pageTurnButtons = {}
  self.pageTurnButtons.left = TextButton({
    label = Label({text = "<", translate = false}),
    hAlign = "left",
    vAlign = "top",
    width = self.unitSize / 2,
    height = self.unitSize / 2,
    onClick = function(selfElement, inputSource, holdTime) self:turnPage(-1) end,
  })
  self.pageTurnButtons.right = TextButton({
    label = Label({text = ">", translate = false}),
    hAlign = "left",
    vAlign = "top",
    width = self.unitSize / 2,
    height = self.unitSize / 2,
    onClick = function(selfElement, inputSource, holdTime) self:turnPage(1) end,
  })
  addNewPage(self)
  goToPage(self, 1)

  Signal.turnIntoEmitter(self)
  self:createSignal("pageTurned")
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
end

function PagedUniGrid:turnPage(sign)
  local newPageNumber = wrap(1, self.currentPage + math.sign(sign), #self.pages)
  goToPage(self, newPageNumber)
  self:emitSignal("pageTurned", self, self.currentPage)
end

function PagedUniGrid:refreshPageTurnButtonVisibility()
  if self.currentPage then
    self.pageTurnButtons.right:setVisibility(self.currentPage < #self.pages)
    self.pageTurnButtons.left:setVisibility(self.currentPage > 1)
  end
end

function PagedUniGrid:drawSelf()
  if DEBUG_ENABLED then
    GraphicsUtil.setColor(1, 0, 0, 1)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

function PagedUniGrid:getElementAt(row, column)
  return self.pages[self.currentPage]:getElementAt(row, column)
end

return PagedUniGrid

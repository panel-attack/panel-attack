local UiElement = require("ui.UIElement")
local class = require("class")
local directsFocus = require("ui.FocusDirector")
local input = require("inputManager")

-- create a new cursor that can navigate on the specified grid
-- grid: the target grid that is navigated on
-- translateSubGrids: if true, grids inside the target grid will directly be navigated into, treating them as if their elemens were part of the main grid
-- activeArea: specify an area on the grid for movement, the cursor cannot move outside
-- selectedGridPos: the starting position for the cursor on the grid
local GridCursor = class(function(self, options)
  directsFocus(self)

  self.target = options.grid
  self.translateSubGrids = options.translateSubGrids or false
  self.activeArea = options.activeArea or {x1 = 1, y1 = 1, x2 = self.target.gridWidth, y2 = self.target.gridHeight}
  self.selectedGridPos = options.startPosition or {x = 1, y = 1}
  self.selectedGridElement = self.target.grid[self.selectedGridPos.y][self.selectedGridPos.x]

  self.playerNumber = options.playerNumber or 1
  self.image = themes[config.theme].images.IMG_char_sel_cursors[self.playerNumber]
  self.leftQuad = themes[config.theme].images.IMG_char_sel_cursor_halves.left[self.playerNumber]
  self.rightQuad = themes[config.theme].images.IMG_char_sel_cursor_halves.right[self.playerNumber]
  self.imageWidth, self.imageHeight = self.image[1]:getDimensions()
  self.imageScale = self.target.unitSize / self.imageHeight

  self.blinkFrequency = options.blinkFrequency or 8
  self.rapidBlinking = options.rapidBlinking or false
  self.frameClock = 0

  self.TYPE = "GridCursor"
end, UiElement)

GridCursor.directions = {up = {x = 0, y = -1}, down = {x = 0, y = 1}, left = {x = -1, y = 0}, right = {x = 1, y = 0}}

function GridCursor:updatePosition(x, y)
  self.selectedGridPos.x = x
  self.selectedGridPos.y = y
  self.selectedGridElement = self:getElementAt(y, x)
end

function GridCursor:getElementAt(y, x)
  local element = self.target.grid[y][x]
  if self.translateSubGrids and element.content.TYPE == "Grid" or element.content.TYPE == "PagedUniGrid" then
    if element.content.TYPE == "Grid" and element.content.unitSize == self.target.unitSize then
      local relativeOffsetX = (x - element.gridOriginX) + 1
      local relativeOffsetY = (y - element.gridOriginY) + 1
      return element.content.grid[relativeOffsetY][relativeOffsetX]
    elseif element.content.TYPE == "PagedUniGrid" and element.content.pages[element.content.currentPage].unitSize == self.target.unitSize then
      local relativeOffsetX = (x - element.gridOriginX) + 1
      local relativeOffsetY = (y - element.gridOriginY) + 1
      return element.content.pages[element.content.currentPage].grid[relativeOffsetY][relativeOffsetX]
    end
  end
  return element
end

-- TODO: implement navigation into subgrids when translateSubGrids is on
function GridCursor:move(direction)
  local nextGridElement
  if direction.x ~= 0 then
    local newX = wrap(self.activeArea.x1, self.selectedGridPos.x + direction.x, self.activeArea.x2)
    nextGridElement = self:getElementAt(self.selectedGridPos.y, newX)
    -- look for a different UiElement until we wrapped back to our position before the move
    while not nextGridElement or (self.selectedGridElement == nextGridElement and newX ~= self.selectedGridPos.x) do
      newX = wrap(self.activeArea.x1, newX + direction.x, self.activeArea.x2)
      nextGridElement = self:getElementAt(self.selectedGridPos.y, newX)
    end
    if nextGridElement == self.selectedGridElement then
      -- this must be the only UiElement in this row, abort here
    else
      -- new UiElement was found!
      self:updatePosition(newX, self.selectedGridPos.y)
    end
  else
    local newY = wrap(self.activeArea.y1, self.selectedGridPos.y + direction.y, self.activeArea.y2)
    nextGridElement = self:getElementAt(newY,self.selectedGridPos.x)
    -- look for a different UiElement until we wrapped back to our position before the move
    while not nextGridElement or (self.selectedGridElement == nextGridElement and newY ~= self.selectedGridPos.y) do
      newY = wrap(self.activeArea.y1, newY + direction.y, self.activeArea.y2)
      nextGridElement = self:getElementAt(newY,self.selectedGridPos.x)
    end
    if nextGridElement == self.selectedGridElement then
      -- this must be the only UiElement in this row, abort here
    else
      -- new UiElement was found!
      self:updatePosition(self.selectedGridPos.x, newY)
    end
  end
end

function GridCursor:toggleRapidBlinking()
  self.rapidBlinking = not self.rapidBlinking
end

function GridCursor:draw()
  self.frameClock = self.frameClock + 1
  local cursorFrame = math.floor((((self.frameClock + self.playerNumber * self.blinkFrequency) / self.blinkFrequency) % 2)) + 1

  local image = self.image[cursorFrame]
  local x, y = self.selectedGridElement:getScreenPos()
  menu_drawq(image, self.leftQuad[cursorFrame], x - 7, y - 7, 0, self.imageScale, self.imageScale)
  menu_drawq(image, self.rightQuad[cursorFrame], x + self.selectedGridElement.width + 7 - self.imageWidth * self.imageScale / 2, y - 7, 0, self.imageScale, self.imageScale)
end

function GridCursor:receiveInputs()
  if self.focused then
    self.focused:receiveInputs()
  elseif input.isDown["MenuEsc"] or input.isDown["Swap2"] then
    self:escapeCallback()
  elseif input.isDown["Left"] then
    play_optional_sfx(themes[config.theme].sounds.menu_move)
    self:move(GridCursor.directions.left)
  elseif input.isDown["Right"] then
    play_optional_sfx(themes[config.theme].sounds.menu_move)
    self:move(GridCursor.directions.right)
  elseif input.isDown["Up"] then
    play_optional_sfx(themes[config.theme].sounds.menu_move)
    self:move(GridCursor.directions.up)
  elseif input.isDown["Down"] then
    play_optional_sfx(themes[config.theme].sounds.menu_move)
    self:move(GridCursor.directions.down)
  elseif input.isDown["Swap1"] then
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    self.selectedGridElement:onSelect(self)
  end
end

function GridCursor:escapeCallback()
  error("Need to implement a callback for escape")
end

return GridCursor

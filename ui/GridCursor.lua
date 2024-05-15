local UiElement = require("ui.UIElement")
local class = require("class")
local directsFocus = require("ui.FocusDirector")
local input = require("inputManager")
local consts = require("consts")
local GraphicsUtil = require("graphics_util")

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

  self.player = options.player
  self.player.cursor = self
  self.frameImages = options.frameImages or themes[config.theme].images.IMG_char_sel_cursors[self.player.playerNumber]
  self.imageWidth, self.imageHeight = self.frameImages[1]:getDimensions()
  self.quads = {}
  self.quads.left = GraphicsUtil:newRecycledQuad(0, 0, self.imageWidth / 2, self.imageHeight, self.imageWidth, self.imageHeight)
  self.quads.right = GraphicsUtil:newRecycledQuad(self.imageWidth / 2, 0, self.imageWidth / 2, self.imageHeight, self.imageWidth, self.imageHeight)

  self.imageScale = self.target.unitSize / self.imageHeight

  self.blinkFrequency = options.blinkFrequency or 8
  self.rapidBlinking = options.rapidBlinking or false
  self.drawClock = 0

  self.TYPE = "GridCursor"
end, UiElement)

GridCursor.directions = {up = {x = 0, y = -1}, down = {x = 0, y = 1}, left = {x = -1, y = 0}, right = {x = 1, y = 0}}

function GridCursor:updatePosition(x, y)
  self.selectedGridPos.x = x
  self.selectedGridPos.y = y
end

function GridCursor:getElementAt(y, x)
  local element = self.target:getElementAt(y, x)
  if self.translateSubGrids and element.content and element.content.TYPE == "Grid" or element.content.TYPE == "PagedUniGrid" then
    if element.content.TYPE == "Grid" and element.content.unitSize == self.target.unitSize then
      local relativeOffsetX = (x - element.gridOriginX) + 1
      local relativeOffsetY = (y - element.gridOriginY) + 1
      return element.content:getElementAt(relativeOffsetY, relativeOffsetX)
    elseif element.content.TYPE == "PagedUniGrid" and element.content.pages[element.content.currentPage].unitSize == self.target.unitSize then
      local relativeOffsetX = (x - element.gridOriginX) + 1
      local relativeOffsetY = (y - element.gridOriginY) + 1
      return element.content:getElementAt(relativeOffsetY, relativeOffsetX)
    end
  end
  return element
end

function GridCursor:move(direction)
  local selectedGridElement = self:getElementAt(self.selectedGridPos.y, self.selectedGridPos.x)
  local nextGridElement
  local acceptPlaceholders = false
  if direction.x ~= 0 then
    local newX = wrap(self.activeArea.x1, self.selectedGridPos.x + direction.x, self.activeArea.x2)
    nextGridElement = self:getElementAt(self.selectedGridPos.y, newX)
    -- look for a different UiElement until we wrapped back to our position before the move
    while (nextGridElement.content.TYPE == "GridPlaceholder" and not acceptPlaceholders) or (selectedGridElement == nextGridElement and newX ~= self.selectedGridPos.x) do
      newX = wrap(self.activeArea.x1, newX + direction.x, self.activeArea.x2)
      nextGridElement = self:getElementAt(self.selectedGridPos.y, newX)
      if self.selectedGridPos.x == newX then
        -- if we get here that means we're looping in an empty character row
        -- accept placeholders so the cursor can get back into legal area
        acceptPlaceholders = true
        newX = wrap(self.activeArea.x1, newX + direction.x, self.activeArea.x2)
        nextGridElement = self:getElementAt(self.selectedGridPos.y, newX)
      end
    end
    if nextGridElement == selectedGridElement then
      -- this must be the only UiElement in this row, abort here
    else
      -- new UiElement was found!
      self:updatePosition(newX, self.selectedGridPos.y)
    end
  else
    local newY = wrap(self.activeArea.y1, self.selectedGridPos.y + direction.y, self.activeArea.y2)
    nextGridElement = self:getElementAt(newY,self.selectedGridPos.x)
    -- look for a different UiElement until we wrapped back to our position before the move
    while (nextGridElement.content.TYPE == "GridPlaceholder" and not acceptPlaceholders) or (selectedGridElement == nextGridElement and newY ~= self.selectedGridPos.y) do
      newY = wrap(self.activeArea.y1, newY + direction.y, self.activeArea.y2)
      nextGridElement = self:getElementAt(newY,self.selectedGridPos.x)
      if self.selectedGridPos.y == newY then
        -- if we get here that means we're looping in an empty character row
        -- accept placeholders so the cursor can get back into legal area
        acceptPlaceholders = true
        newY = wrap(self.activeArea.y1, newY + direction.y, self.activeArea.y2)
        nextGridElement = self:getElementAt(newY,self.selectedGridPos.x)
        break
      end
    end
    if nextGridElement == selectedGridElement then
      -- this must be the only UiElement in this row, abort here
    else
      -- new UiElement was found!
      self:updatePosition(self.selectedGridPos.x, newY)
    end
  end
end

function GridCursor:setRapidBlinking(rapid)
  self.rapidBlinking = rapid
end

function GridCursor:drawSelf()
  self.drawClock = self.drawClock + 1
  local cursorFrame
  local drawThisFrame
  if self.rapidBlinking then
    cursorFrame = 1
    drawThisFrame  = (math.floor(self.drawClock / self.blinkFrequency) + self.player.playerNumber) % 2 + 1 == self.player.playerNumber
  else
    cursorFrame = (math.floor(self.drawClock / 8) + self.player.playerNumber) % 2 + 1
    drawThisFrame = true
  end

  local image = self.frameImages[cursorFrame]
  local element = self:getElementAt(self.selectedGridPos.y, self.selectedGridPos.x)
  local x, y = element:getScreenPos()
  if drawThisFrame then
    GraphicsUtil.drawQuad(image, self.quads.left, x - 7, y - 7, 0, self.imageScale, self.imageScale)
    GraphicsUtil.drawQuad(image, self.quads.right, x + element.width + 7 - self.imageWidth * self.imageScale / 2, y - 7, 0, self.imageScale, self.imageScale)
  end
end

function GridCursor:receiveInputs(inputs, dt)
  if self.focused then
    self.focused:receiveInputs(inputs, dt, self.player)
  elseif inputs.isDown.Swap2 then
    self:escapeCallback()
  elseif inputs:isPressedWithRepeat("Left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    SoundController:playSfx(themes[config.theme].sounds.menu_move)
    self:move(GridCursor.directions.left)
  elseif inputs:isPressedWithRepeat("Right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    SoundController:playSfx(themes[config.theme].sounds.menu_move)
    self:move(GridCursor.directions.right)
  elseif inputs:isPressedWithRepeat("Up", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    SoundController:playSfx(themes[config.theme].sounds.menu_move)
    self:move(GridCursor.directions.up)
  elseif inputs:isPressedWithRepeat("Down", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    SoundController:playSfx(themes[config.theme].sounds.menu_move)
    self:move(GridCursor.directions.down)
  elseif inputs.isDown.Swap1 or inputs.isDown.Start then
    SoundController:playSfx(themes[config.theme].sounds.menu_validate)
    self:getElementAt(self.selectedGridPos.y, self.selectedGridPos.x):onSelect(self)
  elseif inputs.isDown.Raise1 then
    if self.raise1Callback then
      self:raise1Callback()
    end
  elseif inputs.isDown.Raise2 then
    if self.raise2Callback then
      self:raise2Callback()
    end
  end
end

function GridCursor:escapeCallback()
  error("Need to implement a callback for escape")
end

return GridCursor

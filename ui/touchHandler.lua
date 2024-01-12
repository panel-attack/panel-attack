local input = require("inputManager")
-- handles all touch interactions
-- all elements that implement touch interactions must register themselves with the touch handler on construction

local touchHandler = {
  touchableElements = {},
  touchedElement = nil,
  holdTimer = 0,
  draggedThisFrame = false,
}

function touchHandler:getTouchedElement(x, y, elements)
  -- don't use the index of the elements table cause we're recursing into children to tiebreak overlapping hitboxes
  for _, element in pairs(elements) do
    if self.touchableElements[element.id] and element:inBounds(x, y) and element.isEnabled then
      return self:getTouchedElement(x, y, element.children) or element
    end
  end
end

function touchHandler:touch(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  -- prevent multitouch
  if not self.touchedElement then
    self.touchedElement = self:getTouchedElement(canvasX, canvasY, self.touchableElements)
    if self.touchedElement and self.touchedElement.onTouch then
      self.touchedElement:onTouch(canvasX, canvasY)
    end
  end
end

function touchHandler:drag(x, y)
  if self.touchedElement then
    self.draggedThisFrame = true
    if self.touchedElement.onDrag then
      local canvasX, canvasY = GAME:transform_coordinates(x, y)
      self.touchedElement:onDrag(canvasX, canvasY)
    end
  end
end

function touchHandler:release(x, y)
  if self.touchedElement then
    if self.touchedElement.onRelease then
      local canvasX, canvasY = GAME:transform_coordinates(x, y)
      self.touchedElement:onRelease(canvasX, canvasY, self.holdTimer)
    end
    self.touchedElement = nil
    self.holdTimer = 0
    self.draggedThisFrame = false
  end
end

function touchHandler:update(dt)
  if self.touchedElement then
    if not self.draggedThisFrame then
      if self.touchedElement.onHold and self.touchedElement:inBounds(input.mouse.x, input.mouse.y) then
        self.holdTimer = self.holdTimer + dt
        self.touchedElement:onHold(self.holdTimer)
      end
    else
      self.draggedThisFrame = false
    end
  end
end

function touchHandler:unregisterTree(uiElement)
  for i, child in ipairs(uiElement.children) do
    if self.touchableElements[child.id] then
      self.touchableElements[child.id] = nil
    end
    self:unregisterTree(child)
  end
end

function touchHandler:registerTree(uiElement)
  for i, child in ipairs(uiElement.children) do
    if child.canBeTouched then
      self.touchableElements[child.id] = child
    end
    self:registerTree(child)
  end
end

return touchHandler

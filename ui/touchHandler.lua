-- handles all touch interactions
-- all elements that implement touch interactions must register themselves with the touch handler on construction

local touchHandler = {
  touchableElements = {},
  touchedElement = nil
}

function touchHandler:touch(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  for id, element in pairs(self.touchableElements) do
    if element:isSelected(canvasX, canvasY) and element.isEnabled then
      self.touchedElement = element
      if self.touchedElement.onTouch then
        self.touchedElement:onTouch(canvasX, canvasY)
      end
    end
  end
end

function touchHandler:drag(x, y)
  if self.touchedElement and self.touchedElement.onDrag then
    local canvasX, canvasY = GAME:transform_coordinates(x, y)
    self.touchedElement:onDrag(canvasX, canvasY)
  end
end

function touchHandler:release(x, y)
  if self.touchedElement then
    local canvasX, canvasY = GAME:transform_coordinates(x, y)
    if self.touchedElement.onRelease then
      self.touchedElement:onRelease(canvasX, canvasY)
    end
    self.touchedElement = nil
  end
end

return touchHandler

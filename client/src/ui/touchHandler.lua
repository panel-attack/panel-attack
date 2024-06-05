local input = require("common.lib.inputManager")
-- handles all touch interactions
-- all elements that implement touch interactions must register themselves with the touch handler on construction

local touchHandler = {
  touchedElement = nil,
  holdTimer = 0,
  draggedThisFrame = false,
}

function touchHandler:touch(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  local activeScene = GAME.navigationStack:getActiveScene()
  -- if there is no active scene that implies an on-going scene switch, no interactions should be possible
  if activeScene then
    -- prevent multitouch
    if not self.touchedElement then
      self.touchedElement = activeScene.uiRoot:getTouchedElement(canvasX, canvasY)
      if self.touchedElement and self.touchedElement.onTouch then
        self.touchedElement:onTouch(canvasX, canvasY)
      end
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

return touchHandler

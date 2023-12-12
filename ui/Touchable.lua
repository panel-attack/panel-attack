local touchHandler = require("ui.touchHandler")

-- Touchable is a set of functions that is can be applied to any uiElement by calling the canBeTouched function on it

local function inBounds(uiElement, x, y)
  local screenX, screenY = uiElement:getScreenPos()
  return x > screenX and x < screenX + uiElement.width and y > screenY and y < screenY + uiElement.height
end

local function onVisibilityChanged(uiElement)
  if uiElement.isVisible then
    touchHandler.touchableElements[uiElement.id] = uiElement
  else
    touchHandler.touchableElements[uiElement.id] = nil
  end
end

local function canBeTouched(uiElement)
  uiElement.inBounds = inBounds
  if uiElement.onVisibilityChanged then
    local ogFunc = uiElement.onVisibilityChanged
    uiElement.onVisibilityChanged = function (uiElement)
      onVisibilityChanged(uiElement)
      ogFunc(uiElement)
    end
  else
    uiElement.onVisibilityChanged = onVisibilityChanged
  end
  uiElement:onVisibilityChanged()

  -- any touchable element is expected to implement at least one touch callback for the touch handler
  assert(uiElement.onTouch
    --or uiElement.onHold
    or uiElement.onDrag
    or uiElement.onRelease
  )
end

return canBeTouched
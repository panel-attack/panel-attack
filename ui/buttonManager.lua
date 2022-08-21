--@module button_manager
local buttonManager = {
  buttons = {}
}

local selectedButton = nil

function buttonManager.update()
  if selectedButton and love.mouse.isDown(1) then
    selectedButton.onMousePressed()
  end
end

function buttonManager.draw()
  for id, button in pairs(buttonManager.buttons) do
    button:draw()
  end
end

function buttonManager.mousePressed(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  for id, button in pairs(buttonManager.buttons) do
    if button:isSelected(canvasX, canvasY) then
      button.onMouseDown()
      selectedButton = button
      break
    end
  end
end

function buttonManager.mouseReleased(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  if selectedButton then
    selectedButton.onMouseUp()
    if selectedButton:isSelected(canvasX, canvasY) then
      selectedButton.onClick()
    end
    selectedButton = nil
  end
end

return buttonManager
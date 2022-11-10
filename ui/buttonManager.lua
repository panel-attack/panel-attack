--@module button_manager
-- recieves love events and passes them to the correct button object
local buttonManager = {
  buttons = {}
}

local selectedButton = nil

function buttonManager.printButtonCount(self)
print("Current button count: "..#self.buttons)
end

function buttonManager.update()
  -- there is no event for continous mouse pressed, so simulating it here
  if selectedButton and love.mouse.isDown(1) then
    selectedButton.onMousePressed()
  end
end

function buttonManager.mousePressed(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  for id, button in pairs(buttonManager.buttons) do
    if button.isEnabled and button:isSelected(canvasX, canvasY) then
      button.onMouseDown()
      selectedButton = button
      break
    end
  end
end

function buttonManager.mouseReleased(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  if selectedButton and selectedButton.isEnabled then
    selectedButton.onMouseUp()
    if selectedButton:isSelected(canvasX, canvasY) then
      selectedButton.onClick()
    end
    selectedButton = nil
  end
end

return buttonManager
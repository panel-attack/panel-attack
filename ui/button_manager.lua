--@module button_manager
local button_manager = {}

local buttons = {}
local next_button_id = 0
local selected_button = nil

function button_manager.add_button(button)
  button.id = next_button_id
  buttons[button.id] = button
  next_button_id = next_button_id + 1
end

function button_manager.remove_button(button)
  buttons[button.id] = nil
end

function button_manager.update()
  if selected_button and love.mouse.isDown(1) then
    selected_button.onMousePressed()
  end
end

function button_manager.draw()
  for id, button in pairs(buttons) do
    if button.is_visible then
      button:draw()
    end
  end
end

function button_manager.mousePressed(x, y)
  for id, button in pairs(buttons) do
    if button.is_visible and button:isSelected(x, y) then
      button.onMouseDown()
      selected_button = button
      break
    end
  end
end

function button_manager.mouseReleased(x, y)
  if selected_button then
    selected_button.onMouseUp()
    if selected_button:isSelected(x, y) then
      selected_button.onClick()
    end
    selected_button = nil
  end
end

return button_manager
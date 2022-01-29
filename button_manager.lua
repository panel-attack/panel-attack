--@module button_manager
local button_manager = {}

local buttons = {}
local next_button_id = 0

function button_manager.add_button(button)
  button.id = next_button_id
  buttons[button.id] = button
  next_button_id = next_button_id + 1
end

function button_manager.remove_button(button)
  buttons[button.id] = nil
end

function button_manager.draw()
  for id, button in pairs(buttons) do
    button:draw()
  end
end

function button_manager.mousepressed(x, y)
  for id, button in pairs(buttons) do
    if button:isSelected(x, y) then
      button.onClick()
    end
  end
end

return button_manager
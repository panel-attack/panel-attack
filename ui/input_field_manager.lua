local input = require("inputManager")

--@module input_field_manager
local input_field_manager = {}

local input_fields = {}
local next_input_field_id = 0
local selected_input_field = nil

function input_field_manager.add_input_field(input_field)
  input_field.id = next_input_field_id
  input_fields[input_field.id] = input_field
  next_input_field_id = next_input_field_id + 1
end

function input_field_manager.remove_input_field(input_field)
  input_fields[input_field.id] = nil
end

function input_field_manager.update()
  if selected_input_field and love.mouse.isDown(1) then
    selected_input_field.onMousePressed()
  end

  if input:isPressedWithRepeat("backspace", .25, .1) and selected_input_field then
    selected_input_field:onBackspace()
  end
  
  if input:isPressedWithRepeat("left", .25, .1) and selected_input_field then
    selected_input_field:onMoveCursor(-1)
  end
  
  if input:isPressedWithRepeat("right", .25, .1) and selected_input_field then
    selected_input_field:onMoveCursor(1)
  end
end

function input_field_manager.draw()
  for id, input_field in pairs(input_fields) do
    if input_field.is_visible then
      input_field:draw()
    end
  end
end

function input_field_manager.mousePressed(x, y)
  if selected_input_field then
    selected_input_field.has_focus = false
  end
  selected_input_field = nil
  love.keyboard.setTextInput(false)

  for id, input_field in pairs(input_fields) do
    if input_field.is_visible and input_field:isSelected(x, y) then
      input_field:setFocus(x, y)
      love.keyboard.setTextInput(true)
      selected_input_field = input_field
      break
    end
  end
end

function input_field_manager.mouseReleased(x, y)
  --[[
  if selected_input_field then
    selected_input_field.onMouseUp()
    if selected_input_field:isSelected(x, y) then
      selected_input_field.onClick()
    end
    selected_input_field = nil
  end
  --]]
end

function input_field_manager.textInput(t)
  if selected_input_field then
    selected_input_field:textInput(t)
  end
end

return input_field_manager
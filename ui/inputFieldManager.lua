local input = require("inputManager")

--@module inputFieldManager
local inputFieldManager = {
  inputFields = {}
}

local selectedInputField = nil

function inputFieldManager.update()
  if not selectedInputField or not selectedInputField.isEnabled then
    return
  end

  if input:isPressedWithRepeat("backspace", .25, .1)then
    selectedInputField:onBackspace()
  end
  
  if input:isPressedWithRepeat("left", .25, .1) then
    selectedInputField:onMoveCursor(-1)
  end
  
  if input:isPressedWithRepeat("right", .25, .1) then
    selectedInputField:onMoveCursor(1)
  end
end

function inputFieldManager.draw()
  for id, inputField in pairs(inputFieldManager.inputFields) do
    inputField:draw()
  end
end

function inputFieldManager.mousePressed(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  if selectedInputField then
    selectedInputField.hasFocus = false
  end
  selectedInputField = nil
  love.keyboard.setTextInput(false)

  for id, inputField in pairs(inputFieldManager.inputFields) do
    if inputField.isEnabled and inputField:isSelected(canvasX, canvasY) then
      inputField:setFocus(x, y)
      love.keyboard.setTextInput(true)
      selectedInputField = inputField
      break
    end
  end
end

function inputFieldManager.textInput(t)
  if selectedInputField and selectedInputField.isEnabled then
    selectedInputField:textInput(t)
  end
end

return inputFieldManager
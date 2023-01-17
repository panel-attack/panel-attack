local input = require("inputManager")
local consts = require("consts")

--@module inputFieldManager
-- recieves love events and passes them to the correct button object
local inputFieldManager = {
  inputFields = {},
  selectedInputField = nil
}

function inputFieldManager.update()
  if not inputFieldManager.selectedInputField or not inputFieldManager.selectedInputField.isEnabled then
    return
  end

  if input:isPressedWithRepeat("backspace", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD)then
    inputFieldManager.selectedInputField:onBackspace()
  end
  
  if input:isPressedWithRepeat("left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    inputFieldManager.selectedInputField:onMoveCursor(-1)
  end
  
  if input:isPressedWithRepeat("right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    inputFieldManager.selectedInputField:onMoveCursor(1)
  end
end

function inputFieldManager.mousePressed(x, y)
  local canvasX, canvasY = GAME:transform_coordinates(x, y)
  if inputFieldManager.selectedInputField then
    inputFieldManager.selectedInputField:unfocus()
  end

  for id, inputField in pairs(inputFieldManager.inputFields) do
    if inputField.isEnabled and inputField:isSelected(canvasX, canvasY) then
      inputField:setFocus(x, y)
      inputFieldManager.selectedInputField = inputField
      break
    end
  end
end

function inputFieldManager.textInput(t)
  if inputFieldManager.selectedInputField and inputFieldManager.selectedInputField.isEnabled then
    inputFieldManager.selectedInputField:textInput(t)
  end
end

return inputFieldManager
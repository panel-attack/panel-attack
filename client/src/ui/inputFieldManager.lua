local input = require("common.lib.inputManager")

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

  if input.allKeys:isPressedWithRepeat("backspace") then
    inputFieldManager.selectedInputField:onBackspace()
  end
  
  if input.allKeys:isPressedWithRepeat("Left") then
    inputFieldManager.selectedInputField:onMoveCursor(-1)
  end
  
  if input.allKeys:isPressedWithRepeat("Right") then
    inputFieldManager.selectedInputField:onMoveCursor(1)
  end
end

function inputFieldManager.textInput(t)
  if inputFieldManager.selectedInputField and inputFieldManager.selectedInputField.isEnabled then
    inputFieldManager.selectedInputField:textInput(t)
  end
end

return inputFieldManager
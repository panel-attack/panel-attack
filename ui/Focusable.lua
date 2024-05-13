-- use in tandem with FocusDirector.lua

local function canBeFocused(uiElement)
  uiElement.isFocusable = true
  uiElement.hasFocus = false
  if uiElement.receiveInputs == nil then
    uiElement.receiveInputs = function(inputs)
      error("Focusable UIElement of type " .. uiElement.TYPE .. " doesn't implement input interpretation")
    end
  end

  -- this function is implemented on the FocusDirector's side cause it is expected to know about what it is focusing
  -- but the focused element probably does not know what is focusing it
  -- table.yieldFocus = function(focusDirector, table)
  --   focusDirector.focused = nil
  --   table.hasFocus = false
  -- end
end

return canBeFocused
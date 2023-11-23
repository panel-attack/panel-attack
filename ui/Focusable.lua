-- use in tandem with FocusDirector.lua

local function canBeFocused(table)
  table.isFocusable = true
  table.hasFocus = false
  table.setFocus = function()
    table.hasFocus = true
  end
  table.isFocussed = function()
    return table.hasFocus
  end
  if table.receiveInputs == nil then
    table.receiveInputs = function()
      error("Focusable UIElement of type " .. table.TYPE .. " doesn't implement input interpretation")
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
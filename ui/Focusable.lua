-- use in tandem with FocusDirector.lua

local function canBeFocused(table)
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
  -- this function is implemented parent side cause the parent is expected to know about the children
  -- but not necessarily vice versa
  -- table.yieldFocus = function(parent, table)
  --   parent.focused = nil
  --   table.hasFocus = false
  -- end
end

return canBeFocused
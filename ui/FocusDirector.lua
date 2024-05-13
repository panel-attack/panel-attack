-- use in tandem with Focusable.lua

local function directsFocus(uiElement)
    uiElement.focused = nil
    uiElement.setFocus = function(table, focusable)
      if table.focused then
        table.focused.hasFocus = false
      end
      table.focused = focusable
      if focusable then
        focusable.hasFocus = true
        focusable.yieldFocus = function()
          focusable.hasFocus = false
          table.focused = nil
        end
      end
    end
  end
  
  return directsFocus
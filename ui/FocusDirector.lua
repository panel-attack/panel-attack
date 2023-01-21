-- use in tandem with Focusable.lua

local function directsFocus(table)
  table.focused = nil
  table.setFocus = function(table, child)
    if table.focused then
      table.focused.hasFocus = false
    end
    table.focused = child
    if child then
      child.hasFocus = true
      child.yieldFocus = function()
        child.hasFocus = false
        table.focused = nil
      end
    end
  end
end

return directsFocus
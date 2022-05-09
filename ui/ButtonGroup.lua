local class = require("class")
local util = require("util")
local button_manager = require("ui.button_manager")

local function setState(self, i)
  self.buttons[self.selected_index].color = {.3, .3, .3, .7}
  self.selected_index = i
  self.buttons[i].color = {.5, .5, 1, .7}
  self.value = self.values[i]
end

local function genButtonGroupFn(self, i, onClick)
  return function()
    setState(self, i)
    onClick()
    self.onChange()
  end
end

local function setPos(self, x, y)
  self.x = x
  self.y = y
  for i, button in ipairs(self.buttons) do
    button.x = i == 1 and x or (self.buttons[i - 1].x + self.buttons[i - 1].width + 10)
    button.y = y
  end
end

local function setActiveButton(self, selected_index)
  local new_index = util.clamp(1, selected_index, #self.buttons)
  self.buttons[new_index].onClick()
end

--@module Button
local ButtonGroup = class(
  function(self, buttons, values, options)
    self.buttons = buttons
    self.values = values
    self.value = nil -- set in setActiveButton
    self.onChange = options.onChange or function() end
    self.selected_index = options.selected_index or 1
    self.x = options.x or 0
    self.y = options.y or 0
    setPos(self, self.x, self.y)
    setState(self, self.selected_index)
    
    for i, button in ipairs(self.buttons) do
      button.onClick = genButtonGroupFn(self, i, button.onClick)
    end
    self.TYPE = "ButtonGroup"
  end
)

ButtonGroup.setPos = setPos
ButtonGroup.setActiveButton = setActiveButton

function ButtonGroup:setVisibility(is_visible)
  for i, button in ipairs(self.buttons) do
    button.is_visible = is_visible
  end
end

return ButtonGroup
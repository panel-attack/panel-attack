local class = require("class")
local UIElement = require("ui.UIElement")
local util = require("util")

local BUTTON_PADDING = 5

--@module Button
local function setState(self, i)
  self.buttons[self.selectedIndex].color = {.3, .3, .3, .7}
  self.selectedIndex = i
  self.buttons[i].color = {.5, .5, 1, .7}
  self.value = self.values[i]
end

local function genButtonGroupFn(self, i, onClick)
  return function()
    setState(self, i)
    onClick()
    self.onChange(self.value)
  end
end

local function setButtons(self, buttons, values, selectedIndex)
  if self.buttons then
    for i, button in ipairs(self.buttons) do
      button:detach()
    end
  end
  
  self.selectedIndex = selectedIndex
  self.values = values
  self.buttons = buttons
  
  for i, button in ipairs(buttons) do
    if i > 1 then 
       button.x = self.buttons[i - 1].x + self.buttons[i - 1].width + BUTTON_PADDING
    end
    button.onClick = genButtonGroupFn(self, i, button.onClick)
    self:addChild(button)
  end
  self.buttons[self.selectedIndex].color = {.5, .5, 1, .7}
  self.value = self.values[self.selectedIndex]
end

local function setActiveButton(self, selected_index)
  local new_index = util.clamp(1, selected_index, #self.buttons)
  self.buttons[new_index].onClick()
end

local ButtonGroup = class(
  function(self, options)
    self.onChange = options.onChange or function() end
    self.selectedIndex = options.selectedIndex or 1
    
    setButtons(self, options.buttons, options.values, self.selectedIndex)
    
    self.TYPE = "ButtonGroup"
  end,
  UIElement
)

ButtonGroup.setButtons = setButtons
ButtonGroup.setActiveButton = setActiveButton

return ButtonGroup
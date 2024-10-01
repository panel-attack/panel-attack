local class = require("common.lib.class")
local UIElement = require("client.src.ui.UIElement")
local util = require("common.lib.util")

local BUTTON_PADDING = 5

--@module ButtonGroup
-- UIElement representing a set of buttons which share state (think radio buttons)

-- changes state for the button group
-- updates the color of the selected button
-- updates the value to the selected button's value
local function setState(self, i)
  self.buttons[self.selectedIndex].backgroundColor = {.3, .3, .3, .7}
  self.selectedIndex = i
  self.buttons[i].backgroundColor = {.5, .5, 1, .7}
  self.value = self.values[i]
end

-- forced override for each of the button's onClick function
-- this allows buttons to have individual custom behaviour while also triggering the global state change
local function genButtonGroupFn(self, i, onClick)
  return function(selfElement, inputSource, holdTime)
    setState(self, i)
    onClick(selfElement, inputSource, holdTime)
    self:onChange(self.value)
  end
end

-- setup the buttons for use within the button group
local function setButtons(self, buttons, values, selectedIndex)
  if self.buttons then
    for i, button in ipairs(self.buttons) do
      button:detach()
    end
  end
  
  self.selectedIndex = selectedIndex
  self.values = values
  self.buttons = buttons
  
  local overallWidth = 0
  local overallHeight = 0
  for i, button in ipairs(buttons) do
    overallWidth = overallWidth + button.width
    if i > 1 then 
       button.x = self.buttons[i - 1].x + self.buttons[i - 1].width + BUTTON_PADDING
       overallWidth = overallWidth + BUTTON_PADDING
    end
    button.onClick = genButtonGroupFn(self, i, button.onClick)
    self:addChild(button)
    overallHeight = math.max(overallHeight, button.height)
  end
  self.width = overallWidth
  self.height = overallHeight
  self.buttons[self.selectedIndex].backgroundColor = {.5, .5, 1, .7}
  self.value = self.values[self.selectedIndex]
end

local function setActiveButton(self, selectedIndex)
  local newIndex = util.bound(1, selectedIndex, #self.buttons)
  if self.selectedIndex ~= newIndex then
    self.buttons[newIndex]:onClick(nil, 0)
  end
end

local ButtonGroup = class(
  function(self, options)
    self.selectedIndex = options.selectedIndex or 1

    self.onChange = options.onChange or function() end
    
    setButtons(self, options.buttons, options.values, self.selectedIndex)
    
    self.TYPE = "ButtonGroup"
  end,
  UIElement
)

function ButtonGroup:receiveInputs(input)
  if input:isPressedWithRepeat("Left") then
    self:setActiveButton(self.selectedIndex - 1)
  elseif input:isPressedWithRepeat("Right") then
    self:setActiveButton(self.selectedIndex + 1)
  end
end

ButtonGroup.setButtons = setButtons
ButtonGroup.setActiveButton = setActiveButton

return ButtonGroup
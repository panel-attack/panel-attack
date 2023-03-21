local class = require("class")
local util = require("util")
local UIElement = require("ui.UIElement")
local Button = require("ui.Button")

local BUTTON_PADDING = 5

local function setLabels(self, labels, values, selectedIndex)
  if self.labels and #self.labels > 0 then
    self.labels[self.selectedIndex]:detach()
  end
  
  self.selectedIndex = selectedIndex
  self.values = values
  self.labels = labels
  for _, label in ipairs(labels) do
    label.x = self.leftButton.width + BUTTON_PADDING
  end
  if #self.labels > 0 then
    self:addChild(self.labels[self.selectedIndex])
    self.labels[self.selectedIndex]:setVisibility(self.isVisible)
    self.value = self.values[self.selectedIndex]
  end
end

local function setState(self, i)
  local new_index = util.bound(1, i, #self.labels)
  if i ~= new_index then
    return
  end

  self.labels[self.selectedIndex]:setVisibility(false)
  self.labels[self.selectedIndex]:detach()
  self.selectedIndex = new_index
  self.value = self.values[new_index]
  self.labels[new_index]:setVisibility(true)
  self:addChild(self.labels[new_index])
  self.rightButton.x = self.leftButton.width + BUTTON_PADDING + self.labels[self.selectedIndex].width + BUTTON_PADDING
  self.onChange(self.value)
end

--@module Stepper
-- UIElement representing a scrolling list of options
local Stepper = class(
  function(self, options)
    self.onChange = options.onChange or function() end
    self.selectedIndex = options.selectedIndex or 1
    
    local navButtonWidth = 25
    self.leftButton = Button({width = navButtonWidth, label = "<", translate = false, onClick = function() setState(self, self.selectedIndex - 1) end})
    self.rightButton = Button({width = navButtonWidth, label = ">", translate = false, onClick = function() setState(self, self.selectedIndex + 1) end})
    self:addChild(self.leftButton)
    self:addChild(self.rightButton)
    
    setLabels(self, options.labels, options.values, self.selectedIndex)
    
    if #self.labels > 0 then
      self.labels[self.selectedIndex]:setVisibility(self.isVisible)
      self.rightButton.x = self.labels[self.selectedIndex].width + 25 + 10
    end

    for i, label in ipairs(self.labels) do
      label:setVisibility(false)
    end

    self.TYPE = "Stepper"
  end,
  UIElement
)

Stepper.setLabels = setLabels
Stepper.setState = setState

function Stepper:updateLabel()
  for i, label in ipairs(self.labels) do
    label:updateLabel()
  end
  UIElement.updateLabel(self)
end

function Stepper:draw()
  if not self.isVisible then
    return
  end

  -- draw children
  UIElement.draw(self)
end

return Stepper
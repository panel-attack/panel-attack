local class = require("class")
local util = require("util")
local UIElement = require("ui.UIElement")
local TextButton = require("ui.TextButton")
local Label = require("ui.Label")

local BUTTON_PADDING = 5

local function setLabels(self, labels, values, selectedIndex)
  self.selectedIndex = selectedIndex
  self.values = values
  self.labels = labels
  for _, label in ipairs(labels) do
    label.x = self.leftButton.width + BUTTON_PADDING
    self:addChild(label)
    label:setVisibility(false)
  end
  if #self.labels > 0 then
    self.labels[self.selectedIndex]:setVisibility(true)
    self.value = self.values[self.selectedIndex]
  end
end

local function setState(self, i)
  local new_index = util.bound(1, i, #self.labels)
  if i ~= new_index then
    return
  end

  self.labels[self.selectedIndex]:setVisibility(false)
  self.selectedIndex = new_index
  self.value = self.values[new_index]
  self.labels[new_index]:setVisibility(true)
  self.onChange(self.value)
end

--@module Stepper
-- UIElement representing a scrolling list of options
local Stepper = class(
  function(self, options)
    self.onChange = options.onChange or function() end
    self.selectedIndex = options.selectedIndex or 1
    
    local navButtonWidth = 25
    self.leftButton = TextButton({width = navButtonWidth, label = Label({text = "<", translate = false}), onClick = function() setState(self, self.selectedIndex - 1) end})
    self.rightButton = TextButton({width = navButtonWidth, label = Label({text = ">", translate = false}), onClick = function() setState(self, self.selectedIndex + 1) end})
    self:addChild(self.leftButton)
    self:addChild(self.rightButton)

    self.color = {.5, .5, 1, .7}
    self.borderColor = {.7, .7, 1, .7}
    
    setLabels(self, options.labels, options.values, self.selectedIndex)
    
    if #self.labels > 0 then
      for i = 1, #self.labels do
        self.rightButton.x = math.max(self.labels[self.selectedIndex].width + 25 + 10, self.rightButton.x)
      end
    end

    self.TYPE = "Stepper"
  end,
  UIElement
)

Stepper.setLabels = setLabels
Stepper.setState = setState

function Stepper:refreshLocalization()
  for i, label in ipairs(self.labels) do
    label:refreshLocalization()
  end
  UIElement.refreshLocalization(self)
end

function Stepper:drawSelf()
  love.graphics.setColor(self.color)
  love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
  love.graphics.setColor(self.borderColor)
  love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
  love.graphics.setColor(1, 1, 1, 1)
end

return Stepper
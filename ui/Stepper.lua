local class = require("class")
local util = require("util")
local button_manager = require("ui.button_manager")
local Button = require("ui.Button")

local function setPos(self, x, y)
  self.x = x
  self.y = y
  for i, label in ipairs(self.labels) do
    label.x = x + 25 + 5
    label.y = y
  end
  self.left_button.x = x
  self.left_button.y = y
  self.right_button.x = x + self.labels[self.selected_index].width + 25 + 10
  self.right_button.y = y
end

local function setState(self, i)
  local new_index = util.clamp(1, i, #self.labels)
  if i ~= new_index then
    return
  end
  
  self.labels[self.selected_index]:setVisibility(false)
  self.selected_index = new_index
  self.value = self.values[new_index]
  self.labels[new_index]:setVisibility(true)
  setPos(self, self.x, self.y)
  self.onChange(self.value)
end

--@module Stepper
local Stepper = class(
  function(self, labels, values, options)
    self.labels = labels
    self.values = values
    self.value = nil -- set in setState
    self.onChange = options.onChange or function() end
    self.selected_index = options.selected_index or 1
    self.x = options.x or 0
    self.y = options.y or 0
    
    self.left_button = Button({width = 25, label = "<", translate = false, onClick = function() setState(self, self.selected_index - 1) end})
    self.right_button = Button({width = 25, label = ">", translate = false, onClick = function() setState(self, self.selected_index + 1) end})
    
    self.labels[self.selected_index]:setVisibility(false)
    self.selected_index = self.selected_index
    self.value = self.values[self.selected_index]
    self.labels[self.selected_index]:setVisibility(true)
    setPos(self, self.x, self.y)
    
    for i, label in ipairs(self.labels) do
      label:setVisibility(false)
    end
    
    self.TYPE = "Stepper"
  end
)

Stepper.setPos = setPos
Stepper.setState = setState

function Stepper:setVisibility(is_visible)
  self.left_button:setVisibility(is_visible)
  self.right_button:setVisibility(is_visible)
  self.labels[self.selected_index]:setVisibility(is_visible)
end

function Stepper:updateLabel()
  for i, label in ipairs(self.labels) do
    label:updateLabel()
  end
end

function Stepper:draw()
  self.labels[self.selected_index]:draw()
end

return Stepper
local class = require("common.lib.class")
local util = require("common.lib.util")
local UIElement = require("client.src.ui.UIElement")
local TextButton = require("client.src.ui.TextButton")
local Label = require("client.src.ui.Label")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local function setLabels(self, labels, values, selectedIndex)
  self.selectedIndex = selectedIndex
  self.values = values
  self.labels = labels
  for _, label in ipairs(labels) do
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
    self.leftButton = TextButton({
      width = navButtonWidth,
      vAlign = "center",
      label = Label({text = "<", translate = false}),
      onClick = function(selfElement, inputSource, holdTime)
        setState(self, self.selectedIndex - 1)
      end
    })
    self.rightButton = TextButton({
      width = navButtonWidth,
      vAlign = "center",
      label = Label({text = ">", translate = false}),
      onClick = function(selfElement, inputSource, holdTime)
        setState(self, self.selectedIndex + 1)
      end
    })
    self:addChild(self.leftButton)
    self:addChild(self.rightButton)

    self.color = {.5, .5, 1, .7}
    self.borderColor = {.7, .7, 1, .7}

    if #options.labels > 0 then
      for i = 1, #options.labels do
        options.labels[i].hAlign = "center"
        options.labels[i].vAlign = "center"
        self.width = math.max(options.labels[i].width + 10 + navButtonWidth * 2, self.width)
        self.height = math.max(options.labels[i].height + 4, self.height)
      end
      self.rightButton.x = self.width - navButtonWidth
    end

    setLabels(self, options.labels, options.values, self.selectedIndex)

    self.TYPE = "Stepper"
  end,
  UIElement
)

Stepper.setLabels = setLabels
Stepper.setState = setState

function Stepper:receiveInputs(input)
  if input:isPressedWithRepeat("Left") then
    self:setState(self.selectedIndex - 1)
  elseif input:isPressedWithRepeat("Right") then
    self:setState(self.selectedIndex + 1)
  elseif input.isDown["Swap2"] and self.isFocusable then
    self:yieldFocus()
  end
end

function Stepper:refreshLocalization()
  for i, label in ipairs(self.labels) do
    label:refreshLocalization()
  end
  UIElement.refreshLocalization(self)
end

function Stepper:drawSelf()
  if config.debug_mode then
    GraphicsUtil.setColor(self.color)
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(self.borderColor)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return Stepper
local UiElement = require("ui.UIElement")
local class = require("class")

-- StackPanel is a layouting element that stacks up all its children in one direction based on an alignment setting
-- Useful for auto-aligning multiple ui elements that only know one of their dimensions
local StackPanel = class(function(stackPanel, options)
  -- all children are aligned automatically towards that option inside the StackPanel
  -- possible values: "left", "right", "top", "bottom"
  -- for "left" and "right", all children will vertically fill the StackPanel
  -- for "top" and "bottom", all children will horizontally fill the StackPanel
  stackPanel.alignment = options.alignment

  -- StackPanels are unidirectional but can go into either direction
  -- pixelsTaken tracks how many pixels are already taken in the direction the StackPanel propagates towards
  stackPanel.pixelsTaken = 0
end,
UiElement)

function StackPanel:addElement(uiElement)
  if self.alignment == "left" then
    uiElement.vFill = true
    uiElement.hFill = false
    uiElement.hAlign = "left"
    uiElement.x = self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.width
  elseif self.alignment == "right" then
    uiElement.vFill = true
    uiElement.hFill = false
    uiElement.hAlign = "right"
    uiElement.x = - self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.width
  elseif self.alignment == "top" then
    uiElement.vFill = false
    uiElement.hFill = true
    uiElement.vAlign = "top"
    uiElement.y = self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.height
  elseif self.alignment == "bottom" then
    uiElement.vFill = false
    uiElement.hFill = true
    uiElement.vAlign = "bottom"
    uiElement.y = - self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.height
  end

  self:addChild(uiElement)
end


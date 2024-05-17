local UiElement = require("client.src.ui.UIElement")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- StackPanel is a layouting element that stacks up all its children in one direction based on an alignment setting
-- Useful for auto-aligning multiple ui elements that only know one of their dimensions
local StackPanel = class(function(stackPanel, options)
  -- all children are aligned automatically towards that option inside the StackPanel
  -- possible values: "left", "right", "top", "bottom"
  stackPanel.alignment = options.alignment

  -- StackPanels are unidirectional but can go into either direction
  -- pixelsTaken tracks how many pixels are already taken in the direction the StackPanel propagates towards
  stackPanel.pixelsTaken = 0
  -- a stack panel does not have a size limit it's alignment dimension grows with its content

  stackPanel.TYPE = "StackPanel"
end,
UiElement)

function StackPanel:applyStackPanelSettings(uiElement)
  if self.alignment == "left" then
    uiElement.hFill = false
    uiElement.hAlign = "left"
    uiElement.x = self.width
    self.pixelsTaken = self.pixelsTaken + uiElement.width
    self.width = self.pixelsTaken
  elseif self.alignment == "right" then
    uiElement.hFill = false
    uiElement.hAlign = "right"
    uiElement.x = - self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.width
    self.width = self.pixelsTaken
  elseif self.alignment == "top" then
    uiElement.vFill = false
    uiElement.vAlign = "top"
    uiElement.y = self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.height
    self.height = self.pixelsTaken
  elseif self.alignment == "bottom" then
    uiElement.vFill = false
    uiElement.vAlign = "bottom"
    uiElement.y = - self.pixelsTaken
    self.pixelsTaken = self.pixelsTaken + uiElement.height
    self.height = self.pixelsTaken
  end
end

function StackPanel:addElement(uiElement)
  self:applyStackPanelSettings(uiElement)
  self:addChild(uiElement)
  self:resize()
end


function StackPanel:insertElementAtIndex(uiElement, index)
  -- add it at the end
  StackPanel.addElement(self, uiElement)
  StackPanel.shiftTo(self, uiElement, index)
end

function StackPanel:shiftTo(uiElement, index)
  -- swap the previous element with it while updating values until it reached the desired index
  for i = #self.children - 1, index, -1 do
    local otherElement = table.remove(self.children, i)
    if self.alignment == "left" then
      uiElement.x = otherElement.x
      otherElement.x = otherElement.x + uiElement.width
    elseif self.alignment == "right" then
      uiElement.x = otherElement.x
      otherElement.x = otherElement.x - uiElement.width
    elseif self.alignment == "top" then
      uiElement.y = otherElement.y
      otherElement.y = otherElement.y + uiElement.height
    elseif self.alignment == "bottom" then
      uiElement.y = otherElement.y
      otherElement.y = otherElement.y - uiElement.height
    end
    table.insert(self.children, i + 1, otherElement)
  end
end

function StackPanel:remove(uiElement)
  local index = tableUtils.indexOf(self.children, uiElement)

  -- swap the next element with it while updating values until it reached the end, then remove it
  for i = index + 1, #self.children do
    local otherElement = table.remove(self.children, i)
    if self.alignment == "left" then
      otherElement.x = uiElement.x
      uiElement.x = uiElement.x + otherElement.width
    elseif self.alignment == "right" then
      otherElement.x = uiElement.x
      uiElement.x = uiElement.x - otherElement.width
    elseif self.alignment == "top" then
      otherElement.y = uiElement.y
      uiElement.y = uiElement.y + otherElement.height
    elseif self.alignment == "bottom" then
      otherElement.y = uiElement.y
      uiElement.y = uiElement.y + otherElement.height
    end
    table.insert(self.children, i - 1, otherElement)
  end

  if self.alignment == "left" or self.alignment == "right" then
    self.width = self.width - uiElement.width
    self.pixelsTaken = self.width
  else
    self.height = self.height - uiElement.height
    self.pixelsTaken = self.height
  end
  uiElement:detach()
end

function StackPanel:drawSelf()
  if DEBUG_ENABLED then
    GraphicsUtil.setColor(1, 0, 0, 0.7)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return StackPanel
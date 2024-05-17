local StackPanel = require("client.src.ui.StackPanel")
local Label = require("client.src.ui.Label")
local class = require("common.lib.class")
local focusable = require("client.src.ui.Focusable")

-- forms a layer of abstraction between a player specific selector (e.g. GridCursor) and UiElements that exist per player
-- the MultiPlayerSelectionWrapper displays the UiElements of all players but upon selection only redirects inputs to the 
local MultiPlayerSelectionWrapper = class(function(wrapper, options)
  focusable(wrapper)
  wrapper.activeElement = nil
  wrapper.wrappedElements = {}

  wrapper.TYPE = "MultiPlayerSelectionWrapper"
end,
StackPanel)

function MultiPlayerSelectionWrapper:addElement(uiElement, player)
  self.wrappedElements[player] = uiElement
  uiElement.yieldFocus = function()
    self.yieldFocus()
  end
  self:applyStackPanelSettings(uiElement)
  self:addChild(uiElement)
  self:resize()
end

function MultiPlayerSelectionWrapper:insertElementAtIndex(uiElement, index, player)
  self:addElement(uiElement, player)
  self:shiftTo(index)
end

-- the parent makes sure this is only called while focused
function MultiPlayerSelectionWrapper:receiveInputs(inputs, dt, player)
  self.wrappedElements[player]:receiveInputs(inputs, dt)
end

function MultiPlayerSelectionWrapper:drawSelf()
  -- probably apply a dim shader while not focused or something
end

function MultiPlayerSelectionWrapper:setTitle(string)
  self.title = Label({text = string})
  if self.alignment == "top" or self.alignment == "bottom" then
    self.title.hAlign = "center"
    self.title.vAlign = self.alignment
    StackPanel.insertElementAtIndex(self, self.title, 1)
  else
    self.title.hAlign = "center"
    self.title.vAlign = "top"
    self:addChild(self.title)
  end
end

return MultiPlayerSelectionWrapper
local UiElement = require("ui.UIElement")
local StackPanel = require("ui.StackPanel")
local class = require("class")
local focusable = require("ui.Focusable")

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

-- the parent makes sure this is only called while focused
function MultiPlayerSelectionWrapper:receiveInputs(inputs)
  self.wrappedElements[inputs.usedByPlayer]:receiveInputs(inputs)
end

function MultiPlayerSelectionWrapper:drawSelf()
  -- probably apply a dim shader while not focused or something
end

return MultiPlayerSelectionWrapper
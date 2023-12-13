local UiElement = require("ui.UIElement")
local class = require("class")
local focusable = require("ui.Focusable")

-- forms a layer of abstraction between a player specific selector (e.g. GridCursor) and UiElements that exist per player
-- the MultiPlayerSelectionWrapper displays the UiElements of all players but upon selection only redirects inputs to the 
local MultiPlayerSelectionWrapper = class(function(wrapper, options)
  focusable(wrapper)
  wrapper.activeElement = nil
  wrapper.wrappedElements = {}
end,
UiElement)

function MultiPlayerSelectionWrapper:addElement(uiElement, player)
  self.wrappedElements[player] = uiElement
  uiElement.yieldFocus = function()
    self.yieldFocus()
  end
  self:addChild(uiElement)
end

-- the parent makes sure this is only called while focused
function MultiPlayerSelectionWrapper:receiveInputs(inputSource)
  self.wrappedElements[inputSource.player]:receiveInputs()
end

function MultiPlayerSelectionWrapper:drawSelf()
  -- probably apply a dim shader while not focused or something
end

return MultiPlayerSelectionWrapper
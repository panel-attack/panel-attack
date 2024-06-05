local UiElement = require("client.src.ui.UIElement")
local class = require("common.lib.class")
local Focusable = require("client.src.ui.Focusable")
local consts = require("common.engine.consts")

-- technically this value should be derived from the font size set for the label
local SCROLL_STEP = 14

local ScrollText = class(function(self, options)
  assert(options.label, "ScrollText needs a self.label for display!")

  self.label = options.label
  self:addChild(self.label)

  Focusable(self)
end,
UiElement)

function ScrollText:receiveInputs(inputs)
  if inputs:isPressedWithRepeat("MenuUp", .25, 0.03) then
    GAME.theme:playMoveSfx()
    if self.label.height > self.height - (SCROLL_STEP + 1) then
      self.label.y = math.min((SCROLL_STEP + 1), self.label.y + SCROLL_STEP)
    end
  end
  if inputs:isPressedWithRepeat("MenuDown", .25, 0.03) then
    GAME.theme:playMoveSfx()
    if self.label.height > self.height - (SCROLL_STEP + 1) then
      self.label.y = math.max(self.label.y - SCROLL_STEP, (self.height - (SCROLL_STEP + 1)) - self.label.height)
    end
  end
  if inputs.isDown.MenuLeft then
    GAME.theme:playMoveSfx()
    if self.label.height > self.height - (SCROLL_STEP + 1) then
      self.label.y = math.min((SCROLL_STEP + 1), self.label.y + (self.height - (SCROLL_STEP + 1)))
    end
  end
  if inputs.isDown.MenuRight then
    GAME.theme:playMoveSfx()
    if self.label.height > self.height - (SCROLL_STEP + 1) then
      self.label.y = math.max(self.label.y - (self.height - (SCROLL_STEP + 1)), (self.height - (SCROLL_STEP + 1)) - self.label.height)
    end
  end
  if inputs.isDown["MenuEsc"] then
    GAME.theme:playCancelSfx()
    self:onBack()
  end
end

function ScrollText:onTouch(x, y)
  self.swiping = true
  self.initialTouchY = y
  self.originalY = self.label.y
end

function ScrollText:onDrag(x, y)
  local yOffset = y - self.initialTouchY
  if yOffset > 0 then
    self.label.y = math.min((SCROLL_STEP + 1), self.originalY + yOffset)
  else
    self.label.y = math.max(self.originalY + yOffset, (self.height - (SCROLL_STEP + 1)) - self.label.height)
  end
end

function ScrollText:onRelease(x, y)
  self:onDrag(x, y)
  self.swiping = false
end

-- this should/may be overwritten by the parent
function ScrollText:onBack()
  if self.onBackCallback then
    self.onBackCallback()
  end
  self:yieldFocus()
end

return ScrollText
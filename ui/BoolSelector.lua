local UiElement = require("ui.UIElement")
local class = require("class")
local touchable = require("ui.Touchable")

local BoolSelector = class(function(boolSelector, options)
  boolSelector.trueLabel = options.trueLabel
  boolSelector.falseLabel = options.falseLabel
  boolSelector.trueLabel.hAlign = "center"
  boolSelector.trueLabel.vAlign = "top"
  boolSelector.falseLabel.hAlign = "center"
  boolSelector.falseLabel.vAlign = "bottom"
  boolSelector:addChild(boolSelector.trueLabel)
  boolSelector:addChild(boolSelector.falseLabel)
  boolSelector.value = options.startValue or false
  touchable(boolSelector)
end,
UiElement)

function BoolSelector:onRelease(x, y)
  self:setValue(not self.value)
end

function BoolSelector:setValue(value)
  if self.value ~= value and self.onValueChange then
    self:onValueChange(not self.value)
  end
  self.value = value
end

-- other code may implement a callback here
-- function BoolSelector.onValueChange() end

function BoolSelector:drawSelf()
  love.graphics.rectangle("line", 0, 0, 40, 70, 10, 20)
  love.graphics.circle("fill", 5, 5, 30)
end
local UiElement = require("ui.UIElement")
local class = require("class")
local touchable = require("ui.Touchable")
local GraphicsUtil = require("graphics_util")

local BoolSelector = class(function(boolSelector, options)
  boolSelector.value = options.startValue or false
  touchable(boolSelector)
  boolSelector.TYPE = "BoolSelector"
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

local fakeCenteredChild = {hAlign = "center", vAlign = "center", width = 30, height = 40}

function BoolSelector:drawSelf()
  if DEBUG_ENABLED then
    GraphicsUtil.setColor(0, 0, 1, 1)
    love.graphics.rectangle("line", self.x + 1, self.y + 1, self.width - 2, self.height - 2)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end

  -- we want these to be centered but creating a Rectangle / Circle ui element is maybe a bit too much?
  -- so just apply the translation via a fake element with all necessary props
  GraphicsUtil.applyAlignment(self, fakeCenteredChild)
  love.graphics.translate(self.x, self.y)

  love.graphics.rectangle("line", 0, 0, 30, 40, 10, 15)
  if self.value then
    love.graphics.circle("fill", 15, 15, 10)
  else
    love.graphics.circle("fill", 15, 25, 10)
  end

  GraphicsUtil.resetAlignment()
end

return BoolSelector
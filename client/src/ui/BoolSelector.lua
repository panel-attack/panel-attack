local UiElement = require("client.src.ui.UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local BoolSelector = class(function(boolSelector, options)
  boolSelector.value = options.startValue or false
  boolSelector.TYPE = "BoolSelector"
end,
UiElement)

function BoolSelector:onRelease(x, y)
  self:setValue(not self.value)
end

function BoolSelector:setValue(value)
  local old = self.value
  self.value = value
  if old ~= value and self.onValueChange then
    self:onValueChange(self.value)
  end
end

-- other code may implement a callback here
-- function BoolSelector.onValueChange() end

local fakeCenteredChild = {hAlign = "center", vAlign = "center", width = 30, height = 40}

function BoolSelector:drawSelf()
  if DEBUG_ENABLED then
    GraphicsUtil.setColor(0, 0, 1, 1)
    GraphicsUtil.drawRectangle("line", self.x + 1, self.y + 1, self.width - 2, self.height - 2)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end

  -- we want these to be centered but creating a Rectangle / Circle ui element is maybe a bit too much?
  -- so just apply the translation via a fake element with all necessary props
  GraphicsUtil.applyAlignment(self, fakeCenteredChild)
  love.graphics.translate(self.x, self.y)

  GraphicsUtil.drawRectangle("line", 0, 0, 30, 40, nil, nil, nil, nil, 10, 15)
  if self.value then
    love.graphics.circle("fill", 15, 15, 10)
  else
    love.graphics.circle("fill", 15, 25, 10)
  end

  GraphicsUtil.resetAlignment()
end

return BoolSelector
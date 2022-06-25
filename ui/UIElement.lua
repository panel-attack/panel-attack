local class = require("class")

--@module Button
local UIElement = class(function(self, options) end)

function UIElement:updateLabel(label)
  if label then
    self.label = label
  end

  if self.translate or label then
    self.text = love.graphics.newText(love.graphics.getFont(), self.translate and loc(self.label, unpack(self.extra_labels)) or self.label)
  end
end

function UIElement:setVisibility(is_visible)
  self.is_visible = is_visible
end

return UIElement
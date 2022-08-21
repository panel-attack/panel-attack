local class = require("class")

local uniqueId = 0

--@module Button
local UIElement = class(
  function(self, options)
    self.id = uniqueId
    uniqueId = uniqueId + 1
    
    self.x = options.x or 0
    self.y = options.y or 0
    self.width = options.width or 110
    self.height = options.height or 25
    self.label = options.label or ""
    self.extraLabels = options.extra_labels or {}
    self.translate = options.translate or options.translate == nil and true
    self.isVisible = options.isVisible or options.isVisible == nil and true
    self.parent = options.parent
    self.children = options.children or {}
    
    self.text = love.graphics.newText(love.graphics.getFont(), self.translate and loc(self.label, unpack(self.extraLabels)) or self.label)
    self.TYPE = "UIElement"
  end
)



function UIElement:addChild(uiElement)
  self.children[#self.children + 1] = uiElement
  uiElement.parent = self
end

function UIElement:detach()
  if self.parent then
    for i, child in ipairs(self.parent.children) do
      if child.id == self.id then
        table.remove(self.parent.children, i)
      end
    end
    self.parent = nil
    return self
  end
end

function UIElement:getScreenPos()
  local x, y = 0, 0
  if self.parent then
    x, y = self.parent:getScreenPos()
  end
  
  return x + self.x, y + self.y
end

function UIElement:updateLabel(label)
  if label then
    self.label = label
  end

  if self.translate or label then
    self.text = love.graphics.newText(love.graphics.getFont(), self.translate and loc(self.label, unpack(self.extraLabels)) or self.label)
  end
  
  for _, uiElement in pairs(self.children) do
    uiElement:updateLabel()
  end
end

function UIElement:setVisibility(isVisible)
  self.isVisible = isVisible
  for _, uiElement in pairs(self.children) do
    uiElement:setVisibility(isVisible)
  end
end

return UIElement
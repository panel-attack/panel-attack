local class = require("class")

local uniqueId = 0

--@module UIElement
-- base class for all UI elements
-- takes in a options table for setting default values
-- all valid base options are defined in the constructor
local UIElement = class(
  function(self, options)
    -- local position relative to parent (or global pos if parent is nil)
    self.x = options.x or 0
    self.y = options.y or 0
    
    -- ui dimensions
    self.width = options.width or 110
    self.height = options.height or 25
    
    -- label to be displayed on ui element
    -- Only used for Buttons & Labels
    self.label = options.label
    -- list of parameters for translating the label
    if self.label then
      self.extraLabels = options.extra_labels or {}
    end
    -- whether we should traslante the label or not
    self.translate = options.translate or options.translate == nil and true
    
    -- whether the ui element is visible
    self.isVisible = options.isVisible or options.isVisible == nil and true
    -- whether the ui element recieves events
    self.isEnabled = options.isEnabled or options.isEnabled == nil and true
    
    -- the parent element, position is relative to it
    self.parent = options.parent
    -- list of children elements
    self.children = options.children or {}
    
    -- private members
    if self.label then
      self.text = love.graphics.newText(love.graphics.getFont(), self.translate and loc(self.label, unpack(self.extraLabels)) or self.label)
    elseif options.text then
      self.text = options.text
    end
    
    self.id = uniqueId
    uniqueId = uniqueId + 1
    
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
        self.parent = nil
        break
      end
    end
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

-- updates the label with a new label
-- also translates the label if needed
-- if no label is passed in it will translate the existing label
function UIElement:updateLabel(label)
  if label then
    self.label = label
  end

  if self.label and (self.translate or label) then
    self.text = love.graphics.newText(love.graphics.getFont(), self.translate and loc(self.label, unpack(self.extraLabels)) or self.label)
  end
  
  for _, uiElement in ipairs(self.children) do
    uiElement:updateLabel()
  end
end

function UIElement:draw()
  for _, uiElement in ipairs(self.children) do
    if uiElement.isVisible then
      uiElement:draw()
    end
  end
end

function UIElement:setVisibility(isVisible)
  self.isVisible = isVisible
  for _, uiElement in ipairs(self.children) do
    uiElement:setVisibility(isVisible)
  end
end

function UIElement:setEnabled(isEnabled)
  self.isEnabled = isEnabled
  for _, uiElement in ipairs(self.children) do
    uiElement:setEnabled(isEnabled)
  end
end

return UIElement
local class = require("class")
local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")

--@module Label
local Label = class(
  function(self, options)
    self.text = options.text
    -- list of parameters for translating the label (e.g. numbers/names to replace placeholders with)
    self.replacementTable = options.extraLabels or {}

    -- whether we should translate the label or not
    if options.translate == nil then
      self.translate = true
    else
      self.translate = options.translate
    end

    if self.translate then
      self.drawable = love.graphics.newText(love.graphics.getFont(), loc(self.text, unpack(self.replacementTable)))
    else
      self.drawable = love.graphics.newText(love.graphics.getFont(), self.text)
    end
    local textWidth, textHeight = self.drawable:getDimensions()
    self.width = math.max(self.width, textWidth)
    self.height = math.max(self.height, textHeight)

    self.TYPE = "Label"
  end,
  UIElement
)

function Label:draw()
  if not self.isVisible then
    return
  end

  local screenX, screenY = self:getScreenPos()

  GraphicsUtil.drawClearText(self.drawable, screenX, screenY, self.width / 2, self.height / 2)

  self:drawChildren()
end

return Label
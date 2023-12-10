local class = require("class")
local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")

--@module Label
local Label = class(
  function(self, options)
    self.halign = options.halign or "center"
    self.valign = options.valign or "center"

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

function Label:drawSelf()
  GraphicsUtil.drawClearText(self.drawable, self.x, self.y)
end

return Label
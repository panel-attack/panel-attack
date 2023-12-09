local class = require("class")
local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")

local TEXT_WIDTH_PADDING = 15
local TEXT_HEIGHT_PADDING = 6
--@module Label
local Label = class(
  function(self, options)
    self.text = options.text
    -- list of parameters for translating the label (e.g. numbers/names to replace placeholders with)
    self.replacementTable = options.extraLabels or {}

    -- whether we should translate the label or not
    self.translate = options.translate or true

    self.drawable = love.graphics.newText(love.graphics.getFont(), self.translate and loc(self.text, unpack(self.replacementTable)) or nil)
    self.width, self.height = self.drawable:getDimensions()

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
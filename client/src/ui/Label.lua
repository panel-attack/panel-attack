local class = require("common.lib.class")
local UIElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local Label = class(
  function(self, options)
    self.hAlign = options.hAlign or "left"
    self.vAlign = options.vAlign or "top"

    self.hFill = options.hFill or true

    self.wrap = options.wrap or false
    self.wrapRatio = options.wrapRatio or 1

    if options.fontSize then
      self.font = GraphicsUtil.getGlobalFontWithSize(options.fontSize)
      self.fontSize = options.fontSize
    else
      self.font = GraphicsUtil.getGlobalFont()
    end

    self:setText(options.text, options.replacements, options.translate)

    self.TYPE = "Label"
  end,
  UIElement
)

function Label:getEffectiveDimensions()
  return self.drawable:getDimensions()
end

function Label:setText(text, replacementTable, translate)
  if text == self.text and replacementTable == self.replacementTable and self.translate == translate then
    return
  end

  -- whether we should translate the label or not
  if translate ~= nil then
    self.translate = translate
  elseif self.translate == nil then
    self.translate = true
  end

  if replacementTable then
    -- list of parameters for translating the label (e.g. numbers/names to replace placeholders with)
    self.replacementTable = replacementTable
  elseif not self.replacementTable then
    self.replacementTable = {}
  end

  if text then
    self.text = text
  end

  if self.translate then
    -- always need a new text cause the font might have changed
    self.drawable = love.graphics.newTextBatch(self.font, loc(self.text, unpack(self.replacementTable)))
  else
    if not self.drawable then
      self.drawable = love.graphics.newTextBatch(self.font, self.text)
    end
  end

  self:refreshFormatting()

  self.width = self.drawable:getWidth()
  self.height = self.drawable:getHeight()
end

function Label:setWrap(wrapRatio, hAlign)
  self.wrap = not not wrapRatio
  self.wrapRatio = wrapRatio
  self.hAlign = hAlign or self.hAlign
  self:refreshFormatting()
end

function Label:refreshFormatting()
  local text = self.text

  if self.translate then
    text = loc(self.text, unpack(self.replacementTable))
  end

  if self.wrap then
    self.drawable:setf(text, self.wrapRatio * self.width, self.hAlign)
    self.height = self.drawable:getHeight()
  else
    self.drawable:set(text)
  end
end

function Label:onResize()
  if self.wrap then
    self.width = math.max(self.width, self.drawable:getWidth())
  else
    self.width = self.drawable:getWidth()
  end
  self.height = self.drawable:getHeight()
  self:refreshFormatting()
end

function Label:refreshLocalization()
  if self.translate then
    if self.fontSize then
      self.font = GraphicsUtil.getGlobalFontWithSize(self.fontSize)
    else
      self.font = GraphicsUtil.getGlobalFont()
    end
    -- always need a new text cause the font might have changed
    self.drawable = love.graphics.newTextBatch(self.font, loc(self.text, unpack(self.replacementTable)))
    self.width, self.height = self.drawable:getDimensions()
  end
end

function Label:drawSelf()
  GraphicsUtil.drawClearText(self.drawable, self.x, self.y)
end

return Label
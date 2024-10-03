local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local PixelFontLabel = class(function(self, options)
  if options.text then
    self.text = tostring(options.text):upper()
  else
    self.text = ""
  end

  self.charSpacing = options.charSpacing or 2
  self.xScale = options.xScale or 1
  self.yScale = options.yScale or 1
  self.fontMap = options.fontMap or themes[config.theme].fontMaps.pixelFontBlue

  -- effectively we'll draw a quad for each character this much apart
  self.charDistanceScaled = (self.fontMap.charWidth + self.charSpacing) * self.xScale

  self.width = self.text:len() * self.charDistanceScaled
  self.height = self.fontMap.charHeight * self.yScale
end,
UiElement)

function PixelFontLabel:setText(text)
  if text then
    text = tostring(text):upper()
  else
    text = ""
  end

  self.text = text
  self.width = text:len() * self.charDistanceScaled
end


function PixelFontLabel:drawSelf()
  for i = 1, self.text:len(), 1 do
    local char = self.text:sub(i, i)
    if char ~= " " then
      local characterX = self.x + ((i - 1) * self.charDistanceScaled)

      -- Render it at the proper digit location
      GraphicsUtil.drawQuad(self.fontMap.atlas, self.fontMap[char], characterX, self.y, 0, self.xScale, self.yScale)
    end
  end
end

return PixelFontLabel
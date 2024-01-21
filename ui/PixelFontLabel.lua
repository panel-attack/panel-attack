local class = require("class")
local UiElement = require("ui.UIElement")
local tableUtils = require("tableUtils")

-- A pixel font map to use with strings
local standard_pixel_font_map = {["&"]=36, ["?"]=37, ["!"]=38, ["%"]=39, ["*"]=40, ["."]=41}
--0-9 = 0-9
for i = 0, 9, 1 do
  standard_pixel_font_map[tostring(i)] = i
end

--10-35 = A-Z
for i = 10, 35, 1 do
  local characterString = string.char(97+(i-10))
  standard_pixel_font_map[characterString] = i
end

local PixelFontLabel = class(function(self, options)
  if options.text then
    self.text = tostring(options.text)
  else
    self.text = ""
  end
  self.textLength = self.text:len()
  self.charSpacing = options.charSpacing or 2
  self.xScale = options.xScale or 1
  self.yScale = options.yScale or 1
  self.fontMap = options.fontMap or standard_pixel_font_map
  self.atlas = options.atlas or themes[config.theme].images.IMG_pixelFont_blue_atlas
  self.atlasWidth = self.atlas:getWidth()
  self.atlasHeight = self.atlas:getHeight()
  self.quads = {}

  self.charWidth = self.atlas:getWidth() / tableUtils.length(self.fontMap)
  self.charHeight = self.atlasHeight
  -- effectively we'll draw a quad for each character this much apart
  self.charDistanceScaled = (self.charWidth + self.charSpacing) * self.xScale

  self.width = self.textLength * self.charDistanceScaled * self.xScale
  self.height = self.charHeight * self.yScale

  for i = 1, self.text:len() do
    self.quads[i] = GraphicsUtil:newRecycledQuad(0, 0, self.charWidth, self.charHeight, self.atlasWidth, self.atlasHeight)
  end
end,
UiElement)

function PixelFontLabel:setText(text)
  if text then
    text = tostring(text)
  else
    text = ""
  end
  local newLength = text:len()

  -- make sure we have exactly as many quads as needed for the new string
  if newLength > self.textLength then
    for i = self.textLength, newLength do
      self.quads[i] = GraphicsUtil:newRecycledQuad(0, 0, self.charWidth, self.charHeight, self.atlasWidth, self.atlasHeight)
    end
  elseif newLength < self.textLength then
    for i = self.textLength, newLength, -1 do
      GraphicsUtil:releaseQuad(self.quads[i])
    end
  end

  self.text = text:lower()
  self.textLength = newLength

  self.width = self.textLength * self.charDistanceScaled * self.xScale
end


function PixelFontLabel:drawSelf()
  for i = 1, self.textLength, 1 do
    local char = self.text:sub(i, i)
    if char ~= " " then
      local frameNumber = self.fontMap[char]

      -- Select the portion of the atlas that is the current character
      self.quads[i]:setViewport(frameNumber * self.charWidth, 0, self.charWidth, self.charWidth, self.atlasWidth, self.atlasHeight)

      local characterX = self.x + ((i - 1) * self.charDistanceScaled)

      -- Render it at the proper digit location
      love.graphics.draw(self.atlas, self.quads[i], characterX, self.y, 0, self.xScale, self.yScale)
    end
  end
end

return PixelFontLabel
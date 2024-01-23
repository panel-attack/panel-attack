local consts = require("consts")
local logger = require("logger")
local tableUtils = require("tableUtils")

local GFX_SCALE = consts.GFX_SCALE

-- Utility methods for drawing
GraphicsUtil = { 
  fontFile = nil,
  fontSize = 12, 
  fontCache = {},
  quadPool = {}
}

function GraphicsUtil.privateLoadImage(path_and_name)
  local image = nil
  local status = pcall(
    function()
      image = love.graphics.newImage(path_and_name)
    end
  )
  if image == nil then
    return nil
  end
  logger.debug("loaded asset: " .. path_and_name)
  return image
end

function GraphicsUtil.privateLoadImageWithExtensionAndScale(pathAndName, extension, scale)
  local scaleSuffixString = "@" .. scale .. "x"
  if scale == 1 then
    scaleSuffixString = ""
  end

  local fileName = pathAndName .. scaleSuffixString .. extension

  if love.filesystem.getInfo(fileName) then
    local result = GraphicsUtil.privateLoadImage(fileName)
    if result then
      assert(result:getDPIScale() == scale, "The image " .. pathAndName .. " didn't wasn't created with the scale: " .. scale .. " did you make sure the width and height are divisible by the scale?")
      -- We would like to use linear for shrinking and nearest for growing,
      -- but there is a bug in some drivers that doesn't allow for min and mag to be different
      -- to work around this, calculate if we are shrinking or growing and use the right filter on both.
      if GAME.canvasXScale >= scale then
        result:setFilter("nearest", "nearest")
      else
        result:setFilter("linear", "linear")
      end
      return result
    end
    
    logger.error("Error loading image: " .. fileName .. " Check it is valid and try resaving it in an image editor. If you are not the owner please get them to update it or download the latest version.")
    result = GraphicsUtil.privateLoadImageWithExtensionAndScale("themes/Panel Attack/transparent", ".png", 1)
    assert(result ~= next)
    return result
  end

  return nil
end

function GraphicsUtil.loadImageFromSupportedExtensions(pathAndName)
  local supportedImageFormats = {".png", ".jpg", ".jpeg"}
  local supportedScales = {3, 2, 1}
  for _, extension in ipairs(supportedImageFormats) do
    for _, scale in ipairs(supportedScales) do
      local image = GraphicsUtil.privateLoadImageWithExtensionAndScale(pathAndName, extension, scale)
      if image then
        return image
      end
    end
  end

  return nil
end

-- Draws a image at the given screen spot and scales.
function GraphicsUtil.drawImage(image, x, y, scaleX, scaleY)
  if image ~= nil and x ~= nil and y ~= nil and scaleX ~= nil and scaleY ~= nil then
    love.graphics.draw(image, x, y, 0, scaleX, scaleY)
  end
end

-- Draws an image at the given spot while scaling all coordinate and scale values with GFX_SCALE
function drawGfxScaled(img, x, y, rot, xScale, yScale)
  love.graphics.draw(img, x * GFX_SCALE, y * GFX_SCALE, rot, xScale * GFX_SCALE, yScale * GFX_SCALE)
end

-- Draws an image, texture or canvas at the given spot
function GraphicsUtil.draw(img, x, y, rot, x_scale,y_scale)
  love.graphics.draw(img, x, y, rot, x_scale, y_scale)
end

-- A pixel font map to use with numbers
local number_pixel_font_map = {}
--0-9 = 0-9
for i = 0, 9, 1 do
  number_pixel_font_map[tostring(i)] = i
end

-- A pixel font map to use with times
local time_pixel_font_map = {}
--0-9 = 0-9
for i = 0, 9, 1 do
  time_pixel_font_map[tostring(i)] = i
end
time_pixel_font_map[":"] = 10
time_pixel_font_map["'"] = 11

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


-- Draws the given string with the given pixel font image atlas
-- string - the string to draw
-- TODO support both upper and lower case
-- atlas - the image to use as the pixel font
-- font map - a dictionary of a character mapped to the column number in the pixel font image
local function drawPixelFontWithMap(string, atlas, font_map, x, y, x_scale, y_scale, align, characterSpacing, quads)
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  align = align or "left"
  font_map = font_map or standard_pixel_font_map
  assert(quads ~= nil)

  local atlasFrameCount = tableUtils.length(font_map)
  local atlasWidth = atlas:getWidth()
  local atlasHeight = atlas:getHeight()
  local characterWidth = atlasWidth/atlasFrameCount
  local characterHeight = atlasHeight
  characterSpacing = characterSpacing or 2
  local characterDistanceScaled = (characterWidth + characterSpacing) * x_scale

  if string == nil or atlas == nil or atlasFrameCount == nil or characterWidth == nil or characterHeight == nil then
    logger.error("Error initalizing draw pixel font")
    return 
  end

  while #quads < #string do
    table.insert(quads, GraphicsUtil:newRecycledQuad(0, 0, characterWidth, characterHeight, atlasWidth, atlasHeight))
  end

  for i = 1, #string, 1 do
    local c = string:sub(i,i)
    if c == nil or c == " " then
      goto continue
    end

    local frameNumber = font_map[c]

    -- Select the portion of the atlas that is the current character
    quads[i]:setViewport(frameNumber*characterWidth, 0, characterWidth, characterHeight, atlasWidth, atlasHeight)

    local characterIndex = i - 1
    local characterX = x + (characterIndex * characterDistanceScaled)
    if align == "center" then
      characterX = x + ((characterIndex-(#string/2))*characterDistanceScaled)
    elseif align == "right" then
      characterX = x + ((characterIndex-#string)*characterDistanceScaled)
    end

    -- Render it at the proper digit location
    love.graphics.draw(atlas, quads[i], characterX, y, 0, x_scale, y_scale)

    ::continue::
  end

end

-- Draws a time centered horizontally using the theme's time pixel font which is 0-9, then : then '
function GraphicsUtil.draw_time(time, quads, x, y, scale)
  drawPixelFontWithMap(time, themes[config.theme].images.IMG_timeNumber_atlas, time_pixel_font_map, x, y, scale, scale, "center", 0, quads)
end

-- Draws a number via the given font image that has 0-9
function GraphicsUtil.draw_number(number, atlas, quads, x, y, scale, align)
  drawPixelFontWithMap(tostring(number), atlas, number_pixel_font_map, x, y, scale, scale, align, 0, quads)
end

-- Draws the given string with a pixel font image atlas that has 0-9 than a-z
-- string - the string to draw
-- atlas - the image to use as the pixel font
function draw_pixel_font(string, atlas, x, y, x_scale, y_scale, align, characterSpacing, quads)
  drawPixelFontWithMap(string, atlas, standard_pixel_font_map, x, y, x_scale, y_scale, align, characterSpacing, quads)
end

local maxQuadPool = 100

-- Creates a new quad, recycling one if one exists in the pool to reduce memory.
function GraphicsUtil:newRecycledQuad(x, y, width, height, sw, sh)
  local result = nil
  if #self.quadPool == 0 then
    result = love.graphics.newQuad(x, y, width, height, sw, sh)
  else
    result = self.quadPool[#self.quadPool]
    self.quadPool[#self.quadPool] = nil
    result:setViewport(x, y, width, height, sw, sh)
  end
  
  return result
end

-- Stop using a quad and add it to the pool for reuse
function GraphicsUtil:releaseQuad(quad)
  if #self.quadPool >= maxQuadPool then
    quad:release()
  else
    self.quadPool[#self.quadPool+1] = quad
  end
end

-- Draws an image at the given position, using the quad for the viewport
function qdraw(img, quad, x, y, rot, x_scale, y_scale, x_offset, y_offset, mirror)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  x_offset = x_offset or 0
  y_offset = y_offset or 0
  mirror = mirror or 0

  local qX, qY, qW, qH = quad:getViewport()
  if mirror == 1 then
    x = x - (qW*x_scale)
  end

  love.graphics.draw(img, quad, x*GFX_SCALE, y*GFX_SCALE, rot, x_scale*GFX_SCALE, y_scale*GFX_SCALE, x_offset, y_offset)
end

function menu_drawf(img, x, y, halign, valign, rot, x_scale, y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  halign = halign or "left"
  if halign == "center" then
    x = x - math.floor(img:getWidth() * 0.5 * x_scale)
  elseif halign == "right" then
    x = x - math.floor(img:getWidth() * x_scale)
  end
  valign = valign or "top"
  if valign == "center" then
    y = y - math.floor(img:getHeight() * 0.5 * y_scale)
  elseif valign == "bottom" then
    y = y - math.floor(img:getHeight() * y_scale)
  end

  love.graphics.draw(img, x, y, rot, x_scale, y_scale)
end

function menu_drawq(img, quad, x, y, rot, x_scale,y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1

  love.graphics.draw(img, quad, x, y, rot, x_scale, y_scale)
end

-- Draws a rectangle at the given coordinates
function GraphicsUtil.drawRectangle(mode, x, y, w, h, r, g, b, a)
  a = a or 1
  if r then
    love.graphics.setColor(r, g, b, a)
  end

  love.graphics.rectangle(mode, x, y, w, h)
  love.graphics.setColor(1, 1, 1, 1)
end

function GraphicsUtil.drawStraightLine(x1, y1, x2, y2, r, g, b, a)
  a = a or 1

  love.graphics.setColor(r, g, b, a)
  love.graphics.line(x1, y1, x2, y2)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Draws text at the given spot
function gprint(str, x, y, color, scale)
  x = x or 0
  y = y or 0
  scale = scale or 1
  color = color or nil
  GraphicsUtil.setColor(0, 0, 0, 1)
  love.graphics.print(str, x+1, y+1, 0, scale)

  local r, g, b, a = 1,1,1,1
  if color ~= nil then
    r,g,b,a = unpack(color)
  end
  GraphicsUtil.setColor(r,g,b,a)
  love.graphics.print(str, x, y, 0, scale)
  GraphicsUtil.setColor(1,1,1,1)
end

-- draws a readymade Text object at a specific coordinate
function GraphicsUtil.printText(text, x, y, align)
  align = align or "left"

  local xOffset = x

  if align ~= "left" then
    local width = text:getWidth()
    if align == "center" then
      xOffset = x - width / 2
    elseif align == "right" then
      xOffset = x - width
    else
      error(align .. " is not a valid alignment")
    end
  end

  love.graphics.draw(text, xOffset, y, 0, 1, 1, 0, 0)
end

local function privateMakeFont(fontPath, size)
  local f
  local hinting = "normal"
  local dpi = GAME:newCanvasSnappedScale()
  if fontPath then
    f = love.graphics.newFont(fontPath, size, hinting, dpi)
  else
    f = love.graphics.newFont(size, hinting, dpi)
  end

  return f
end

-- Creates a new font based on the current font and a delta
function GraphicsUtil.getGlobalFontWithSize(fontSize)
  local f = GraphicsUtil.fontCache[fontSize]
  if not f then
    f = privateMakeFont(GraphicsUtil.fontFile, fontSize)
    GraphicsUtil.fontCache[fontSize] = f
  end
  return f
end

function GraphicsUtil.setGlobalFont(filepath, size)
  GraphicsUtil.fontCache = {}
  GraphicsUtil.fontFile = filepath
  GraphicsUtil.fontSize = size
  local createdFont = GraphicsUtil.getGlobalFontWithSize(size)
  love.graphics.setFont(createdFont)
end

-- Returns the current global font
function GraphicsUtil.getGlobalFont()
  return GraphicsUtil.getGlobalFontWithSize(GraphicsUtil.fontSize)
end

-- Creates a new font based on the current font and a delta
function get_font_delta(with_delta_size)
  local font_size = GraphicsUtil.fontSize + with_delta_size
  return GraphicsUtil.getGlobalFontWithSize(font_size)
end

function GraphicsUtil.setFont(font)
  love.graphics.setFont(font)
end

function GraphicsUtil.setShader(shader)
  love.graphics.setShader(shader)
end

-- Draws a font with a given font delta from the standard font
function gprintf(str, x, y, limit, halign, color, scale, font_delta_size)
  x = x or 0
  y = y or 0
  scale = scale or 1
  color = color or nil
  limit = limit or consts.CANVAS_WIDTH
  font_delta_size = font_delta_size or 0
  halign = halign or "left"
  GraphicsUtil.setColor(0, 0, 0, 1)
  if font_delta_size ~= 0 then
    GraphicsUtil.setFont(get_font_delta(font_delta_size))
  end
  love.graphics.printf(str, x+1, y+1, limit, halign, 0, scale)

  local r, g, b, a = 1,1,1,1
  if color ~= nil then
    r,g,b,a = unpack(color)
  end
  GraphicsUtil.setColor(r,g,b,a)
  love.graphics.printf(str, x, y, limit, halign, 0, scale)

  if font_delta_size ~= 0 then
    GraphicsUtil.setFont(GraphicsUtil.getGlobalFont())
  end
  GraphicsUtil.setColor(1,1,1,1)
end

local _r, _g, _b, _a
function GraphicsUtil.setColor(r, g, b, a)
  a = a or 1
  -- only do it if this color isn't the same as the previous one...
  if _r~=r or _g~=g or _b~=b or _a~=a then
      _r,_g,_b,_a = r,g,b,a
      love.graphics.setColor(r, g, b, a)
    end
end

-- temporary work around to drawing clearer text until we use better fonts
-- draws multiple copies of the same text slightly offset from each other
-- to simultate thickness
-- also draw in 2 stages, first for a drop shadow and second for the main text
-- text: Drawable text object
-- x: The position to draw the object (x-axis).
-- y: The position to draw the object (y-axis).
-- ox: Origin offset (x-axis).
-- oy: Origin offset (y-axis).
function GraphicsUtil.drawClearText(text, x, y, ox, oy)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.draw(text, x - 1, y - 1, 0, 1, 1, ox, oy)
  love.graphics.draw(text, x - 1, y + 1, 0, 1, 1, ox, oy)
  love.graphics.draw(text, x + 2, y - 1, 0, 1, 1, ox, oy)
  love.graphics.draw(text, x + 2, y + 1, 0, 1, 1, ox, oy)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(text, x + 0, y + 0, 0, 1, 1, ox, oy)
  love.graphics.draw(text, x + 1, y + 0, 0, 1, 1, ox, oy)
end

function GraphicsUtil.getAlignmentOffset(parentElement, childElement)
  local xOffset, yOffset
  if childElement.hAlign == "center" then
    xOffset = parentElement.width / 2 - childElement.width / 2
  elseif childElement.hAlign == "right" then
    xOffset = parentElement.width - childElement.width
  else -- if hAlign == "left" then
    -- default
    xOffset = 0
  end

  if childElement.vAlign == "center" then
    yOffset = parentElement.height / 2 - childElement.height / 2
  elseif childElement.vAlign == "bottom" then
    yOffset = parentElement.height - childElement.height
  else --if uiElement.vAlign == "top" then
    -- default
    yOffset = 0
  end

  return xOffset, yOffset
end

-- sets the translation for a childElement inside of a parentElement so that
-- x=0, y=0 aligns the childElement inside the parentElement according to the settings
function GraphicsUtil.applyAlignment(parentElement, childElement)
  love.graphics.push("transform")
  love.graphics.translate(GraphicsUtil.getAlignmentOffset(parentElement, childElement))
end

-- resets the translation of the last alignment adjustment
function GraphicsUtil.resetAlignment()
  love.graphics.pop()
end

return GraphicsUtil

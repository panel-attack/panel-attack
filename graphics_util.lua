require("consts")
local logger = require("logger")


-- Utility methods for drawing
GraphicsUtil = { fontFile = nil, fontSize = 12, fontCache = {} }

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
      assert(result:getDPIScale() == scale)
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
  local supportedImageFormats = {".png", ".jpg"}
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
    gfx_q:push({love.graphics.draw, {image, x, y,
    0, scaleX, scaleY}})
  end
end

-- Draws a image at the given screen spot with the given width and height. Scaling as needed.
function GraphicsUtil.drawScaledImage(image, x, y, width, height)
  if image ~= nil and x ~= nil and y ~= nil and width ~= nil and height ~= nil then
    local scaleX = width / image:getWidth()
    local scaleY = height / image:getHeight()
    GraphicsUtil.drawImage(image, x, y, scaleX, scaleY)
  end
end

-- Draws a image at the given screen spot with the given width. Scaling to keep the ratio.
function GraphicsUtil.drawScaledWidthImage(image, x, y, width)
  if image ~= nil and x ~= nil and y ~= nil and width ~= nil then
    local scaleX = width / image:getWidth()
    GraphicsUtil.drawImage(image, x, y, scaleX, scaleX)
  end
end

-- Draws an image at the given spot
-- TODO rename
function draw(img, x, y, rot, x_scale, y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  gfx_q:push({love.graphics.draw, {img, x*GFX_SCALE, y*GFX_SCALE,
  rot, x_scale*GFX_SCALE, y_scale*GFX_SCALE}})
end

-- Draws a label image at the given spot.
-- TODO consolidate with above
function draw_label(img, x, y, rot, scale, mirror)
  rot = rot or 0
  mirror = mirror or 0
  x = x - math.floor((img:getWidth()/GFX_SCALE*scale)*mirror)
  gfx_q:push({love.graphics.draw, {img, x*GFX_SCALE, y*GFX_SCALE,
  rot, scale, scale}})
end

-- Draws a number via a font image
-- TODO consolidate with draw_pixel_font which should encompass all this API
function draw_number(number, atlas, frameCount, quads, x, y, scale, x_scale, y_scale, align, mirror)
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  align = align or "left"
  mirror = mirror or 0
  
  local width = atlas:getWidth()
  local height = atlas:getHeight()
  local numberWidth = atlas:getWidth()/frameCount
  local numberHeight = atlas:getHeight()
  
  x = x - (numberWidth*GFX_SCALE*scale)*mirror

  if number == nil or atlas == nil or numberHeight == nil or numberWidth == nil then return end

  while #quads < #tostring(number) do
    table.insert(quads, love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height))
  end

  for i = 1, #tostring(number), 1 do
    local c = tostring(number):sub(i,i)
    if c == nil then return end
    quads[i]:setViewport(tonumber(c)*numberWidth, 0, numberWidth, numberHeight, width, height)
    if align == "left" then
      gfx_q:push({love.graphics.draw, {atlas, quads[i], ((x+(i*(13*scale)))-(13*scale)), y,
        0, x_scale, y_scale}})
    end
    if align == "center" then
      gfx_q:push({love.graphics.draw, {atlas, quads[i], (x+((i-(#tostring(number)/2))*(13*scale))), y,
        0, x_scale, y_scale}})
    end
    if align == "right" then
      gfx_q:push({love.graphics.draw, {atlas, quads[i], (x+((i-#tostring(number))*(13*scale))), y,
        0, x_scale, y_scale}})
    end
  end

end

-- Draws a time using a pixel font
-- TODO consolidate with draw_pixel_font which should encompass all this API
function draw_time(time, quads, x, y, x_scale, y_scale)
  x_scale = x_scale or 1
  y_scale = y_scale or 1

  if #quads == 0 then
    width = themes[config.theme].images.IMG_timeNumber_atlas:getWidth()
    height = themes[config.theme].images.IMG_timeNumber_atlas:getHeight()
    numberWidth = themes[config.theme].images.timeNumberWidth
    numberHeight = themes[config.theme].images.timeNumberHeight
    quads =
    {
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height),
      love.graphics.newQuad(0, 0, numberWidth, numberHeight, width, height)
    }

    symbolEnum = {[":"]=10, ["'"]=11, ["-"]=13}
    for i = 1, #time, 1 do
      local c = time:sub(i,i)

      if c ~= ":" and c ~= "'" and c ~= "-" then
        quads[i]:setViewport(tonumber(c)*numberWidth, 0, numberWidth, numberHeight, width, height)
      else
        quads[i]:setViewport(symbolEnum[c]*numberWidth, 0, numberWidth, numberHeight, width, height)
      end
      gfx_q:push({love.graphics.draw, {themes[config.theme].images.IMG_timeNumber_atlas, quads[i], ((x+(i*(20*themes[config.theme].time_Scale)))-(20*themes[config.theme].time_Scale))+((7-#time)*10), y,
          0, x_scale, y_scale}})
    end

  end
end

-- Returns the pixel font map for the pixel fonts that contain numbers and letters
-- a font map is a dictionary of a character mapped to the column number in the pixel font image
function standard_pixel_font_map()

  -- Special Characters
  local fontMap = {["&"]=36, ["?"]=37, ["!"]=38, ["%"]=39, ["*"]=40, ["."]=41}

  --0-9 = 0-9
  for i = 0, 9, 1 do
    fontMap[tostring(i)] = i
  end

  --10-35 = A-Z
  for i = 10, 35, 1 do
    local characterString = string.char(97+(i-10))
    fontMap[characterString] = i
    --logger.debug(characterString .. " = " .. fontMap[characterString])
  end

  return fontMap
end

-- Draws the given string with the given pixel font image atlas
-- string - the string to draw
-- TODO support both upper and lower case
-- atlas - the image to use as the pixel font
-- font map - a dictionary of a character mapped to the column number in the pixel font image
function draw_pixel_font(string, atlas, font_map, x, y, x_scale, y_scale, align, mirror)
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  align = align or "left"
  mirror = mirror or 0
  font_map = font_map or standard_pixel_font_map()

  local atlasFrameCount = table.length(font_map)
  local atlasWidth = atlas:getWidth()
  local atlasHeight = atlas:getHeight()
  local characterWidth = atlasWidth/atlasFrameCount
  local characterHeight = atlasHeight
  local characterSpacing = 2 -- 3 -- 7 for time
  local characterDistance = characterWidth + characterSpacing

  x = x - (characterWidth*GFX_SCALE*x_scale)*mirror

  if string == nil or atlas == nil or atlasFrameCount == nil or characterWidth == nil or characterHeight == nil then
    logger.error("Error initalizing draw pixel font")
    return 
  end

  local quads = {}

  while #quads < #string do
    table.insert(quads, love.graphics.newQuad(0, 0, characterWidth, characterHeight, atlasWidth, atlasHeight))
  end

  for i = 1, #string, 1 do
    local c = string:sub(i,i)
    if c == nil or c == " " then
      goto continue
    end

    local frameNumber = font_map[c]

    -- Select the portion of the atlas that is the current character
    quads[i]:setViewport(frameNumber*characterWidth, 0, characterWidth, characterHeight, atlasWidth, atlasHeight)

    local characterX = ((x+(i*(characterDistance*x_scale)))-(characterDistance*x_scale))
    if align == "center" then
      characterX = (x+((i-(#string/2))*(characterDistance*x_scale)))
    elseif align == "right" then
      characterX = (x+((i-#string)*(characterDistance*x_scale)))
    end

    -- Render it at the proper digit location
    gfx_q:push({love.graphics.draw, {atlas, quads[i], characterX, y, 0, x_scale, y_scale}})
    ::continue::
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

  qX, qY, qW, qH = quad:getViewport()
  if mirror == 1 then
    x = x - (qW*x_scale)
  end
  gfx_q:push({love.graphics.draw, {img, quad, x*GFX_SCALE, y*GFX_SCALE,
    rot, x_scale*GFX_SCALE, y_scale*GFX_SCALE, x_offset, y_offset}})
end

function menu_draw(img, x, y, rot, x_scale,y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  gfx_q:push({love.graphics.draw, {img, x, y,
    rot, x_scale, y_scale}})
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
  gfx_q:push({love.graphics.draw, {img, x, y,
    rot, x_scale, y_scale}})
end

function menu_drawq(img, quad, x, y, rot, x_scale,y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  gfx_q:push({love.graphics.draw, {img, quad, x, y,
    rot, x_scale, y_scale}})
end

-- Draws a rectangle at the given coordinates
function grectangle(mode, x, y, w, h)
  gfx_q:push({love.graphics.rectangle, {mode, x, y, w, h}})
end

-- Draws a colored rectangle at the given coordinates
function grectangle_color(mode, x, y, w, h, r, g, b, a)
  a = a or 1
  gfx_q:push({love.graphics.setColor, {r, g, b, a}})
  gfx_q:push({love.graphics.rectangle, {mode, x*GFX_SCALE, y*GFX_SCALE, w*GFX_SCALE, h*GFX_SCALE}})
  gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
end

-- Draws text at the given spot
function gprint(str, x, y, color, scale)
  x = x or 0
  y = y or 0
  scale = scale or 1
  color = color or nil
  set_color(0, 0, 0, 1)
  gfx_q:push({love.graphics.print, {str, x+1, y+1, 0, scale}})
  local r, g, b, a = 1,1,1,1
  if color ~= nil then
    r,g,b,a = unpack(color)
  end
  set_color(r,g,b,a)
  gfx_q:push({love.graphics.print, {str, x, y, 0, scale}})
  set_color(1,1,1,1)
end

local function privateMakeFont(fontPath, size)
  local f
  local hinting = "normal"
  local dpi = GAME.canvasXScale
  if fontPath then
    f = love.graphics.newFont(fontPath, size, hinting, dpi)
  else
    f = love.graphics.newFont(size, hinting, dpi)
  end
  local dpi2 = f:getDPIScale()
  return f
end

-- Creates a new font based on the current font and a delta
function get_global_font_with_size(fontSize)
  local f = GraphicsUtil.fontCache[fontSize]
  if not f then
    f = privateMakeFont(GraphicsUtil.fontFile, fontSize)
    GraphicsUtil.fontCache[fontSize] = f
  end
  return f
end

function set_global_font(filepath, size)
  GraphicsUtil.fontCache = {}
  GraphicsUtil.fontFile = filepath
  GraphicsUtil.fontSize = size
  local createdFont = get_global_font_with_size(size)
  love.graphics.setFont(createdFont)
end

-- Returns the current global font
function get_global_font()
  return get_global_font_with_size(GraphicsUtil.fontSize)
end

-- Creates a new font based on the current font and a delta
function get_font_delta(with_delta_size)
  local font_size = GraphicsUtil.fontSize + with_delta_size
  return get_global_font_with_size(font_size)
end

function set_font(font)
  gfx_q:push({love.graphics.setFont, {font}})
end

function set_shader(shader)
  gfx_q:push({love.graphics.setShader, {shader}})
end

-- Draws a font with a given font delta from the standard font
function gprintf(str, x, y, limit, halign, color, scale, font_delta_size)
  x = x or 0
  y = y or 0
  scale = scale or 1
  color = color or nil
  limit = limit or canvas_width
  font_delta_size = font_delta_size or 0
  halign = halign or "left"
  set_color(0, 0, 0, 1)
  local old_font = love.graphics.getFont()
  if font_delta_size ~= 0 then
    set_font(get_font_delta(font_delta_size)) 
  end
  gfx_q:push({love.graphics.printf, {str, x+1, y+1, limit, halign, 0, scale}})
  local r, g, b, a = 1,1,1,1
  if color ~= nil then
    r,g,b,a = unpack(color)
  end
  set_color(r,g,b,a)
  gfx_q:push({love.graphics.printf, {str, x, y, limit, halign, 0, scale}})
  if font_delta_size ~= 0 then set_font(old_font) end
  set_color(1,1,1,1)
end

local _r, _g, _b, _a
function set_color(r, g, b, a)
  a = a or 1
  -- only do it if this color isn't the same as the previous one...
  if _r~=r or _g~=g or _b~=b or _a~=a then
      _r,_g,_b,_a = r,g,b,a
      gfx_q:push({love.graphics.setColor, {r, g, b, a}})
  end
end

-- TODO this should be in a util file
function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function reset_filters()
  GAME.background_overlay = nil
  GAME.foreground_overlay = nil
end

return GraphicsUtil

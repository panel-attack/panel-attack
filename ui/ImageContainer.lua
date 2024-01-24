local class = require("class")
local UiElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")

local ImageContainer = class(function(self, options)
  self.drawBorders = options.drawBorders or false
  self.outlineColor = options.outlineColor or {1, 1, 1, 1}

  self:setImage(options.image, options.width, options.height, options.scale)
end, UiElement)

function ImageContainer:setImage(image, width, height, scale)
  self.image = image
  self.imageWidth, self.imageHeight = self.image:getDimensions()

  if self.hFill and self.vFill then
    self.scale = math.min(self.width / self.imageWidth, self.height / self.imageHeight)
  else
    scale = scale or 1
  
    local scaledImageWidth = self.imageWidth * scale
    local scaledImageHeight = self.imageHeight * scale
  
    if width and height then
      -- scale is getting capped to what width and height actually give us
      self.scale = math.min(width / scaledImageWidth, height / scaledImageHeight)
      self.width = width * scale
      self.height = height * scale
    else
      -- there are no size limits, set the size based on scale
      self.width = scaledImageWidth
      self.height = scaledImageHeight
      self.scale = scale
    end
  end
end

function ImageContainer:onResize()
  self.scale = math.min(self.width / self.imageWidth, self.height / self.imageHeight)
  self.width = self.imageWidth * self.scale
  self.height = self.imageHeight * self.scale
end

function ImageContainer:drawSelf()
  GraphicsUtil.draw(self.image, self.x, self.y, 0, self.scale, self.scale)

  if self.drawBorders then
    -- border is just drawn on top, not around
    GraphicsUtil.setColor(self.outlineColor)
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

return ImageContainer

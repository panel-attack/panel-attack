local class = require("class")
local UiElement = require("ui.UIElement")

local ImageContainer = class(function(self, options)
  self.drawBorders = options.drawBorders or false
  self.outlineColor = options.outlineColor or {1, 1, 1, 1}

  self:setImage(options.image, options.width, options.height, options.scale)
end, UiElement)

function ImageContainer:setImage(image, width, height, scale)
  self.image = image
  self.imageWidth, self.imageHeight = self.image:getDimensions()

  scale = scale or 1

  local scaledImageWidth = self.imageWidth * scale
  local scaledImageHeight = self.imageHeight * scale

  if width and height then
    -- scale is getting capped to what width and height actually give us
    self.scale = math.min(self.width / scaledImageWidth, self.height / scaledImageHeight)
  else
    -- there are no size limits, set the size based on scale
    self.width = scaledImageWidth
    self.height = scaledImageHeight
    self.scale = scale
  end
end

function ImageContainer:onResize()
  self.scale = math.min(self.width / self.imageWidth, self.height / self.imageHeight)
end

function ImageContainer:drawSelf()
  love.graphics.draw(self.image, self.x, self.y, 0, self.scale, self.scale)

  if self.drawBorders then
    -- border is just drawn on top, not around
    love.graphics.setColor(self.outlineColor)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return ImageContainer

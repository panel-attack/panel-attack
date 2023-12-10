local class = require("class")
local UiElement = require("ui.UIElement")

local ImageContainer = class(function(self, options)
  self.image = options.image
  if options.aspectRatio then
    self.aspectRatio = options.aspectRatio
  else
    local x, y = self.image:getDimensions()
    self.aspectRatio = {x = x, y = y}
  end
  self.drawBorders = options.drawBorders or false
  self.outlineColor = options.outlineColor or {1, 1, 1, 1}
end, UiElement)

function ImageContainer:setImage(image, aspectRatio)
  self.image = image
  if aspectRatio then
    self.aspectRatio = aspectRatio
  else
    local x, y = self.image:getDimensions()
    self.aspectRatio = {x = x, y = y}
  end
end

function ImageContainer:drawSelf()
  local imageWidth, imageHeight = self.image:getDimensions()
  local width, height = self.width, self.height
  if self.drawBorders then
    love.graphics.setColor(self.outlineColor)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
    width = width - 2
    height = height - 2
  end

  local ratioX = width / self.aspectRatio.x
  local ratioY = height / self.aspectRatio.y
  local containerRatio = math.min(ratioX, ratioY)
  ratioX = imageWidth / self.aspectRatio.x
  ratioY = imageHeight / self.aspectRatio.y

  love.graphics.draw(self.image, self.x, self.y, 0, containerRatio * ratioX,
                     containerRatio * ratioY)

end

return ImageContainer

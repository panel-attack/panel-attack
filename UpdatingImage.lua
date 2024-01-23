
local logger = require("logger")

-- A image that can update allowing it to do various things like tile and animate.
UpdatingImage =
  class(
  function(self, image, tiled, speedX, speedY, width, height)
    assert(image ~= nil)
    self.image = image
    self.tiled = tiled
    self.image:setWrap("repeat", "repeat")
    self.speedX = speedX or 0
    self.speedY = speedY or 0
    self.width = width or self.image:getWidth()
    self.height = height or self.image:getHeight()
    self.totalTime = 0
    self.quad = nil
    if self.tiled then
      -- note how the Quad's width and height are larger than the image width and height.
      self.quad = GraphicsUtil:newRecycledQuad(0, 0, self.width, self.height, self.image:getDimensions())
    end
  end
)

function UpdatingImage:update(dt)
  self.totalTime = self.totalTime + dt
  if self.tiled then
    local x = math.floor(self.totalTime * self.speedX)
    local y = math.floor(self.totalTime * -self.speedY)
    self.quad:setViewport(x, y, self.width, self.height, self.image:getDimensions())
  end
end

function UpdatingImage:draw()
  local x_scale = 1
  local y_scale = 1
  if not self.tiled then   
    x_scale = self.width / self.image:getWidth()
    y_scale = self.height / self.image:getHeight()
    love.graphics.draw(self.image, 0, 0, 0, x_scale, y_scale)
  else
    love.graphics.draw(self.image, self.quad, 0, 0, 0, x_scale, y_scale)
  end
end

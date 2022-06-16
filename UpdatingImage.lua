
local logger = require("logger")

-- A image that can update allowing it to do various things like tile and animate.
UpdatingImage =
  class(
  function(self, image, tiled, speedX, speedY, width, height)
    assert(image ~= nil)
    self.image = image
    self.tiled = tiled
    self.image:setWrap("repeat", "repeat")
    self.image:setFilter("linear", "linear")
    self.speedX = speedX or 0
    self.speedY = speedY or 0
    self.width = width or self.image:getWidth()
    self.height = height or self.image:getHeight()
    self.totalTime = 0
  end
)

function UpdatingImage:update(dt)
  self.totalTime = self.totalTime + dt
end

function UpdatingImage:draw()
  local x = math.floor(self.totalTime * self.speedX)
  local y = math.floor(self.totalTime * -self.speedY)

  -- note how the Quad's width and height are larger than the image width and height.
  local bg_quad = love.graphics.newQuad(x, y, self.width, self.height, self.image:getDimensions())

  local scale = 1
  if not self.tiled then   
    scale = self.width / math.max(self.image:getWidth(), self.image:getHeight()) -- keep image ratio
  end
  gfx_q:push({love.graphics.draw, {self.image, bg_quad, 0, 0, 0, scale, scale}})
end

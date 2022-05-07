
local logger = require("logger")

-- A Tiling Image tiles as big as you make it, and can optionally scroll
TilingImage =
  class(
  function(self, image, speedX, speedY, width, height)
    assert(image ~= nil)
    self.image = image
    self.image:setWrap("repeat", "repeat")
    self.image:setFilter("linear", "linear")
    self.speedX = speedX or 0
    self.speedY = speedY or 0
    self.width = width or self.image:getWidth()
    self.height = height or self.image:getHeight()
    self.totalTime = 0
  end
)

function TilingImage:update(dt)
    self.totalTime = self.totalTime + dt
end

function TilingImage:draw()
    local x = math.floor(self.totalTime * self.speedX)
    local y = math.floor(self.totalTime * -self.speedY)

    -- note how the Quad's width and height are larger than the image width and height.
    local bg_quad = love.graphics.newQuad(x, y, self.width, self.height, self.image:getWidth(), self.image:getHeight())

    gfx_q:push({love.graphics.draw, {self.image, bg_quad, 0, 0}})
  end

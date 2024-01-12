local class = require("class")
local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")
local touchable = require("ui.Touchable")

--@module Button
local Button = class(
  function(self, options)
    self.backgroundColor = options.backgroundColor or {.3, .3, .3, .7}
    self.outlineColor = options.outlineColor or {.5, .5, .5, .7}

    -- callbacks
    self.onClick = options.onClick or function()
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
    end
    self.onMouseDown = options.onMouseDown or function() end
    self.onMousePressed = options.onMousePressed or function()
      local screenX, screenY = self:getScreenPos()
      GAME.gfx_q:push({love.graphics.setColor, {self.backgroundColor[1], self.backgroundColor[2], self.backgroundColor[3], 1}})
      GAME.gfx_q:push({love.graphics.rectangle, {"fill", screenX, screenY, self.width, self.height}})
      GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
    end
    self.onMouseUp = options.onMouseUp or function() end

    touchable(self)

    self.TYPE = "Button"
  end,
  UIElement
)

function Button:onTouch(x, y)
  self.backgroundColor[4] = 1
end

function Button:onRelease(x, y)
  self.backgroundColor[4] = 0.7
  if self:inBounds(x, y) then
    self:onClick()
  end
end

function Button:drawBackground()
  if self.backgroundColor[4] > 0 then
    love.graphics.setColor(self.backgroundColor)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function Button:drawOutline()
  love.graphics.setColor(self.outlineColor)
  love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
  love.graphics.setColor(1, 1, 1, 1)
end

function Button:drawSelf()
  self:drawBackground()
  self:drawOutline()
end

return Button
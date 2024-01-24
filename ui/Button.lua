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

    touchable(self)

    self.TYPE = "Button"
  end,
  UIElement
)

function Button:onTouch(x, y)
  self.backgroundColor[4] = 1
end

function Button:onRelease(x, y, timeHeld)
  self.backgroundColor[4] = 0.7
  if self:inBounds(x, y) then
    -- first argument non-self of onClick is the input source to accomodate inputs via controllers from different players
    self:onClick(nil, timeHeld)
  end
end

function Button:drawBackground()
  if self.backgroundColor[4] > 0 then
    GraphicsUtil.setColor(self.backgroundColor)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

function Button:drawOutline()
  GraphicsUtil.setColor(self.outlineColor)
  love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Button:drawSelf()
  self:drawBackground()
  self:drawOutline()
end

return Button
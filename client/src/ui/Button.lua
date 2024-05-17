local class = require("class")
local UIElement = require("ui.UIElement")
local GraphicsUtil = require("graphics_util")
local input = require("inputManager")

--@module Button
local Button = class(
  function(self, options)
    self.backgroundColor = options.backgroundColor or {.3, .3, .3, .7}
    self.outlineColor = options.outlineColor or {.5, .5, .5, .7}

    -- callbacks
    self.onClick = options.onClick or function()
      GAME.theme:playValidationSfx()
    end

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
    self:onClick(input.mouse, timeHeld)
  end
end

function Button:receiveInputs(input)
  if input.isDown["MenuSelect"] then
    self:onClick(input)
  elseif input.isDown["MenuEsc"] then
    self:onClick(input)
  end
end

function Button:drawBackground()
  if self.backgroundColor[4] > 0 then
    GraphicsUtil.setColor(self.backgroundColor)
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

function Button:drawOutline()
  GraphicsUtil.setColor(self.outlineColor)
  GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Button:drawSelf()
  self:drawBackground()
  self:drawOutline()
end

return Button
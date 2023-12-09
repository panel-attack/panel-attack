local class = require("class")
local UIElement = require("ui.UIElement")
local buttonManager = require("ui.buttonManager")
local GraphicsUtil = require("graphics_util")

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

    buttonManager.buttons[self.id] = self.isVisible and self or nil
    self.TYPE = "Button"
  end,
  UIElement
)

function Button:setVisibility(isVisible)
  buttonManager.buttons[self.id] = isVisible and self or nil
  UIElement.setVisibility(self, isVisible)
end

function Button:isSelected(x, y)
  local screenX, screenY = self:getScreenPos()
  return x > screenX and x < screenX + self.width and y > screenY and y < screenY + self.height
end

function Button:drawBackground(screenX, screenY)
  if self.backgroundColor[4] > 0 then
    if GAME.isDrawing then
      love.graphics.setColor(self.backgroundColor)
      love.graphics.rectangle("fill", screenX, screenY, self.width, self.height)
      love.graphics.setColor(1, 1, 1, 1)
    else
      GAME.gfx_q:push({love.graphics.setColor, self.backgroundColor})
      GAME.gfx_q:push({love.graphics.rectangle, {"fill", screenX, screenY, self.width, self.height}})
      GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
    end
  end
end

function Button:drawOutline(screenX, screenY)
  if GAME.isDrawing then
    love.graphics.setColor(self.outlineColor)
    love.graphics.rectangle("line", screenX, screenY, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
  else
    GAME.gfx_q:push({love.graphics.setColor, self.outlineColor})
    GAME.gfx_q:push({love.graphics.rectangle, {"line", screenX, screenY, self.width, self.height}})
    GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  end
end

function Button:draw()
  if not self.isVisible then
    return
  end

  local screenX, screenY = self:getScreenPos()

  self:drawBackground(screenX, screenY)
  self:drawOutline(screenX, screenY)

  -- draw children
  self:drawChildren()
end

return Button
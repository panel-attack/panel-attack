local class = require("class")
local UIElement = require("ui.UIElement")
local buttonManager = require("ui.buttonManager")
local GraphicsUtil = require("graphics_util")

--@module Button
local Button = class(
  function(self, options)
    self.image = options.image
    self.backgroundColor = options.backgroundColor or {.3, .3, .3, .7}
    self.outlineColor = options.outlineColor or {.5, .5, .5, .7}
    
    -- text alignments settings
    -- must be one of the following values:
    -- left, right, center
    self.halign = options.halign or "center"
    self.valign = options.valign or "center"
    
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
    
    -- text field is set in base class (UIElement)
    local textWidth, textHeight = self.text:getDimensions()
    -- stretch to fit text
    self.width = math.max(textWidth + 15, self.width)
    self.height = math.max(textHeight + 6, self.height)
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

function Button:draw()
  if not self.isVisible then
    return
  end

  local screenX, screenY = self:getScreenPos()
  
  GAME.gfx_q:push({love.graphics.setColor, self.outlineColor})
  GAME.gfx_q:push({love.graphics.rectangle, {"line", screenX, screenY, self.width, self.height}})
  if self.image then
    GAME.gfx_q:push({love.graphics.draw, {self.image, screenX + 1, screenY + 1, 0, (self.width - 2) / self.image:getWidth(), (self.height - 2) / self.image:getHeight()}})
  else
    GAME.gfx_q:push({love.graphics.setColor, self.backgroundColor})
    GAME.gfx_q:push({love.graphics.rectangle, {"fill", screenX, screenY, self.width, self.height}})
  end
  
  local textWidth, textHeight = self.text:getDimensions()
  local xAlignments = {
    center = {self.width / 2, textWidth / 2},
    left = {0, 0},
    right = {self.width, textWidth},
  }
  local yAlignments = {
    center = {self.height / 2, textHeight / 2},
    top = {0, 0},
    bottom = {self.height, textHeight},
  }
  local xPosAlign, xOffset = unpack(xAlignments[self.halign])
  local yPosAlign, yOffset = unpack(yAlignments[self.valign])
  
  GraphicsUtil.drawClearText(self.text, screenX + xPosAlign, screenY + yPosAlign, xOffset, yOffset)
  
  -- draw children
  UIElement.draw(self)
end

return Button
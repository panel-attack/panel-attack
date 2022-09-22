local class = require("class")
local UIElement = require("ui.UIElement")
local sliderManager = require("ui.sliderManager")
local util = require("util")

--@module Slider
local Slider = class(
  function(self, options)
    self.min = options.min or 1
    self.max = options.max or 99
    self.value = options.value and util.clamp(self.min, options.value, self.max) or math.floor((self.max - self.min) / 2)
    -- pixels per value change
    self.tickLength = options.tickLength or 1
    self.onValueChange = options.onValueChange or function() end
    
    self.minText = love.graphics.newText(love.graphics.getFont(), self.min)
    self.maxText = love.graphics.newText(love.graphics.getFont(), self.max)
    self.valueText = love.graphics.newText(love.graphics.getFont(), self.value)
    
    sliderManager.sliders[self.id] = self.isVisible and self or nil
    self.TYPE = "Slider"
  end,
  UIElement
)

local xOffset = 10
local yOffset = 15

function Slider:setVisibility(isVisible)
  sliderManager.sliders[self.id] = isVisible and self or nil
  UIElement.setVisibility(self, isVisible)
end

function Slider:isSelected(x, y)
  local screenX, screenY = self:getScreenPos()
  return x >= screenX + xOffset and x <= screenX + xOffset + (self.max - self.min + 1) * self.tickLength and y >= screenY + yOffset and y <= screenY + yOffset + 15
end

function Slider:setValueFromPos(x)
  local screenX, screenY = self:getScreenPos()
  self:setValue(math.floor((x - (screenX + xOffset)) / self.tickLength) + self.min + 1)
end

function Slider:setValue(value)
  local prevValue = self.value
  self.value = util.clamp(self.min, value, self.max)
  self.valueText = love.graphics.newText(love.graphics.getFont(), self.value)
  if self.value ~= prevValue then
    self:onValueChange()
  end
end

function Slider:draw()
  if not self.isVisible then
    return
  end

  local screenX, screenY = self:getScreenPos()
  
  local dark_gray = .3
  local light_gray = .5
  local alpha = .7
  GAME.gfx_q:push({love.graphics.setColor, {light_gray, light_gray, light_gray, alpha}})
  GAME.gfx_q:push({love.graphics.rectangle, {"fill", screenX + xOffset, screenY + yOffset, (self.max - self.min + 1) * self.tickLength, 5}})
  
  GAME.gfx_q:push({love.graphics.setColor, {dark_gray, dark_gray, dark_gray, .9}})
  GAME.gfx_q:push({love.graphics.circle, {"fill", screenX + xOffset + (self.value - self.min + .5) * self.tickLength, screenY + yOffset + 2.5, 7.5, 32}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  
  GAME.gfx_q:push({love.graphics.draw, {self.minText, screenX + xOffset - self.minText:getWidth() - 7, screenY + yOffset, 0, 1, 1, 0, 0}})
  GAME.gfx_q:push({love.graphics.draw, {self.maxText, screenX + xOffset + (self.max - self.min + 1) * self.tickLength + 7, screenY + yOffset, 0, 1, 1, 0, 0}})
  GAME.gfx_q:push({love.graphics.draw, {self.valueText, screenX + xOffset + (self.value - self.min + .5) * self.tickLength - 5, screenY + yOffset - 20, 0, 1, 1, 0, 0}})
  
  -- draw children
  UIElement.draw(self)
end

return Slider
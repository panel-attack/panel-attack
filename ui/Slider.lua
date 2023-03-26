local class = require("class")
local UIElement = require("ui.UIElement")
local sliderManager = require("ui.sliderManager")
local util = require("util")
local GraphicsUtil = require("graphics_util")

--@module Slider
local Slider = class(
  function(self, options)
    self.min = options.min or 1
    self.max = options.max or 99
    self.value = options.value and util.bound(self.min, options.value, self.max) or math.floor((self.max - self.min) / 2)
    -- pixels per value change
    self.tickLength = options.tickLength or 1
    self.onValueChange = options.onValueChange or function() end
    
    self.minText = love.graphics.newText(GraphicsUtil.getGlobalFont(), self.min)
    self.maxText = love.graphics.newText(GraphicsUtil.getGlobalFont(), self.max)
    self.valueText = love.graphics.newText(GraphicsUtil.getGlobalFont(), self.value)
    
    sliderManager.sliders[self.id] = self.isVisible and self or nil
    self.TYPE = "Slider"
  end,
  UIElement
)

local xOffset = 0
local yOffset = 15
local textOffset = -3
local sliderBarThickness = 5
local handleRadius = 7.5

function Slider:setVisibility(isVisible)
  sliderManager.sliders[self.id] = isVisible and self or nil
  UIElement.setVisibility(self, isVisible)
end

function Slider:isSelected(x, y)
  local screenX, screenY = self:getScreenPos()
  return x >= screenX and x <= screenX + (self.max - self.min + 1) * self.tickLength and y >= screenY + yOffset + sliderBarThickness / 2 - handleRadius and y <= screenY + yOffset + sliderBarThickness / 2 + handleRadius
end

function Slider:setValueFromPos(x)
  local screenX, screenY = self:getScreenPos()
  self:setValue(math.floor((x - screenX) / self.tickLength) + self.min)
end

function Slider:setValue(value)
  local prevValue = self.value
  self.value = util.bound(self.min, value, self.max)
  self.valueText = love.graphics.newText(GraphicsUtil.getGlobalFont(), self.value)
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
  GAME.gfx_q:push({love.graphics.rectangle, {"fill", screenX, screenY + yOffset, (self.max - self.min + 1) * self.tickLength, sliderBarThickness}})
  
  GAME.gfx_q:push({love.graphics.setColor, {dark_gray, dark_gray, dark_gray, .9}})
  GAME.gfx_q:push({love.graphics.circle, {"fill", screenX + (self.value - self.min + .5) * self.tickLength, screenY + yOffset + sliderBarThickness / 2, handleRadius, 32}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  
  local textWidth, textHeight = self.minText:getDimensions()
  GAME.gfx_q:push({love.graphics.draw, {self.minText, screenX - textWidth * .3, screenY + textOffset, 0, 1, 1, 0, 0}})
  
  textWidth, textHeight = self.maxText:getDimensions()
  GAME.gfx_q:push({love.graphics.draw, {self.maxText, screenX + (self.max - self.min + 1) * self.tickLength - textWidth, screenY + textOffset, 0, 1, 1, 0, 0}})
  
  textWidth, textHeight = self.valueText:getDimensions()
  GAME.gfx_q:push({love.graphics.draw, {self.valueText, screenX + ((self.max - self.min + 1) / 2.0) * self.tickLength - textWidth / 2, screenY + textOffset, 0, 1, 1, 0, 0}})
  
  -- draw children
  UIElement.draw(self)
end

return Slider
local class = require("class")
local slider_manager = require("ui.slider_manager")
local util = require("util")

--@module Slider
local Slider = class(
  function(self, options)
    self.id = nil -- set in the slider manager
    self.x = options.x or 0
    self.y = options.y or 0
    self.min = options.min or 1
    self.max = options.max or 99
    self.text = options.text or love.graphics.newText(love.graphics.getFont(), "Slider")
    self.is_visible = options.is_visible or options.is_visible == nil and true
    self.is_enabled = options.is_enabled or options.is_enabled == nil and true
    self.value = options.value or math.floor((self.max - self.min) / 2)
    self.tick_length = options.tick_length or 1
    self.onValueChange = options.onValueChange or function() end
    
    --local text_width, text_height = self.text:getDimensions()
    --self.width = math.max(text_width + 6, self.width)
    --self.height = math.max(text_height + 6, self.height)
    self._min_text = love.graphics.newText(love.graphics.getFont(), self.min)
    self._max_text = love.graphics.newText(love.graphics.getFont(), self.max)
    self._value_text = love.graphics.newText(love.graphics.getFont(), self.value)
    
    slider_manager.add_slider(self)
    self.TYPE = "Slider"
  end
)

local x_offset = 10
local y_offset = 15
  
function Slider:setVisibility(is_visible)
  self.is_visible = is_visible
end

function Slider:updateLabel(label) end

function Slider:remove()
  slider_manager.remove_slider(self)
end

function Slider:isSelected(x, y)
  return self.is_enabled and x >= self.x + x_offset and x <= self.x + x_offset + (self.max - self.min + 1) * self.tick_length and y >= self.y + y_offset and y <= self.y + y_offset + 15
end

function Slider:setValueFromPos(x)
  self:setValue(math.floor((x - (self.x + x_offset)) / self.tick_length) + self.min + 1)
end

function Slider:setValue(value)
  local prev_value = self.value
  self.value = util.clamp(self.min, value, self.max)
  self._value_text = love.graphics.newText(love.graphics.getFont(), self.value)
  if self.value ~= prev_value then
    self:onValueChange()
  end
end

function Slider:draw()
  local dark_gray = .3
  local light_gray = .5
  local alpha = .7
  GAME.gfx_q:push({love.graphics.setColor, {light_gray, light_gray, light_gray, alpha}})
  GAME.gfx_q:push({love.graphics.rectangle, {"fill", self.x + x_offset, self.y + y_offset, (self.max - self.min + 1) * self.tick_length, 5}})
  --GAME.gfx_q:push({love.graphics.setColor, {light_gray, light_gray, light_gray, alpha}})
  --GAME.gfx_q:push({love.graphics.rectangle, {"line", self.x, self.y, self.max - self.min, 10}})
  
  GAME.gfx_q:push({love.graphics.setColor, {dark_gray, dark_gray, dark_gray, .9}})
  GAME.gfx_q:push({love.graphics.circle, {"fill", self.x + x_offset + (self.value - self.min + .5) * self.tick_length, self.y + y_offset + 2.5, 7.5, 32}})
  GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
  
  --local text_width, text_height = self.text:getDimensions()
  GAME.gfx_q:push({love.graphics.draw, {self._min_text, self.x + x_offset - self._min_text:getWidth() - 7, self.y + y_offset, 0, 1, 1, 0, 0}})
  GAME.gfx_q:push({love.graphics.draw, {self._max_text, self.x + x_offset + (self.max - self.min + 1) * self.tick_length + 7, self.y + y_offset, 0, 1, 1, 0, 0}})
  GAME.gfx_q:push({love.graphics.draw, {self._value_text, self.x + x_offset + (self.value - self.min + .5) * self.tick_length - 5, self.y + y_offset - 20, 0, 1, 1, 0, 0}})
end

return Slider
local class = require("class")
local slider_manager = require("ui.slider_manager")
local Slider = require("ui.Slider")
local util = require("util")

--@module LevelSlider
local LevelSlider = class(
  function(self, options)
    self.id = nil -- set in the slider manager
    self.x = options.x or 0
    self.y = options.y or 0
    self.min = 1
    self.max = #themes[config.theme].images.IMG_levels
    self.tick_length = options.tick_length or 11
    self.is_visible = options.is_visible or options.is_visible == nil and true
    self.is_enabled = options.is_enabled or options.is_enabled == nil and true 
    self.value = options.value or math.floor((self.max - self.min) / 2)
    self.onValueChange = options.onValueChange or function() end
    slider_manager.add_slider(self)
    self.TYPE = "Slider"
  end,
  Slider)

function LevelSlider:isSelected(x, y)
  return self.is_enabled and x >= self.x and x <= self.x + (self.max - self.min + 1) * self.tick_length and y >= self.y and y <= self.y + self.tick_length * 2
end

function LevelSlider:draw()
  for i, level_img in ipairs(themes[config.theme].images.IMG_levels) do
    local img = i <= self.value and 
      themes[config.theme].images.IMG_levels[i] or 
      themes[config.theme].images.IMG_levels_unfocus[i]
    local width = img:getWidth()
    GAME.gfx_q:push({love.graphics.draw, {img, self.x + (i - 1) * self.tick_length, self.y, 0, self.tick_length / img:getWidth(), self.tick_length / img:getHeight(), 0, 0}})
  end
  local cursor_image = themes[config.theme].images.IMG_level_cursor
  -- self.tick_length / cursor_image:getWidth(), self.tick_length / cursor_image:getHeight()
  GAME.gfx_q:push({love.graphics.draw, {cursor_image, self.x + (self.value - 1 + .5) * self.tick_length, self.y + self.tick_length, 0, 1, 1, cursor_image:getWidth() / 2, 0}})
end

return LevelSlider
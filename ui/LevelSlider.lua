local class = require("class")
local Slider = require("ui.Slider")
local util = require("util")

--@module LevelSlider
local LevelSlider = class(
  function(self, options)
    self.min = 1
    self.max = #themes[config.theme].images.IMG_levels
    self.value = options.value or math.floor((self.max - self.min) / 2)
    self.tickLength = 11
  end,
  Slider)

function LevelSlider:isSelected(x, y)
  local screenX, screenY = self:getScreenPos()
  return x >= screenX and x <= screenX + (self.max - self.min + 1) * self.tickLength and y >= screenY and y <= screenY + self.tickLength * 2
end

function LevelSlider:draw()
  local screenX, screenY = self:getScreenPos()
  for i, level_img in ipairs(themes[config.theme].images.IMG_levels) do
    local img = i <= self.value and 
      themes[config.theme].images.IMG_levels[i] or 
      themes[config.theme].images.IMG_levels_unfocus[i]
    local width = img:getWidth()
    GAME.gfx_q:push({love.graphics.draw, {img, screenX + (i - 1) * self.tickLength, screenY, 0, self.tickLength / img:getWidth(), self.tickLength / img:getHeight(), 0, 0}})
  end
  local cursor_image = themes[config.theme].images.IMG_level_cursor
  GAME.gfx_q:push({love.graphics.draw, {cursor_image, screenX + (self.value - 1 + .5) * self.tickLength, screenY + self.tickLength, 0, 1, 1, cursor_image:getWidth() / 2, 0}})
end

return LevelSlider
local class = require("class")
local UIElement = require("ui.UIElement")
local Slider = require("ui.Slider")
local util = require("util")

--@module LevelSlider
local LevelSlider = class(
  function(self, options)
    self.min = 1
    self.max = #themes[config.theme].images.IMG_levels
    self.value = options.value and util.bound(self.min, options.value, self.max) or 5
    -- pixels per value change
    self.tickLength = options.tickLength or 11

    self.width = self.max * self.tickLength
    self.height = self.tickLength
  end,
  Slider)

function LevelSlider:isSelected(x, y)
  local screenX, screenY = self:getScreenPos()
  return x >= screenX and x <= screenX + (self.max - self.min + 1) * self.tickLength and y >= screenY and y <= screenY + self.tickLength * 2
end

function LevelSlider:drawSelf()
  for i, level_img in ipairs(themes[config.theme].images.IMG_levels) do
    local img = i <= self.value and level_img or
      themes[config.theme].images.IMG_levels_unfocus[i]
    love.graphics.draw(img, self.x + (i - 1) * self.tickLength, self.y, 0, self.tickLength / img:getWidth(), self.tickLength / img:getHeight(), 0, 0)
  end
  local cursor_image = themes[config.theme].images.IMG_level_cursor
  love.graphics.draw(cursor_image, self.x + (self.value - 1 + .5) * self.tickLength, self.y + self.tickLength, 0, 1, 1, cursor_image:getWidth() / 2, 0)
end

return LevelSlider
local class = require("common.lib.class")
local Slider = require("client.src.ui.Slider")
local util = require("common.lib.util")
local GraphicsUtil = require("client.src.graphics.graphics_util")

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

function LevelSlider:onTouch(x, y)
  self:setValueFromPos(x)
end

function LevelSlider:onDrag(x, y)
  self:setValueFromPos(x)
end

function LevelSlider:drawSelf()
  for i, level_img in ipairs(themes[config.theme].images.IMG_levels) do
    local img = i <= self.value and level_img or
      themes[config.theme].images.IMG_levels_unfocus[i]
      GraphicsUtil.draw(img, self.x + (i - 1) * self.tickLength, self.y, 0, self.tickLength / img:getWidth(), self.tickLength / img:getHeight(), 0, 0)
  end
  local cursor_image = themes[config.theme].images.IMG_level_cursor
  GraphicsUtil.draw(cursor_image, self.x + (self.value - 1 + .5) * self.tickLength, self.y + self.tickLength, 0, 1, 1, cursor_image:getWidth() / 2, 0)
end

return LevelSlider
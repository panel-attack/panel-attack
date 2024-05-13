local class = require("class")
local Transition = require("scenes.Transitions.Transition")
local consts = require("consts")
local GraphicsUtil = require("graphics_util")

local BlackFadeTransition = class(function(transition, startTime, duration,  oldScene, newScene, easing)
  transition.easing = easing
end,
Transition)

function BlackFadeTransition:updateScenes(dt)
  if self.progress >= 0.5 then
    self.newScene:update(dt)
  end
end

function BlackFadeTransition:draw()
  local alpha
  if self.progress < 0.5 then
    alpha = self.easing(self.progress * 2)
    self.oldScene:draw()
  else
    alpha = self.easing(self.progress * 2 - (self.progress - 0.5) * 2)
    self.newScene:draw()
  end
  GraphicsUtil.setColor(0, 0, 0, alpha)
  GraphicsUtil.drawRectangle("fill", 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

return BlackFadeTransition
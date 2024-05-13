local class = require("class")
local consts = require("consts")
local GraphicsUtil = require("graphics_util")

-- a transition that displays an intermediary loading screen while the match of the newScene is catching up
-- once the match caught up, the transition ends
local CatchUpTransition = class(function(transition, oldScene, newScene)
  assert(newScene.match)
  transition.progress = 0
  transition.timePassed = 0
  transition.oldScene = oldScene
  transition.newScene = newScene
  transition.match = newScene.match
end)

function CatchUpTransition:update(dt)
  self.timePassed = self.timePassed + dt
  if not self.match.P1.play_to_end then
    self.progress = 1
    self.newScene:onGameStart()
  else
    self.progress = self.match.P1.clock / #self.match.P1.confirmedInput
  end
  local t = love.timer.getTime()
  local shouldCatchUp = ((self.match.P1 and self.match.P1.play_to_end) or (self.match.P2 and self.match.P2.play_to_end))
  -- spend 90% of frame time on catchup
  -- since we're not drawing anything big that should be realistic for catching ASAP
  local hasTimeLeft = function() return love.timer.getTime() < t + 0.9 * consts.FRAME_RATE end
  while shouldCatchUp and hasTimeLeft() do
    self.match:run()
  end
end

function CatchUpTransition:draw()
  GraphicsUtil.setColor(1, 1, 1, 1)
  GraphicsUtil.drawRectangle("line", consts.CANVAS_WIDTH / 4 - 5, consts.CANVAS_HEIGHT / 2 - 25, consts.CANVAS_WIDTH / 2 + 10, 50)
  GraphicsUtil.drawRectangle("fill", consts.CANVAS_WIDTH / 4, consts.CANVAS_HEIGHT / 2 - 20, consts.CANVAS_WIDTH / 2 * self.progress, 40)
  GraphicsUtil.printf("Catching up: " .. self.match.P1.clock .. " out of " .. #self.match.P1.confirmedInput .. " frames", 0, 500, consts.CANVAS_WIDTH, "center")
end

return CatchUpTransition
local class = require("class")
local consts = require("consts")

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
    self.progress = 2
  else
    self.progress = self.match.P1.clock / #self.match.P1.confirmedInput
  end
  local t = love.timer.getTime()
    -- spend 90% of frame time on catchup
    -- since we're not drawing anything big that should be realistic for catching ASAP
    while love.timer.getTime() < t + 0.9*dt and ((self.S1 and self.S1.play_to_end) or (self.S2 and self.S2.play_to_end)) do
      self.match:run()
    end
end

function CatchUpTransition:draw()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("line", consts.CANVAS_WIDTH / 4 - 5, consts.CANVAS_HEIGHT / 2 - 25, consts.CANVAS_WIDTH / 2 + 5, 50)
  love.graphics.rectangle("fill", consts.CANVAS_WIDTH / 4, consts.CANVAS_HEIGHT / 2 - 20, consts.CANVAS_WIDTH / 2 * self.progress, 40)
  gprintf("Catching up: " .. #self.match.P1.confirmedInput - self.match.P1.clock .. " frames to go", 0, 500, consts.CANVAS_WIDTH, "center")
end

return CatchUpTransition
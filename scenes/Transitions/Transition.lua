local class = require("class")
local UiElement = require("ui.UIElement")
local consts = require("consts")

-- A transition, or more specifically a scene transition represents an object that handles going from one scene to the next
-- For the duration of handover, the transition is responsible for handling both update and draw calls on the scenes
-- (the general rule of thumb however is that you never want to update the old scene once the transition started, only the draw)
local Transition = class(function(transition, startTime, duration, oldScene, newScene)
  transition.startTime = startTime
  transition.timePassed = 0
  transition.duration = duration
  transition.progress = 0
  transition.oldScene = oldScene
  transition.newScene = newScene
  transition.uiRoot = UiElement({x = 0, y = 0, width = consts.CANVAS_WIDTH, height = consts.CANVAS_HEIGHT})

end)

function Transition:update(dt)
  self.timePassed = self.timePassed + dt
  self.progress = self.timePassed / self.duration
  self:updateScenes(dt)
end

function Transition:updateScenes(dt)
  -- error("A transition should probably implement an updateScenes function")
end

function Transition:draw()
  error("A transition must implement a draw function")
end

return Transition
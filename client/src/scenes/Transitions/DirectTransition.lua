local class = require("common.lib.class")
local Transition = require("client.src.scenes.Transitions.Transition")

local DirectTransition = class(function(transition, startTime, duration)
  transition.duration = tonumber(1e-12)
end,
Transition)

function DirectTransition:draw()
  if self.oldScene and self.oldScene.draw then
    self.oldScene:draw()
  end
end

return DirectTransition

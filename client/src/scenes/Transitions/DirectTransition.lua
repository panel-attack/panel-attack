local class = require("common.lib.class")
local Transition = require("client.src.scenes.Transitions.Transition")

local DirectTransition = class(function(transition, startTime, duration)
  transition.duration = tonumber(1e-12)
end,
Transition)

function DirectTransition:draw()
  self.oldScene:draw()
end

return DirectTransition

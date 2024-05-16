local class = require("class")
local Transition = require("scenes.Transitions.Transition")
local consts = require("consts")
local GraphicsUtil = require("graphics_util")

local DirectTransition = class(function(transition, startTime, duration, oldScene, newScene)
end,
Transition)

function DirectTransition:updateScenes(dt)
  self.newScene:update(dt)
end

function DirectTransition:draw()
  self.newScene:draw()
end

return DirectTransition

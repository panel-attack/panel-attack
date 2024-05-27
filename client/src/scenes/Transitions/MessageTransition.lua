local class = require("common.lib.class")
local Transition = require("client.src.scenes.Transitions.Transition")
local Label = require("client.src.ui.Label")
local input = require("common.lib.inputManager")

local MessageTransition = class(function(transition, startTime, duration, message)
  transition.message = message
  transition.label = Label({text = message, hAlign = "center", vAlign = "center"})
  transition.uiRoot:addChild(transition.label)
end, Transition)

function MessageTransition:updateScenes(dt)
  if self.progress > 0.2 then
    -- give an avenue for early skip
    if input.isDown["MenuSelect"] or input.isDown["MenuEsc"] then
      self.progress = 1
    end
  end
end

function MessageTransition:draw()
  self.uiRoot:draw()
end

return MessageTransition

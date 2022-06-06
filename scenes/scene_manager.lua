local consts = require("consts")
local socket = require("socket")
local transition_utils = require("scenes.transition_utils")

--@module scene_manager
local scene_manager = {
  active_scene = nil,
  next_scene = nil,
  is_transitioning = false
}

local scenes = {}
local transition_co = nil
local transition_type = "fade"
local transitions = {
  none = {
    pre_load_transition = function() end,
    post_load_transition = function() end
  },
  fade = {
    pre_load_transition = function() transition_utils.fade(0, 1, .2) end,
    post_load_transition = function() transition_utils.fade(1, 0, .2) end
  }
}

function scene_manager:switchScene(scene_name, scene_params)
  transition_co = coroutine.create(function() self:transitionFn(scene_params) end)
  self.next_scene = scenes[scene_name]
  self.is_transitioning = true
end

function scene_manager:transitionFn(scene_params)
  transitions[transition_type].pre_load_transition()
  
  if scene_manager.active_scene then
    self.active_scene:unload()
  end
  
  if self.next_scene then
    self.next_scene:load(scene_params)
    self.active_scene = self.next_scene
    GAME.rich_presence:setPresence(nil, self.next_scene.name, true)
  else
    self.active_scene = nil
  end
  
  transitions[transition_type].post_load_transition()
  
  self.is_transitioning = false
end

function scene_manager:transition()
  coroutine.resume(transition_co)
end

function scene_manager:addScene(scene)
  scenes[scene.name] = scene
end

return scene_manager
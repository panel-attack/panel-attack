local consts = require("consts")
local socket = require("socket")

--@module scene_manager
local scene_manager = {
  active_scene = nil,
  next_scene = nil,
  is_transitioning = false
}

local scenes = {}
local transition_co = nil
function scene_manager:switchScene(scene_name)
  transition_co = coroutine.create(function() self:transitionFn() end)
  self.next_scene = scenes[scene_name]
  self.is_transitioning = true
end

function scene_manager:transitionFn()
  for alpha = 0, 1, .01 do
    GAME.gfx_q:push({love.graphics.setColor, {0, 0, 0, alpha}})
    GAME.gfx_q:push({love.graphics.rectangle, {"fill", 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT}})
    GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
    coroutine.yield()
  end
  
  if scene_manager.active_scene then
    self.active_scene:unload()
  end
  
  if self.next_scene then
    self.next_scene:load()
    self.active_scene = self.next_scene
  else
    self.active_scene = nil
  end
  
  for alpha = 1, 0, -.01 do
    GAME.gfx_q:push({love.graphics.setColor, {0, 0, 0, alpha}})
    GAME.gfx_q:push({love.graphics.rectangle, {"fill", 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT}})
    GAME.gfx_q:push({love.graphics.setColor, {1, 1, 1, 1}})
    coroutine.yield()
  end
  self.is_transitioning = false
end

function scene_manager:transition()
  coroutine.resume(transition_co)
end

function scene_manager:addScene(scene)
  scenes[scene.name] = scene
end

return scene_manager
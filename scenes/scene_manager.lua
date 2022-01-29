--@module scene_manager
local scene_manager = {
  active_scene = nil
}

function scene_manager:switchScene(scene)
  if scene_manager.active_scene then
    self.active_scene:unload()
  end

  if scene then
    scene:load()
    self.active_scene = scene
  else
    self.active_scene = nil
  end
end

return scene_manager
local Easings = require("Easings")
local BlackFadeTransition = require("scenes.Transitions.BlackFadeTransition")

--@module sceneManager
-- Contains all initialized scenes and handles scene transitions 
local sceneManager = {
  activeScene = nil,
  nextSceneName = nil,
  transition = nil,
  scenes = {}
}

function sceneManager:switchToScene(newScene, transition)
  GAME.rich_presence:setPresence(nil, newScene.name, true)
  if not transition or type(transition) ~= "table" then
    self.transition = BlackFadeTransition(GAME.timer, config.doFadeTransitions and 0.4 or 0.0, self.activeScene, newScene, Easings.linear)
  else
    self.transition = transition
  end
end

function sceneManager:addScene(scene)
  self.scenes[scene.name] = scene
end

function sceneManager:createScene(sceneName, sceneParams)
  if not self.scenes[sceneName] then
    self.scenes[sceneName] = require("scenes." .. sceneName)
  end
  return self.scenes[sceneName](sceneParams)
end

function sceneManager:draw()
  if self.transition then
    self.transition:draw()
  else
    if not self.activeScene then
      error("There better be an active scene. We bricked.")
    end
    self.activeScene:draw()
  end
end

function sceneManager:update(dt)
  if self.transition then
    self.transition:update(dt)

    if self.transition.progress >= 1 then
      -- doing this here again for good measure
      -- more complex transitions might find out a transition can't go through and switch oldScene and newScene to go back instead
      self.activeScene = self.transition.newScene
      self.transition = nil
    end
  else
    if not self.activeScene then
      error("There better be an active scene. We bricked.")
    end
    self.activeScene:update(dt)
  end
end

return sceneManager

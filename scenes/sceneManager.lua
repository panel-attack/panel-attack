local Easings = require("Easings")
local BlackFadeTransition = require("scenes.Transitions.BlackFadeTransition")

--@module sceneManager
-- Contains all initialized scenes and handles scene transitions 
local sceneManager = {
  activeScene = nil,
  nextSceneName = nil,
  transition = nil
}

local scenes = {}

function sceneManager:switchToScene(sceneName, sceneParams, transition)
  GAME.rich_presence:setPresence(nil, sceneName, true)
  if not scenes[sceneName] then
    scenes[sceneName] = require("scenes." .. sceneName)
  end
  local newScene = scenes[sceneName](sceneParams or {})
  if not transition or type(transition) ~= "table" then
    self.transition = BlackFadeTransition(GAME.timer, 0.4, self.activeScene, newScene, Easings.linear)
  else
    self.transition = transition
    self.transition.oldScene = self.activeScene
    self.transition.newScene = newScene
  end
end

function sceneManager:addScene(scene)
  scenes[scene.name] = scene
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

    if self.transition.progress > 1 then
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
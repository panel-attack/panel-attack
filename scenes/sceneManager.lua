local transitionUtils = require("scenes.transitionUtils")

--@module sceneManager
-- Contains all initialized scenes and handles scene transitions 
local sceneManager = {
  activeScene = nil,
  nextSceneName = nil,
  isTransitioning = false
}

local scenes = {}
local transitionCo = nil
local defaultTransition = "none"
local transitionType = "none"
local transitions = {
  none = {
    preLoadTransition = function() end,
    postLoadTransition = function() end
  },
  fade = {
    preLoadTransition = function() transitionUtils.fade(0, 1, .2) end,
    postLoadTransition = function() transitionUtils.fade(1, 0, .2) end
  }
}

function sceneManager:switchToScene(sceneName, sceneParams, transition)
  transitionType = transition or defaultTransition
  transitionCo = coroutine.create(function() self:transitionFn(sceneParams) end)
  self.nextSceneName = sceneName
  self.isTransitioning = true
end

function sceneManager:transitionFn(sceneParams)
  transitions[transitionType].preLoadTransition()
  
  if self.activeScene then
    self.activeScene:unload()
  end
  
  if self.nextSceneName then
    -- Looks up the class for {self.nextSceneName} and call it's constructor
    self.activeScene = scenes[self.nextSceneName](sceneParams or {})
    GAME.rich_presence:setPresence(nil, self.nextSceneName, true)
  else
    self.activeScene = nil
  end
  
  transitions[transitionType].postLoadTransition()
  
  self.isTransitioning = false
end

function sceneManager:transition()
  coroutine.resume(transitionCo)
end

function sceneManager:addScene(scene)
  scenes[scene.name] = scene
end

return sceneManager
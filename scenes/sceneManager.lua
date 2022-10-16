local consts = require("consts")
local socket = require("socket")
local transitionUtils = require("scenes.transitionUtils")

--@module sceneManager
local sceneManager = {
  activeScene = nil,
  nextScene = nil,
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
  self.nextScene = scenes[sceneName]
  self.isTransitioning = true
end

function sceneManager:transitionFn(sceneParams)
  transitions[transitionType].preLoadTransition()
  
  if self.activeScene then
    self.activeScene:unload()
  end
  
  if self.nextScene then
    self.nextScene:load(sceneParams)
    self.activeScene = self.nextScene
    GAME.rich_presence:setPresence(nil, self.nextScene.name, true)
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
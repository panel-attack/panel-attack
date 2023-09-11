local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local class = require("class")

--@module SceneTemplate
-- Skeleton for building a scene, to be copied into a new file and filled
local SceneTemplate = class(
  function (self, sceneParams)
    self.backgroundImg = nil
    self:load(sceneParams)
  end,
  Scene
)

SceneTemplate.name = "SceneTemplate"
sceneManager:addScene(SceneTemplate)

function SceneTemplate:load(sceneParams)
  
end

function SceneTemplate:drawBackground()
  self.backgroundImg:draw()
end

function SceneTemplate:update(dt)
  self.backgroundImg:update(dt)
end

function SceneTemplate:unload()
  
end

return SceneTemplate
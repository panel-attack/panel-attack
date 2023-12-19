local class = require("class")
local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")

local StartUp = class(function(scene, sceneParams)
  scene.setupRoutine = coroutine.create(sceneParams.setupRoutine)
  scene.message = "Startup"
end, Scene)

StartUp.name = "StartUp"
sceneManager:addScene(StartUp)

function StartUp:update(dt)
  local success, status = coroutine.resume(self.setupRoutine, GAME)
  if success then
    if status then
      self.message = status
    end
  else
    GAME.crashTrace = debug.traceback(self.setupRoutine)
    error(status)
  end

  if coroutine.status(self.setupRoutine) == "dead" then
    if themes[config.theme].images.bg_title then
      sceneManager:switchToScene("TitleScreen")
    else
      sceneManager:switchToScene("MainMenu")
    end
  end
end

function StartUp:drawLoadingString(loadingString)
  local textHeight = 40
  local x = 0
  local y = canvas_height / 2 - textHeight / 2
  love.graphics.setFont(get_font_delta(10))
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf(loadingString, x, y, canvas_width, "center", 0, 1)
  love.graphics.setFont(GraphicsUtil.getGlobalFont())
end

function StartUp:draw()
  self:drawLoadingString(self.message)
end

return StartUp

local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local sceneManager = require("client.src.scenes.sceneManager")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")

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
      local titleScreen = require("client.src.scenes.TitleScreen")()
      sceneManager:switchToScene(titleScreen)
    else
      local mainMenu = require("client.src.scenes.MainMenu")()
      sceneManager:switchToScene(mainMenu)
    end
  end
end

function StartUp:drawLoadingString(loadingString)
  local textHeight = 40
  local x = 0
  local y = consts.CANVAS_HEIGHT / 2 - textHeight / 2
  love.graphics.setFont(GraphicsUtil.getGlobalFontWithSize(GraphicsUtil.fontSize + 10))
  GraphicsUtil.setColor(1, 1, 1, 1)
  love.graphics.printf(loadingString, x, y, consts.CANVAS_WIDTH, "center", 0, 1)
  love.graphics.setFont(GraphicsUtil.getGlobalFont())
end

function StartUp:draw()
  self:drawLoadingString(self.message)
end

return StartUp

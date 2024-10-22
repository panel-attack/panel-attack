local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")

local StartUp = class(function(scene, sceneParams)
  scene.migrationRoutine = coroutine.create(scene.migrate)
  scene.setupRoutine = coroutine.create(sceneParams.setupRoutine)
  scene.message = "Startup"
  scene.migrationPath = scene:checkIfMigrationIsPossible()

  local saveDir = love.filesystem.getSaveDirectory()

  if scene.migrationPath then
    scene.migrationMessage = "Migrating save directory" ..
            "\nOld save directory at " .. scene.migrationPath ..
            "\nNew save directory at " .. saveDir
    logger.debug(scene.migrationMessage)
  end

  love.graphics.setFont(GraphicsUtil.getGlobalFontWithSize(GraphicsUtil.fontSize + 10))
end, Scene)

StartUp.name = "StartUp"

function StartUp:update(dt)
  if self.migrationPath then
    local success, status = coroutine.resume(self.migrationRoutine, self)
    if success then
      if status then
        self.message = self.migrationMessage .. "\n" .. status
      end
    else
      GAME.crashTrace = debug.traceback(self.migrationRoutine)
      error(status)
    end
  else
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
      love.graphics.setFont(GraphicsUtil.getGlobalFont())
      -- we need the indirection for the scenes here because startup initializes localization which following scenes need
      if themes[config.theme].images.bg_title then
        GAME.navigationStack:replace(require("client.src.scenes.TitleScreen")())
      else
        GAME.navigationStack:replace(require("client.src.scenes.MainMenu")())
      end
    end
  end
end

function StartUp:drawLoadingString(loadingString)
  local textHeight = 40
  local x = 0
  local y = consts.CANVAS_HEIGHT / 2 - textHeight / 2
  GraphicsUtil.setColor(1, 1, 1, 1)
  love.graphics.printf(loadingString, x, y, consts.CANVAS_WIDTH, "center", 0, 1)
end

function StartUp:draw()
  self:drawLoadingString(self.message)
end

function StartUp:checkIfMigrationIsPossible()
  local os = love.system.getOS()
  if os == "Linux" or os == "OS X" then
    if not love.filesystem.exists("conf.json") then
      local path = love.filesystem.getAppdataDirectory()
      if path:sub(-1) ~= "/" then
        path = path .. "/"
      end
      if os == "Linux" then
        path = path .. "love/"
      elseif os == "OS X" then
        path = path .. "LOVE/"
      end
      path = path .. love.filesystem.getIdentity()
      logger.debug("Trying to mount old install under " .. path)

      if not love.filesystem.mountFullPath(path, "oldInstall") then
        -- if we couldn't mound that directory, that means there is no old install
        logger.debug("No old install found")
      else
        return path
      end
    end
  end
end

function StartUp:migrate()
  fileUtils.recursiveCopy("oldInstall", "", true)
  love.filesystem.unmountFullPath(self.migrationPath)
  self.migrationPath = nil
  self.migrationMessage = nil
  readConfigFile(config)
  love.window.updateMode(config.windowWidth, config.windowHeight,
    {
      x = config.windowX,
      y = config.windowY,
      fullscreen = config.fullscreen,
      borderless = config.borderless,
      displayindex = config.display,
      resizable = true,
    })
  love.load()
end

return StartUp

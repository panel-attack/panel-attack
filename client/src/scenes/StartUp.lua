local class = require("common.lib.class")
local Scene = require("client.src.scenes.Scene")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local TitleScreen = require("client.src.scenes.TitleScreen")
local MainMenu = require("client.src.scenes.MainMenu")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")

local StartUp = class(function(scene, sceneParams)
  scene.preloadRoutine = coroutine.create(scene.preload)
  scene.setupRoutine = coroutine.create(sceneParams.setupRoutine)
  scene.message = "Startup"
  scene.migrationPath = scene:checkIfMigrationIsPossible()

  if scene.migrationPath then
    scene.message = "Migrating save directory" ..
            "\nOld save directory at " .. love.filesystem.getRealDirectory("oldInstall") ..
            "\nNew save directory at " .. love.filesystem.getSaveDirectory()
    logger.debug(scene.message)
  end
end, Scene)

StartUp.name = "StartUp"

function StartUp:update(dt)
  if self.migrationPath then
    fileUtils.recursiveCopy("oldInstall", "")
    love.filesystem.unmountFullPath(self.migrationPath)
    self.migrationPath = nil
    readConfigFile(config)
    love.window.setMode(config.windowWidth, config.windowHeight,
      {
        x = config.windowX,
        y = config.windowY,
        fullscreen = config.fullscreen,
        borderless = config.borderless,
        displayindex = config.display
      })
    love.load()
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
      if themes[config.theme].images.bg_title then
        GAME.navigationStack:replace(TitleScreen())
      else
        GAME.navigationStack:replace(MainMenu())
      end
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

function StartUp:checkIfMigrationIsPossible()
  local os = love.system.getOS()
  if os == "Linux" or os == "OS X" then
    if not love.filesystem.exists("conf.json") then
      local path = love.filesystem.getAppdataDirectory()
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

function StartUp:preload()
  local os = love.system.getOS()
  if os == "Linux" or os == "OS X" then
    if not love.filesystem.exists("conf.json") then
      local path = love.filesystem.getRealDirectory(love.filesystem.getSaveDirectory())
      if os == "Linux" then
        path = path .. "/love/"
      elseif os == "OS X" then
        path = path .. "/LOVE/"
      end
      path = path .. love.filesystem.getIdentity()
      logger.debug("Trying to mount old install under " .. path)

      if not love.filesystem.mountFullPath(path, "oldInstall") then
        -- if we couldn't mound that directory, that means there is no old install
        logger.debug("No old install found")
      else
        self.message = "Migrating save directory" ..
            "\nOld save directory at " .. path ..
            "\nNew save directory at " .. love.filesystem.getSaveDirectory()
        coroutine.yield()
        fileUtils.recursiveCopy("oldInstall", "")
      end
    end
  end
end

return StartUp

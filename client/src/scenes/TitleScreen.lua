local Scene = require("client.src.scenes.Scene")
local sceneManager = require("client.src.scenes.sceneManager")
local consts = require("common.engine.consts")
local input = require("common.lib.inputManager")
local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

--@module titleScreen
-- The title screen scene
local TitleScreen = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_title
    self:load(sceneParams)
  end,
  Scene
)

TitleScreen.name = "TitleScreen"
sceneManager:addScene(TitleScreen)


local function titleDrawPressStart(percent)
  local textMaxWidth = consts.CANVAS_WIDTH - 40
  local textHeight = 40
  local x = (consts.CANVAS_WIDTH / 2) - (textMaxWidth / 2)
  local y = consts.CANVAS_HEIGHT * 0.75
  GraphicsUtil.printf(loc("continue_button"), x, y, textMaxWidth, "center", {1,1,1,percent}, nil, 16)
end

function TitleScreen:update(dt)
  self.backgroundImg:update(dt)
  local keyPressed = tableUtils.trueForAny(input.isDown, function(key) return key end)
  if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or keyPressed then
    GAME.theme:playValidationSfx()
    sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
  end
end

function TitleScreen:draw()
  self.backgroundImg:draw()
  titleDrawPressStart(((math.sin(5 * love.timer.getTime()) / 2 + .5) ^ .5) / 2 + .5)
end

function TitleScreen:load(sceneParams)
  SoundController:playMusic(themes[config.theme].stageTracks.title_screen)
end

function TitleScreen:unload()
end

return TitleScreen
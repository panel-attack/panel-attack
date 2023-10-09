local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local consts = require("consts")
local input = require("inputManager")
local tableUtils = require("tableUtils")
local Menu = require("ui.Menu")
local class = require("class")

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
  gprintf(loc("continue_button"), x, y, textMaxWidth, "center", {1,1,1,percent}, nil, 16)
end

function TitleScreen:drawBackground()
  self.backgroundImg:draw()
end

function TitleScreen:update(dt)
  self.backgroundImg:update(dt)
  titleDrawPressStart(((math.sin(5 * love.timer.getTime()) / 2 + .5) ^ .5) / 2 + .5)
  local keyPressed = tableUtils.trueForAny(input.isDown, function(key) return key end)
  if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or keyPressed then
    Menu.playValidationSfx()
    stop_the_music()
    sceneManager:switchToScene("MainMenu")
  end
end

function TitleScreen:load(sceneParams)
  stop_the_music()
  if themes[config.theme].musics["title_screen"] then
    find_and_add_music(themes[config.theme].musics, "title_screen")
  end
end

function TitleScreen:unload()
end

return TitleScreen
local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local consts = require("consts")
local input = require("inputManager")
local tableUtils = require("tableUtils")
local Menu = require("ui.Menu")

--@module titleScreen
-- The title screen scene
local titleScreen = Scene("titleScreen")

local function titleDrawPressStart(percent) 
  local textMaxWidth = consts.CANVAS_WIDTH - 40
  local textHeight = 40
  local x = (consts.CANVAS_WIDTH / 2) - (textMaxWidth / 2)
  local y = consts.CANVAS_HEIGHT * 0.75
  gprintf(loc("continue_button"), x, y, textMaxWidth, "center", {1,1,1,percent}, nil, 16)
end

local backgroundImg = nil

function titleScreen:init()
  sceneManager:addScene(titleScreen)
end

function titleScreen:load() 
  backgroundImg = themes[config.theme].images.bg_title
end

function titleScreen:drawBackground()
  backgroundImg:draw()
end

function titleScreen:update(dt)
  backgroundImg:update(dt)
  titleDrawPressStart(((math.sin(5 * love.timer.getTime()) / 2 + .5) ^ .5) / 2 + .5)
  local keyPressed = tableUtils.trueForAny(input.isDown, function(key) return key end)
  if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or keyPressed then
    Menu.playValidationSfx()
    sceneManager:switchToScene("mainMenu")
  end
end

function titleScreen:unload()
end
return titleScreen
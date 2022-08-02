local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")
local Button = require("ui.Button")
local Menu = require("ui.Menu")
local scene_manager = require("scenes.scene_manager")
local input = require("inputManager")
local tableUtils = require("tableUtils")
require("mainloop")

--@module titleScreen
local titleScreen = Scene("titleScreen")

local function titleDrawPressStart(percent) 
  local textMaxWidth = canvas_width - 40
  local textHeight = 40
  local x = (canvas_width / 2) - (textMaxWidth / 2)
  local y = canvas_height * 0.75
  gprintf(loc("continue_button"), x, y, textMaxWidth, "center", {1,1,1,percent}, nil, 16)
end

function titleScreen:init()
  scene_manager:addScene(titleScreen)
end

function titleScreen:load()
  if not themes[config.theme].images.bg_title then
    return scene_manager:switchScene("main_menu")
  end

  GAME.backgroundImage = themes[config.theme].images.bg_title
end

function titleScreen:update()
  titleDrawPressStart(((math.sin(5 * love.timer.getTime()) / 2 + .5) ^ .5) / 2 + .5)
  local key_pressed = tableUtils.trueForAny(input.isDown, function(key) return key end)
  if love.mouse.isDown(1, 2, 3) or #love.touch.getTouches() > 0 or key_pressed then
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    scene_manager:switchScene("main_menu")
  end
end

function titleScreen:unload()
end

return titleScreen
local Button = require("Button")
local button_manager = require("button_manager")
Queue = require("Queue")
config = require("config")
require("class")
socket = require("socket")
json = require("dkjson")
local Game = require("Game")
GAME = Game()
--config = GAME.config
server_queue = GAME.server_queue
global_canvas = GAME.global_canvas
localization = GAME.localization
replay = GAME.replay
main_menu_screen_pos = GAME.main_menu_screen_pos
ClickMenu = require("ClickMenu")
require("match")
require("BattleRoom")
require("util")
require("consts")
require("globals")
require("character") -- after globals!
require("stage") -- after globals!
require("save")
require("engine")
require("AttackEngine")
require("graphics")
require("network")
require("Puzzle")
require("PuzzleSet")
require("puzzles")
require("mainloop")
require("sound")
require("timezones")
require("gen_panels")
require("panels")
require("Theme")
require("dump")
local logger = require("logger")

--[[
local consts = require("consts")
local function endless_buttons(button)
  button:remove()
  
  local b1 = Button({label = "button1", x = math.random(0, consts.CANVAS_WIDTH), y = math.random(0, consts.CANVAS_HEIGHT)})
  b1.label = "button" .. b1.id
  b1.onClick = function() play_optional_sfx(themes[config.theme].sounds.menu_validate) endless_buttons(b1) end
  
  if math.random() > .75 then
    local b2 = Button({label = "button1", x = math.random(0, consts.CANVAS_WIDTH), y = math.random(0, consts.CANVAS_HEIGHT)})
    b2.label = "button" .. b2.id
    b2.onClick = function() play_optional_sfx(themes[config.theme].sounds.menu_validate) endless_buttons(b2) end
  end
end
--]]

-- Called at the beginning to load the game
-- Either called directly or from auto_updater
-- auto updater passes in GameUpdater as the last args
function love.load(args)
  local game_updater = nil
  if args then
    game_updater = args[#args]
  end
  
  -- local button = Button({label = "button"})
  -- button.onClick = function() play_optional_sfx(themes[config.theme].sounds.menu_validate) endless_buttons(button) end
  math.randomseed(os.time())
  for i = 1, 4 do
    math.random()
  end
  
  
  -- construct game here
  GAME:load(game_updater)
  mainloop = coroutine.create(fmainloop)
end

function love.focus(f)
  GAME.focused = f
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)
  GAME:update(dt)
end

-- Called whenever the game needs to draw.
function love.draw()
  button_manager.draw()
  GAME:draw()
end

-- Transform from window coordinates to game coordinates
local function transform_coordinates(x, y)
  local lbx, lby, lbw, lbh = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  return (x - lbx) / 1 * canvas_width / lbw, (y - lby) / 1 * canvas_height / lbh
end

-- Handle a mouse or touch press
function love.mousepressed(x, y)
  button_manager.mousepressed(x, y)

  for menu_name, menu in pairs(CLICK_MENUS) do
    menu:click_or_tap(transform_coordinates(x, y))
  end
end

-- Handle a touch press
-- Note we are specifically not implementing this because mousepressed above handles mouse and touch
-- function love.touchpressed(id, x, y, dx, dy, pressure)
  -- local _x, _y = transform_coordinates(x, y)
  -- click_or_tap(_x, _y, {id = id, x = _x, y = _y, dx = dx, dy = dy, pressure = pressure})
-- end

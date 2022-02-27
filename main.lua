local button_manager = require("ui.button_manager")
local slider_manager = require("ui.slider_manager")
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
require("table_util")
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
local input = require("input2")
require("rich_presence.RichPresence")
GAME.scores = require("scores")
GAME.rich_presence = RichPresence()
local nextPresenceUpdate = 0

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
  GAME.rich_presence:initialize("902897593049301004")
end

function love.focus(f)
  GAME.focused = f
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)
  button_manager.update()
  button_manager.draw()
  slider_manager.draw()
  input:update()
  GAME:update(dt)
  GAME.rich_presence:runCallbacks()
end

-- Called whenever the game needs to draw.
function love.draw()
  GAME:draw()
end

-- Transform from window coordinates to game coordinates
local function transform_coordinates(x, y)
  local lbx, lby, lbw, lbh = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  return (x - lbx) / 1 * canvas_width / lbw, (y - lby) / 1 * canvas_height / lbh
end

-- Handle a mouse or touch press
function love.mousepressed(x, y)
  button_manager.mousePressed(x, y)
  slider_manager.mousePressed(x, y)

  for menu_name, menu in pairs(CLICK_MENUS) do
    menu:click_or_tap(transform_coordinates(x, y))
  end
end

function love.mousereleased(x, y, button)
  if button == 1 then
    slider_manager.mouseReleased(x, y)
    button_manager.mouseReleased(x, y)
  end
end

function love.mousemoved( x, y, dx, dy, istouch )
	if love.mouse.isDown(1) then
    slider_manager.mouseDragged(x, y)
  end
end

-- Handle a touch press
-- Note we are specifically not implementing this because mousepressed above handles mouse and touch
-- function love.touchpressed(id, x, y, dx, dy, pressure)
-- local _x, _y = transform_coordinates(x, y)
-- click_or_tap(_x, _y, {id = id, x = _x, y = _y, dx = dx, dy = dy, pressure = pressure})
-- end

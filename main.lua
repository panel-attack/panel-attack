require("class")
socket = require("socket")
json = require("dkjson")
GAME = require("game")
require("match")
require("BattleRoom")
require("util")
require("table_util")
require("consts")
require("queue")
require("globals")
require("character") -- after globals!
require("stage") -- after globals!
require("save")
require("engine")
require("AttackEngine")
require("localization")
require("graphics")
GAME.input = require("input")
require("network")
require("Puzzle")
require("PuzzleSet")
require("puzzles")
require("mainloop")
require("sound")
require("timezones")
require("gen_panels")
require("panels")
require("theme")
require("click_menu")
local logger = require("logger")

GAME.scores = require("scores")

global_canvas = love.graphics.newCanvas(canvas_width, canvas_height)

local last_x = 0
local last_y = 0
local input_delta = 0.0
local pointer_hidden = false
local mainloop = nil

-- Called at the beginning to load the game
function love.load()
  math.randomseed(os.time())
  for i = 1, 4 do
    math.random()
  end
  read_key_file()
  mainloop = coroutine.create(fmainloop)
end

function love.focus(f)
  GAME.focused = f
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)
  if love.mouse.getX() == last_x and love.mouse.getY() == last_y then
    if not pointer_hidden then
      if input_delta > mouse_pointer_timeout then
        pointer_hidden = true
        love.mouse.setVisible(false)
      else
        input_delta = input_delta + dt
      end
    end
  else
    last_x = love.mouse.getX()
    last_y = love.mouse.getY()
    input_delta = 0.0
    if pointer_hidden then
      pointer_hidden = false
      love.mouse.setVisible(true)
    end
  end

  leftover_time = leftover_time + dt

  local status, err = coroutine.resume(mainloop)
  if not status then
    local system_info = "OS: " .. love.system.getOS()
    if GAME_UPDATER_GAME_VERSION then
      system_info = system_info .. "\n" .. GAME_UPDATER_GAME_VERSION
    end
    send_error_report(err, debug.traceback(mainloop), GAME_UPDATER_GAME_VERSION, love.system.getOS())
    error(err .. "\n" .. debug.traceback(mainloop).. "\n" .. system_info)
  end
  if server_queue and server_queue:size() > 0 then
    logger.trace("Queue Size: " .. server_queue:size() .. " Data:" .. server_queue:to_short_string())
  end
  this_frame_messages = {}

  update_music()
end

-- Called whenever the game needs to draw.
function love.draw()
  -- if not main_font then
  -- main_font = love.graphics.newFont("Oswald-Light.ttf", 15)
  -- end
  -- main_font:setLineHeight(0.66)
  -- love.graphics.setFont(main_font)
  if GAME.foreground_overlay then
    local scale = canvas_width / math.max(GAME.foreground_overlay:getWidth(), GAME.foreground_overlay:getHeight()) -- keep image ratio
    menu_drawf(GAME.foreground_overlay, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end

  -- Clear the screen
  love.graphics.setBlendMode("alpha", "alphamultiply")
  love.graphics.setCanvas(global_canvas)
  love.graphics.setBackgroundColor(unpack(global_background_color))
  love.graphics.clear()

  for i = gfx_q.first, gfx_q.last do
    gfx_q[i][1](unpack(gfx_q[i][2]))
  end
  gfx_q:clear()

  -- Draw the FPS if enabled
  if config ~= nil and config.show_fps then
    love.graphics.print("FPS: " .. love.timer.getFPS(), 1, 1)
  end

  love.graphics.setCanvas() -- render everything thats been added
  love.graphics.clear(love.graphics.getBackgroundColor()) -- clear in preperation for the next render
  
  x, y, w, h = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(global_canvas, x, y, 0, w / canvas_width, h / canvas_height)

  -- draw background and its overlay
  local scale = canvas_width / math.max(GAME.backgroundImage:getWidth(), GAME.backgroundImage:getHeight()) -- keep image ratio
  menu_drawf(GAME.backgroundImage, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  if GAME.background_overlay then
    local scale = canvas_width / math.max(GAME.background_overlay:getWidth(), GAME.background_overlay:getHeight()) -- keep image ratio
    menu_drawf(GAME.background_overlay, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end
end

-- Transform from window coordinates to game coordinates
local function transform_coordinates(x, y)
  local lbx, lby, lbw, lbh = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  return (x - lbx) / 1 * canvas_width / lbw, (y - lby) / 1 * canvas_height / lbh
end

-- Handle a mouse or touch press
function love.mousepressed(x, y)
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

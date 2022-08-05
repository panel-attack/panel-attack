require("class")
socket = require("socket")
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
require("engine/GarbageQueue")
require("engine/telegraph")
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
require("computerPlayers.computerPlayer")
require("rich_presence.RichPresence")
local logger = require("logger")
GAME.scores = require("scores")
GAME.rich_presence = RichPresence()


local last_x = 0
local last_y = 0
local input_delta = 0.0
local pointer_hidden = false
local mainloop = nil

-- Called at the beginning to load the game
function love.load()
  love.graphics.setDefaultFilter("linear", "linear")
  if config.maximizeOnStartup and not love.window.isMaximized() then
    love.window.maximize()
  end
  local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
  GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
  math.randomseed(os.time())
  for i = 1, 4 do
    math.random()
  end
  read_key_file()
  GAME.rich_presence:initialize("902897593049301004")
  mainloop = coroutine.create(fmainloop)

  GAME.globalCanvas = love.graphics.newCanvas(canvas_width, canvas_height, {dpiscale=GAME:newCanvasSnappedScale()})
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

  if GAME.backgroundImage then
    GAME.backgroundImage:update(dt)
  end

  local status, err = coroutine.resume(mainloop)
  if not status then
    local errorData = Game.errorData(err, debug.traceback(mainloop))
    if GAME_UPDATER_GAME_VERSION then
      send_error_report(errorData)
    end
    error(err .. "\n\n" .. dump(errorData, true))
  end
  if server_queue and server_queue:size() > 0 then
    logger.trace("Queue Size: " .. server_queue:size() .. " Data:" .. server_queue:to_short_string())
  end
  this_frame_messages = {}

  update_music()
  GAME.rich_presence:runCallbacks()
end

function love.resize(newPixelWidth, newPixelHeight)
  if GAME then
    local previousXScale = GAME.canvasXScale
    GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
    if previousXScale ~= GAME.canvasXScale then
      if GAME.match then
        GAME.needsAssetReload = true
      else
        GAME:refreshCanvasAndImagesForNewScale()
      end
    end
    GAME.showGameScale = true
  end
end

-- Called whenever the game needs to draw.
function love.draw()
  if GAME.foreground_overlay then
    local scale = canvas_width / math.max(GAME.foreground_overlay:getWidth(), GAME.foreground_overlay:getHeight()) -- keep image ratio
    menu_drawf(GAME.foreground_overlay, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end

  -- Clear the screen
  love.graphics.setCanvas(GAME.globalCanvas)
  love.graphics.setBackgroundColor(unpack(global_background_color))
  love.graphics.clear()

  -- Draw the FPS if enabled
  if config ~= nil and config.show_fps then
    gprintf("FPS: " .. love.timer.getFPS(), 1, 1)
  end

  if STONER_MODE then 
    gprintf("STONER", 1, 1 + (11 * 4))
  end

  for i = gfx_q.first, gfx_q.last do
    gfx_q[i][1](unpack(gfx_q[i][2]))
  end
  gfx_q:clear()

  love.graphics.setCanvas() -- render everything thats been added
  love.graphics.clear(love.graphics.getBackgroundColor()) -- clear in preperation for the next render
    
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(GAME.globalCanvas, GAME.canvasX, GAME.canvasY, 0, GAME.canvasXScale, GAME.canvasYScale)
  love.graphics.setBlendMode("alpha", "alphamultiply")

  if GAME.showGameScale or config.debug_mode then
    local scaleString = "Scale: " .. GAME.canvasXScale .. " (" .. canvas_width * GAME.canvasXScale .. " x " .. canvas_height * GAME.canvasYScale .. ")"
    local newPixelWidth = love.graphics.getWidth()

    if canvas_width * GAME.canvasXScale > newPixelWidth then
      scaleString = scaleString .. " Clipped "
    end
    love.graphics.printf(scaleString, get_global_font_with_size(30), 5, 5, 2000, "left")
  end

  -- draw background and its overlay
  if GAME.backgroundImage then
    GAME.backgroundImage:draw()
  end
  if GAME.background_overlay then
    local scale = canvas_width / math.max(GAME.background_overlay:getWidth(), GAME.background_overlay:getHeight()) -- keep image ratio
    menu_drawf(GAME.background_overlay, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end
end

-- Handle a mouse or touch press
function love.mousepressed(x, y)
  for menu_name, menu in pairs(CLICK_MENUS) do
    menu:click_or_tap(GAME:transform_coordinates(x, y))
  end
end

-- Handle a touch press
-- Note we are specifically not implementing this because mousepressed above handles mouse and touch
-- function love.touchpressed(id, x, y, dx, dy, pressure)
-- local _x, _y = GAME:transform_coordinates(x, y)
-- click_or_tap(_x, _y, {id = id, x = _x, y = _y, dx = dx, dy = dy, pressure = pressure})
-- end

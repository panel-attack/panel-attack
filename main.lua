require("class")
socket = require("socket")
GAME = require("game")
require("match")
local batteries = require("batteries")
local fpsGraph = require("libraries.FPSGraph")
require("BattleRoom")
require("util")
require("table_util")
require("consts")
require("FileUtil")
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
require("replay")
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

if PROFILING_ENABLED then
  GAME.profiler = require("profiler")
end

local logger = require("logger")
GAME.scores = require("scores")
GAME.rich_presence = RichPresence()


local last_x = 0
local last_y = 0
local input_delta = 0.0
local pointer_hidden = false
local mainloop = nil

local testGraph = nil
local testGraph2 = nil
local testGraph3 = nil

-- Called at the beginning to load the game
function love.load()

  if PROFILING_ENABLED then
    GAME.profiler:start()
  end
  
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

local consts = {}
consts.FRAME_RATE = 1/60

local prev_time = 0
local sleep_ratio = .9
local leftOverRatio = .1
function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0  

  -- Main loop time.
	return function()
    local targetDelta = consts.FRAME_RATE
    if leftover_time > consts.FRAME_RATE / 2 then
      targetDelta = targetDelta - (leftover_time * leftOverRatio)
    end

    local targetTime = prev_time + targetDelta
    local currentTime = love.timer.getTime()

    -- Sleep for 90% of our time to wait to save cpu
    local sleepTime = (targetTime - currentTime) * sleep_ratio
    if love.timer and sleepTime > 0 then 
      love.timer.sleep(sleepTime) 
    end

    -- While loop the last little bit to be more accurate
    currentTime = love.timer.getTime()
    while currentTime < targetTime do
      currentTime = love.timer.getTime()
    end

    prev_time = currentTime
  
    -- Process events.
    if love.event then
      love.event.pump()
      for name, a,b,c,d,e,f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then
            return a or 0
          end
        end
        love.handlers[name](a,b,c,d,e,f)
      end
    end

    -- Update dt, as we'll be passing it to update
    if love.timer then dt = love.timer.step() end

    -- Call update and draw
    if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

    if love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())

      if love.draw then love.draw() end

      love.graphics.present()
    end
  end
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)

  if config.show_fps and config.debug_mode then
    if testGraph == nil then
      local updateSpeed = 0.25

      -- fps graph
      testGraph = fpsGraph.createGraph(0, 0, 1200, 50, updateSpeed)
      -- memory graph
      testGraph2 = fpsGraph.createGraph(0, 260, nil, nil, updateSpeed)
      -- spare time graph
      testGraph3 = fpsGraph.createGraph(0, 600, 1200, 100, updateSpeed)
    end
    local fps = math.round(1.0 / dt, 1)
    fpsGraph.updateGraph(testGraph, fps, "FPS: " .. fps, dt)
    fpsGraph.updateMem(testGraph2, dt)
    --local sparePercent = math.round(timeToWaitDelta / (consts.FRAME_RATE) * 100, 1)
    --fpsGraph.updateGraph(testGraph3, sparePercent, "Spare %: " .. sparePercent .. " leftovers: " .. leftover_time - consts.FRAME_RATE .. " dt: " .. dt, dt)
  end

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

  local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
  if GAME.previousWindowWidth ~= newPixelWidth or GAME.previousWindowHeight ~= newPixelHeight then
    GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
    if GAME.match then
      GAME.needsAssetReload = true
    else
      GAME:refreshCanvasAndImagesForNewScale()
    end
    GAME.showGameScale = true
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
  
  if GAME.memoryFix then
    batteries(0.0001, nil, nil)
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
    gprintf("leftover_time: " .. leftover_time, 1, 40)
    local memoryCount = collectgarbage("count")
    memoryCount = round(memoryCount / 1000, 1)
    gprintf("Memory " .. memoryCount .. " MB", 1, 100)
  end

  -- local memoryCount = collectgarbage("count")
  -- memoryCount = round(memoryCount / 1000, 1)
  -- gprintf("Memory " .. memoryCount .. " MB", 1, 100)

  if STONER_MODE then 
    gprintf("STONER", 1, 1 + (11 * 4))
  end

  for i = gfx_q.first, gfx_q.last do
    gfx_q[i][1](unpack(gfx_q[i][2]))
  end
  gfx_q:clear()
  if testGraph then
	  fpsGraph.drawGraphs({testGraph, testGraph2, testGraph3})
  end

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

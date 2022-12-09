require("class")
socket = require("socket")
GAME = require("game")
require("match")
local batteries = require("batteries")
local BarGraph = require("libraries.BarGraph")
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

local testGraph = {}

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
consts.frameRate = 1/60

local sleepAmount = 0
local previousTime = 0
local sleepRatio = .99

local function customSleep()

  local targetDelay = consts.frameRate
  -- We want leftover time to be above 0 but less than a quarter frame.
  -- If it goes above that, only wait enough to get it down to that.
  local maxLeftOverTime = consts.frameRate / 4
  if leftover_time > maxLeftOverTime then
    targetDelay = targetDelay - (leftover_time - maxLeftOverTime)
    targetDelay = math.max(targetDelay, 0)
  end

  local targetTime = previousTime + targetDelay
  local originalTime = love.timer.getTime()
  local currentTime = originalTime

  -- Sleep a percentage of our time to wait to save cpu
  local sleepTime = (targetTime - currentTime) * sleepRatio
  if love.timer and sleepTime > 0 then 
    love.timer.sleep(sleepTime) 
  end
  currentTime = love.timer.getTime()

  -- While loop the last little bit to be more accurate
  while currentTime < targetTime do
    currentTime = love.timer.getTime()
  end

  previousTime = currentTime
  sleepAmount = currentTime - originalTime
end

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0  

  -- Main loop time.
	return function()
    customSleep()

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
    if love.timer then
      dt = love.timer.step()
    end

    local preUpdateTime = love.timer.getTime()

    -- Call update and draw
    if love.update then
      love.update(dt)
    end -- will pass 0 if love.timer is disabled

    local graphicsActive = love.graphics and love.graphics.isActive()
    if graphicsActive then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())

      if love.draw then 
        love.draw()
      end
    end

    local updateTimeTaken = love.timer.getTime() - preUpdateTime
    
    local presentTimeTaken = 0
    if graphicsActive then
      local prePresentTime = love.timer.getTime()
      love.graphics.present()
      presentTimeTaken = love.timer.getTime() - prePresentTime
    end

    if testGraph[1] then
      local fps = math.round(1.0 / dt, 1)
      testGraph[1]:updateGraph({fps}, "FPS: " .. fps, dt)
      local memoryCount = collectgarbage("count")
      memoryCount = round(memoryCount / 1024, 1)
      testGraph[2]:updateGraph({memoryCount}, "Memory: " .. memoryCount .. " Mb", dt)
      testGraph[3]:updateGraph({leftover_time}, "leftover_time " .. leftover_time, dt)
      testGraph[4]:updateGraph({updateTimeTaken, sleepAmount, presentTimeTaken}, "Run Loop " .. updateTimeTaken .. " " .. sleepAmount .. " " .. presentTimeTaken, dt)
    end
  end
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)

  if config.show_fps and config.debug_mode then
    if testGraph[1] == nil then
      local updateSpeed = consts.frameRate * 1
      local x = 880
      local y = 0
      local width = 400
      local height = 50
      local padding = 80
      -- fps graph
      testGraph[#testGraph+1] = BarGraph(x, y, width, height, updateSpeed, 60)
      testGraph[#testGraph]:setFillColor({0,1,0,1}, 1)
      y = y + height + padding
      -- memory graph
      testGraph[#testGraph+1] = BarGraph(x, y, width, height, updateSpeed, 20)
      y = y + height + padding
      -- leftover time
      testGraph[#testGraph+1] = BarGraph(x, y, width, height, updateSpeed, consts.frameRate * 1)
      testGraph[#testGraph]:setFillColor({0,1,1,1}, 1)
      y = y + height + padding
      -- run loop graph
      testGraph[#testGraph+1] = BarGraph(x, y, width, height, updateSpeed, consts.frameRate * 1)
      testGraph[#testGraph]:setFillColor({0,1,0,1}, 1) -- update
      testGraph[#testGraph]:setFillColor({0,0,1,1}, 2) -- sleep
      testGraph[#testGraph]:setFillColor({1,1,0,1}, 3) -- present
      y = y + height + padding
    end
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
    if testGraph[1] then
      BarGraph.drawGraphs(testGraph)
    else
      gprintf("FPS: " .. love.timer.getFPS(), 1, 1)
    end
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

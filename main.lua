local buttonManager = require("ui.buttonManager")
local sliderManager = require("ui.sliderManager")
local inputFieldManager = require("ui.inputFieldManager")
local inputManager = require("inputManager")
local logger = require("logger")
local consts = require("consts")

local RichPresence = require("rich_presence.RichPresence")

Queue = require("Queue")
require("developer")
require("class")
socket = require("socket")
json = require("dkjson")
-- move to load once global dependencies have been resolved
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
local RunTimeGraph = require("RunTimeGraph")
require("BattleRoom")
require("util")
require("FileUtil")

require("globals")
require("character_loader") -- after globals!
require("stage") -- after globals!

require("localization")
require("queue")
require("save")
-- temp hack to keep modules dependent on the global gfx_q working, please use GAME:gfx_q instead
gfx_q = GAME.gfx_q


require("engine/GarbageQueue")
require("engine/telegraph")
require("engine")
require("AttackEngine")

require("graphics")
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
require("Theme")
require("dump")
local utf8 = require("utf8")
require("computerPlayers.computerPlayer")

if PROFILING_ENABLED then
  GAME.profiler = require("profiler")
end

GAME.scores = require("scores")
GAME.rich_presence = RichPresence()

local runTimeGraph = nil
local runMetrics = {
  previousSleepEnd = 0,
  dt = 0,
  sleepDuration = 0,
  updateDuration = 0,
  drawDuration = 0,
  presentDuration = 0
}

local prev_time = 0

-- Sleeps just the right amount of time to make our next update step be one frame long.
-- If we have leftover time that hasn't been run yet, it will sleep less to catchup.
local function customSleep()
  local sleep_ratio = .9
  local current_time = love.timer.getTime()
  local wait_time = (prev_time + consts.FRAME_RATE - current_time) * sleep_ratio
  if love.timer and wait_time > 0 then 
    love.timer.sleep(wait_time) 
  end
  current_time = love.timer.getTime()
  while prev_time + consts.FRAME_RATE > current_time do
    current_time = love.timer.getTime()
  end
  prev_time = current_time
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

-- Called at the beginning to load the game
-- Either called directly or from auto_updater
-- auto updater passes in GameUpdater as the last args
function love.load(args)
  local game_updater = nil
  if args then
    game_updater = args[#args]
  end
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
  -- construct game here
  GAME.rich_presence:initialize("902897593049301004")
  GAME:load(game_updater)
  mainloop = coroutine.create(fmainloop)

  GAME.globalCanvas = love.graphics.newCanvas(canvas_width, canvas_height, {dpiscale=GAME:newCanvasSnappedScale()})
end

function love.focus(f)
  GAME.focused = f
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)
  inputManager:update(dt)
  buttonManager.update()
  inputFieldManager.update()

  if config.show_fps and config.debug_mode then
    if runTimeGraph == nil then
      runTimeGraph = RunTimeGraph()
    end
  else
    runTimeGraph = nil
  end
  
  GAME:update(dt)
end

-- Called whenever the game needs to draw.
function love.draw()
  if config ~= nil and config.show_fps then
    if runTimeGraph then
      runTimeGraph:draw()
    end
  end

  GAME:draw()
end

-- Handle a mouse or touch press
function love.mousepressed(x, y, button)
  buttonManager.mousePressed(x, y)
  sliderManager.mousePressed(x, y)
  inputFieldManager.mousePressed(x, y)
  inputManager:mousePressed(x, y, button)

  for menu_name, menu in pairs(CLICK_MENUS) do
    menu:click_or_tap(GAME:transform_coordinates(x, y))
  end
end

function love.mousereleased(x, y, button)
  if button == 1 then
    sliderManager.mouseReleased(x, y)
    buttonManager.mouseReleased(x, y)
    inputManager:mouseReleased(x, y, button)
  end
end

function love.mousemoved( x, y, dx, dy, istouch )
	if love.mouse.isDown(1) then
    sliderManager.mouseDragged(x, y)
  end
  inputManager:mouseMoved(x, y)
end

function love.joystickpressed(joystick, button)
  inputManager:joystickPressed(joystick, button)
end

function love.joystickreleased(joystick, button)
  inputManager:joystickReleased(joystick, button)
end

-- Handle a touch press
-- Note we are specifically not implementing this because mousepressed above handles mouse and touch
-- function love.touchpressed(id, x, y, dx, dy, pressure)
-- local _x, _y = GAME:transform_coordinates(x, y)
-- click_or_tap(_x, _y, {id = id, x = _x, y = _y, dx = dx, dy = dy, pressure = pressure})
-- end

function love.errorhandler(msg)

  if not love.window or not love.graphics or not love.event then
    return
  end

  if not love.graphics.isCreated() or not love.window.isOpen() then
    local success, status = pcall(love.window.setMode, 800, 600)
    if not success or not status then
      return
    end
  end

  msg = tostring(msg)
  local sanitizedMessageLines = {}
  for char in msg:gmatch(utf8.charpattern) do
    table.insert(sanitizedMessageLines, char)
  end
  local sanitizedMessage = table.concat(sanitizedMessageLines)

  local trace = GAME.crashTrace or debug.traceback("", 3)
  local traceLines = {}
  for l in trace:gmatch("(.-)\n") do
    if not l:match("boot.lua") and not l:match("stack traceback:") then
      table.insert(traceLines, l)
    end
  end
  local sanitizedTrace = table.concat(traceLines, "\n")
  
  local errorData = GAME.errorData(sanitizedMessage, sanitizedTrace)
  local detailedErrorLogString = GAME.detailedErrorLogString(errorData)
  errorData.detailedErrorLogString = detailedErrorLogString
  if GAME_UPDATER_GAME_VERSION then
    send_error_report(errorData)
  end

  local errorLines = {}
  table.insert(errorLines, "Error\n")
  table.insert(errorLines, detailedErrorLogString)
  if #sanitizedMessage ~= #msg then
    table.insert(errorLines, "Invalid UTF-8 string in error message.")
  end
  table.insert(errorLines, "\n")

  local messageToDraw = table.concat(errorLines, "\n")
  messageToDraw = messageToDraw:gsub("\t", "    ")
  messageToDraw = messageToDraw:gsub("%[string \"(.-)\"%]", "%1")

  print(messageToDraw)

  -- Reset state.
  if love.mouse then
    love.mouse.setVisible(true)
    love.mouse.setGrabbed(false)
    love.mouse.setRelativeMode(false)
    if love.mouse.isCursorSupported() then
      love.mouse.setCursor()
    end
  end
  if love.joystick then
    -- Stop all joystick vibrations.
    for i, v in ipairs(love.joystick.getJoysticks()) do
      v:setVibration()
    end
  end
  if love.audio then
    love.audio.stop()
  end

  love.graphics.reset()
  love.graphics.setFont(get_font_delta(4))
  love.graphics.setColor(1, 1, 1)
  love.graphics.origin()

  local scale = 1
  if GAME then
    scale = GAME:newCanvasSnappedScale()
    love.graphics.scale(scale, scale)
  end

  local function draw()
    if not love.graphics.isActive() then
      return
    end

    love.graphics.clear(love.graphics.getBackgroundColor())
    local positionX = 40
    local positionY = positionX
    love.graphics.printf(messageToDraw, positionX, positionY, love.graphics.getWidth() - positionX)

    love.graphics.present()
  end

  local fullErrorText = messageToDraw
  local function copyToClipboard()
    if not love.system then
      return
    end
    love.system.setClipboardText(fullErrorText)
    messageToDraw = messageToDraw .. "\nCopied to clipboard!"
  end

  if love.system then
    messageToDraw = messageToDraw .. "\n\nPress Ctrl+C or tap to copy this error"
  end

  return function()
    love.event.pump()

    for e, a, b, c in love.event.poll() do
      if e == "quit" then
        return 1
      elseif e == "keypressed" and a == "escape" then
        return 1
      elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
        copyToClipboard()
      elseif e == "touchpressed" then
        local name = love.window.getTitle()
        if #name == 0 or name == "Untitled" then
          name = "Game"
        end
        local buttons = {"OK", "Cancel"}
        if love.system then
          buttons[3] = "Copy to clipboard"
        end
        local pressed = love.window.showMessageBox("Quit " .. name .. "?", "", buttons)
        if pressed == 1 then
          return 1
        elseif pressed == 3 then
          copyToClipboard()
        end
      end
    end

    draw()

    if love.timer then
      love.timer.sleep(0.1)
    end
  end

end

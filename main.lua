local buttonManager = require("ui.buttonManager")
local sliderManager = require("ui.sliderManager")
local inputFieldManager = require("ui.inputFieldManager")
local inputManager = require("inputManager")
local logger = require("logger")
local consts = require("consts")


require("developer")
require("class")
socket = require("socket")

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
local Game = require("Game")
-- move to load once global dependencies have been resolved
GAME = Game()
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
require("theme")
local utf8 = require("utf8")
require("click_menu")
require("computerPlayers.computerPlayer")
require("rich_presence.RichPresence")

if PROFILING_ENABLED then
  GAME.profiler = require("profiler")
end

GAME.scores = require("scores")
GAME.rich_presence = RichPresence()

-- Called at the beginning to load the game
-- Either called directly or from auto_updater
function love.load(args) 
  love.keyboard.setTextInput(false)
  
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
  -- TODO: pull game updater from from args
  GAME:load(GAME_UPDATER)
  mainloop = coroutine.create(fmainloop)

  GAME.globalCanvas = love.graphics.newCanvas(canvas_width, canvas_height, {dpiscale=GAME:newCanvasSnappedScale()})
end

function love.focus(f)
  GAME.focused = f
end

-- Sleeps just the right amount of time to make our next update step be one frame long.
-- If we have leftover time that hasn't been run yet, it will sleep less to catchup.
local function customSleep(runMetrics)

  local targetDelay = consts.FRAME_RATE
  -- We want leftover time to be above 0 but less than a quarter frame.
  -- If it goes above that, only wait enough to get it down to that.
  local maxLeftOverTime = consts.FRAME_RATE / 4
  if leftover_time > maxLeftOverTime then
    targetDelay = targetDelay - (leftover_time - maxLeftOverTime)
    targetDelay = math.max(targetDelay, 0)
  end

  local targetTime = runMetrics.previousSleepEnd + targetDelay
  local originalTime = love.timer.getTime()
  local currentTime = originalTime

  -- Sleep a percentage of our time to wait to save cpu
  local sleepRatio = .90
  local sleepTime = (targetTime - currentTime) * sleepRatio
  if love.timer and sleepTime > 0 then
    love.timer.sleep(sleepTime)
  end
  currentTime = love.timer.getTime()

  -- While loop the last little bit to be more accurate
  while currentTime < targetTime do
    currentTime = love.timer.getTime()
  end

  runMetrics.previousSleepEnd = currentTime
  runMetrics.sleepDuration = currentTime - originalTime
end

local runMetrics = {}
runMetrics.previousSleepEnd = 0
runMetrics.dt = 0
runMetrics.sleepDuration = 0
runMetrics.updateDuration = 0
runMetrics.drawDuration = 0
runMetrics.presentDuration = 0

local runTimeGraph = nil

function love.run()
  if love.load then
    love.load(love.arg.parseGameArguments(arg), arg)
  end

  -- We don't want the first frame's dt to include time taken by love.load.
  if love.timer then
    love.timer.step()
  end

  local dt = 0

  -- Main loop time.
  return function()
    customSleep(runMetrics)

    -- Process events.
    if love.event then
      love.event.pump()
      for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then
            return a or 0
          end
        end
        love.handlers[name](a, b, c, d, e, f)
      end
    end

    -- Update dt, as we'll be passing it to update
    if love.timer then
      dt = love.timer.step()
      runMetrics.dt = dt
    end

    -- Call update and draw
    if love.update then
      local preUpdateTime = love.timer.getTime()
      love.update(dt) -- will pass 0 if love.timer is disabled
      runMetrics.updateDuration = love.timer.getTime() - preUpdateTime
    end

    local graphicsActive = love.graphics and love.graphics.isActive()
    if graphicsActive then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())

      if love.draw then
        local preDrawTime = love.timer.getTime()
        love.draw()
        runMetrics.drawDuration = love.timer.getTime() - preDrawTime
      end

      local prePresentTime = love.timer.getTime()
      love.graphics.present()
      runMetrics.presentDuration = love.timer.getTime() - prePresentTime
    end

    if runTimeGraph ~= nil then
      runTimeGraph:updateWithMetrics(runMetrics)
    end
  end
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
  buttonManager:printButtonCount()
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
  
  local errorData = Game.errorData(sanitizedMessage, sanitizedTrace)
  local detailedErrorLogString = Game.detailedErrorLogString(errorData)
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

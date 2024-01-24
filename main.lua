local touchHandler = require("ui.touchHandler")
local inputFieldManager = require("ui.inputFieldManager")
local inputManager = require("inputManager")
local logger = require("logger")
local consts = require("consts")
require("developer")
require("class")
socket = require("socket")
require("localization")
require("match")
local RunTimeGraph = require("RunTimeGraph")
require("BattleRoom")
require("network.BattleRoom")
require("util")
local tableUtils = require("tableUtils")
local fileUtils = require("FileUtils")
require("globals")
require("character_loader") -- after globals!
require("stage_loader") -- after globals!
local CustomRun = require("CustomRun")
local GraphicsUtil = require("graphics_util")

require("queue")
local save = require("save")
local Game = require("Game")
local ClientMessages = require("network.ClientProtocol")
-- move to load once global dependencies have been resolved
GAME = Game()

require("engine/GarbageQueue")
require("engine/telegraph")
require("engine")
require("engine.checkMatches")
require("network.Stack")
require("AttackEngine")

require("graphics")
require("replay")
require("Puzzle")
require("PuzzleSet")
require("puzzles")
require("sound")
require("timezones")
require("panels")
require("Theme")
local utf8 = require("utf8Additions")
require("computerPlayers.computerPlayer")

-- We override love.run with a function that refers to `pa_runInternal` for its gameloop function
-- so by overwriting that, the new runInternal will get used on the next iteration
love.pa_runInternal = CustomRun.innerRun
if GAME_UPDATER == nil then
  -- We don't have an autoupdater, so we need to override run.
  -- In the autoupdater case run will already have been overridden and be running
  love.run = CustomRun.run
end

GAME.rich_presence = RichPresence()

-- Called at the beginning to load the game
-- Either called directly or from auto_updater
function love.load(args) 
  love.keyboard.setTextInput(false)

  if PROFILING_ENABLED then
    GAME.profiler = require("profiler")
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

  GAME.globalCanvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=GAME:newCanvasSnappedScale()})
end

function love.focus(f)
  GAME.focused = f
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function love.update(dt)
  if config.show_fps and config.debug_mode then
    if CustomRun.runTimeGraph == nil then
      CustomRun.runTimeGraph = RunTimeGraph()
    end
  else
    CustomRun.runTimeGraph = nil
  end

  inputManager:update(dt)
  inputFieldManager.update()
  touchHandler:update(dt)

  local status, err = xpcall(function() GAME:update(dt) end, debug.traceback)
  if not status then
    error(err)
  end
end

-- Called whenever the game needs to draw.
function love.draw()
  GAME:draw()
end

-- Handle a mouse or touch press
function love.mousepressed(x, y, button)
  touchHandler:touch(x, y)
  inputManager:mousePressed(x, y, button)
end

function love.mousereleased(x, y, button)
  if button == 1 then
    touchHandler:release(x, y)
    inputManager:mouseReleased(x, y, button)
  end
end

function love.mousemoved( x, y, dx, dy, istouch )
  if love.mouse.isDown(1) then
    touchHandler:drag(x, y)
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

-- quit handling
function love.quit()
  if PROFILING_ENABLED then
    GAME.profiler.report("profiler.log")
  end
  if GAME.tcpClient:isConnected() then
    GAME.tpcClient:sendRequest(ClientMessages.logout())
  end
  love.audio.stop()
  if love.window.getFullscreen() then
    _, _, config.display = love.window.getPosition()
  else
    config.windowX, config.windowY, config.display = love.window.getPosition()
    config.windowX = math.max(config.windowX, 0)
    config.windowY = math.max(config.windowY, 30) --don't let 'y' be zero, or the title bar will not be visible on next launch.
  end

  config.windowWidth, config.windowHeight, _ = love.window.getMode( )
  config.maximizeOnStartup = love.window.isMaximized()
  config.fullscreen = love.window.getFullscreen()
  write_conf_file()
end

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
  
  local function getGameErrorData(sanitizedMessage, sanitizedTrace)
    local errorData = Game.errorData(sanitizedMessage, sanitizedTrace)
    local detailedErrorLogString = Game.detailedErrorLogString(errorData)
    errorData.detailedErrorLogString = detailedErrorLogString
    if GAME_UPDATER_GAME_VERSION then
      if not GAME.tcpClient:isConnected() then
        GAME.tcpClient:connectToServer(consts.SERVER_LOCATION, 59569)
      end
      GAME.tcpClient:sendErrorReport(errorData)
      GAME.tcpClient:resetNetwork()
    end
    return detailedErrorLogString
  end

  local success, detailedErrorLogString = pcall(getGameErrorData, sanitizedMessage, sanitizedTrace)
  local errorLines = {}
  table.insert(errorLines, "Error\n")
  if success then
    table.insert(errorLines, detailedErrorLogString)
  else
    table.insert(errorLines, sanitizedMessage)
  end
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
  love.graphics.setFont(GraphicsUtil.getGlobalFontWithSize(GraphicsUtil.fontSize + 4))
  GraphicsUtil.setColor(1, 1, 1)
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

function love.resize(newWidth, newHeight)
  if GAME then
    GAME:handleResize(newWidth, newHeight)
  end
end

function love.keypressed(key, scancode, rep)
  logger.trace("key pressed: " .. key)
  if scancode then
    inputManager:keyPressed(key, scancode, rep)
  end
end

function love.textinput(text)
  inputFieldManager.textInput(text)
end

function love.keyreleased(key, unicode)
  inputManager:keyReleased(key, unicode)
end
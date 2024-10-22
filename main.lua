local logger = require("common.lib.logger")
require("common.lib.mathExtensions")
local utf8 = require("common.lib.utf8Additions")
local inputManager = require("common.lib.inputManager")
require("client.src.globals")
local touchHandler = require("client.src.ui.touchHandler")
local inputFieldManager = require("client.src.ui.inputFieldManager")
local ClientMessages = require("common.network.ClientProtocol")
local RunTimeGraph = require("client.src.RunTimeGraph")
local CustomRun = require("client.src.CustomRun")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local prof = require("common.lib.jprof.jprof")

local Game = require("client.src.Game")
-- move to load once global dependencies have been resolved
GAME = Game()

-- We override love.run with a function that refers to `runInternal` for its gameloop function
-- so by overwriting that, the new runInternal will get used on the next iteration
love.runInternal = CustomRun.innerRun

function love.run()
  return CustomRun.run()
end

-- Called at the beginning to load the game
-- Either called directly or from auto_updater
function love.load(args)
  love.keyboard.setTextInput(false)

  love.graphics.setDefaultFilter("linear", "linear")
  if config.maximizeOnStartup and not love.window.isMaximized() then
    love.window.maximize()
  end

  -- there is a bug on windows that causes the game to start like it was borderless
  -- check for that and restore the window if that's the case:
  local dWidth, desktopHeight = love.window.getDesktopDimensions()
  local x, y = love.window.getPosition()
  local w, windowHeight, flags = love.window.getMode()

  if not flags.fullscreen and not flags.borderless then
    if y == 0 and windowHeight == desktopHeight then
      if love.window.isMaximized() then
        love.window.restore()
      end
      love.window.updateMode(w, windowHeight - 30, flags)
      love.window.setPosition(x, 30)
    end
  end

  local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
  GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)

  GAME:load()
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

  GAME:update(dt)
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
  if PROF_CAPTURE then
    prof.write("prof.mpack")
  end
  if GAME.netClient and GAME.netClient:isConnected() then
    GAME.netClient:logout()
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
  pcall(love.filesystem.write, "debug.log", table.concat(logger.messages, "\n"))
end

function love.errorhandler(msg)
  if lldebugger then
    pcall(love.filesystem.write, "debug.log", table.concat(logger.messages, "\n"))
    error(msg, 2)
  end

  if not love.window or not love.graphics or not love.event then
    return
  end

  if not love.graphics.isCreated() or not love.window.isOpen() then
    local success, status = pcall(love.window.setMode, 800, 600)
    if not success or not status then
      return
    end
  end

  -- if we crashed during a match that is likely cause of the issue
  -- we want it logged in a digestable form
  if GAME.battleRoom and GAME.battleRoom.match then
    pcall(function()
      local match = GAME.battleRoom.match
      match.aborted = true
      Replay.finalizeReplay(match, match.replay)
      logger.info("Replay of match during crash:\n" .. json.encode(match.replay))
    end)
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
    -- if GAME_UPDATER_GAME_VERSION then
    --   GAME.netClient:sendErrorReport(errorData, consts.SERVER_LOCATION, 59569)
    -- end
    return detailedErrorLogString
  end

  local success, detailedErrorLogString = pcall(getGameErrorData, sanitizedMessage, sanitizedTrace)
  local errorLines = {}
  table.insert(errorLines, "Error: Please share your crash.log with the developers to get help with this!\n")
  if success then
    table.insert(errorLines, detailedErrorLogString)
    logger.info(detailedErrorLogString)
  else
    table.insert(errorLines, sanitizedMessage)
    logger.info(sanitizedMessage)
  end
  if logger.messages then
    logger.info("config during crash: " .. table_to_string(config))
    pcall(love.filesystem.write, "crash.log", table.concat(logger.messages, "\n"))
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

function love.joystickaxis(joystick, axisIndex, value)
  inputManager:joystickaxis(joystick, axisIndex, value)
end
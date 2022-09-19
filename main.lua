local buttonManager = require("ui.buttonManager")
local sliderManager = require("ui.sliderManager")
local inputFieldManager = require("ui.inputFieldManager")
Queue = require("Queue")
require("developer")
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
local consts = require("consts")
require("globals")
require("character") -- after globals!
require("stage") -- after globals!
require("save")
require("engine/GarbageQueue")
require("engine/telegraph")
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
require("computerPlayers.computerPlayer")
local logger = require("logger")
local RichPresence = require("rich_presence.RichPresence")
local inputManager = require("inputManager")
GAME.scores = require("scores")
GAME.rich_presence = RichPresence()

local prev_time = 0
local sleep_ratio = .9
function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0  

  -- Main loop time.
	return function()
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
  
  GAME.rich_presence:runCallbacks()
  GAME:update(dt)
end

-- Called whenever the game needs to draw.
function love.draw()
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

function love.gamepadpressed(joystick, button)
  inputManager:gamepadPressed(joystick, button)
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

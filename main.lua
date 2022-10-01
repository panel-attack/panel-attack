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
require("BattleRoom")
require("util")
require("FileUtil")

require("globals")
require("character") -- after globals!
require("stage") -- after globals!

require("localization")
require("queue")
require("save")
local Game = require("Game")
GAME = Game()
-- temp hack to keep modules dependnent on the global gfx_q working, please use GAME:gfx_q instead
gfx_q = GAME.gfx_q


require("engine/GarbageQueue")
require("engine/telegraph")
require("engine")
require("AttackEngine")

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

GAME.scores = require("scores")
GAME.rich_presence = RichPresence()

-- Called at the beginning to load the game
-- Either called directly or from auto_updater
function love.load(args)  
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
  GAME:load()
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

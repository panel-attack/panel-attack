-- with love 12 you can pass the name of a lua file as an argument when starting love
-- this will cause that file to be used in place of main.lua
-- so by passing "./testLauncher.lua" as the first arg this becomes a testrunner that shares the game's conf.lua

require("common.lib.mathExtensions")
local util = require("common.lib.util")
util.addToCPath("./common/lib/??")
util.addToCPath("./server/lib/??")
local logger = require("common.lib.logger")
require("client.src.globals")
local Game = require("client.src.Game")
if arg[2] == "debug" then
  require("client.src.developer")
end

function love.load()
  -- this is necessary setup of globals while non-client tests still depend on client components
  GAME = Game()
  GAME:load()
  GAME.muteSound = true

  local cr = coroutine.create(GAME.setupRoutine)
  while coroutine.status(cr) ~= "dead" do
    local success, status = coroutine.resume(cr, GAME)
    if not success then
      GAME.crashTrace = debug.traceback(cr)
      error(status)
    end
  end
end

local tests = {
  "common.tests.engine.StackRollbackReplayTests",
  "client.tests.QueueTests",
  "client.tests.ServerQueueTests",
  --"client.tests.StackGraphicsTests",
  "client.tests.TcpClientTests",
  "client.tests.ThemeTests",
  "server.tests.ConnectionTests",
  "common.tests.engine.GarbageQueueTests",
  "common.tests.engine.HealthTests",
  "common.tests.engine.PanelGenTests",
  "common.tests.engine.PuzzleTests",
  "common.tests.engine.ReplayTests",
  "common.tests.engine.RollbackBufferTests",
  "common.tests.engine.StackTests",
  "common.tests.engine.StackReplayTests",
  "common.tests.engine.StackTouchReplayTests",
  -- disabled for testLauncher because it needs the client love callbacks
  --"common.tests.lib.InputTests",
  "common.tests.lib.JsonEncodingTests",
  "common.tests.lib.tableUtilsTest",
  "common.tests.lib.utf8AdditionsTests",
  "common.tests.lib.utilTests",
  "common.tests.network.NetworkProtocolTests",
  "common.tests.network.TouchDataEncodingTests",
}

local updateCount = 0
function love.update(dt)
  if tests[updateCount] then
    logger.info("running test file " .. tests[updateCount])
    require(tests[updateCount])
  end
  updateCount = updateCount + 1
end

-- the drawing somehow doesn't really work because the update does not wait for the require to finish?
function love.draw()
  local width, height = love.window.getMode()
  if tests[updateCount + 1] then
    love.graphics.printf("Running " .. tests[updateCount + 1], 0, height / 2, width, "center")
  elseif updateCount > #tests then
    love.graphics.printf("All tests completed", 0, height / 2, width, "center")
  end
end

function love.quit()
  love.filesystem.write("test.log", table.concat(logger.messages, "\n"))
end

local love_errorhandler = love.errorhandler
function love.errorhandler(msg)
  logger.info(msg)
  pcall(love.filesystem.write, "test-crash.log", table.concat(logger.messages, "\n"))
  if lldebugger then
    error(msg, 2)
  else
    return love_errorhandler(msg)
  end
end
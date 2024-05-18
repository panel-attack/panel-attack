-- with love 12 you can pass the name of a lua file as an argument when starting love
-- this will cause that file to be used in place of main.lua
-- so by passing "./testLauncher.lua" as the first arg this becomes a testrunner that shares the game's conf.lua
local logger = require("common.lib.logger")
require("client.src.globals")
local Game = require("client.src.Game")

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
  "server.tests.ConnectionTests",
  "common.engine.tests.StackTests",
  "common.engine.tests.GarbageQueueTests",
  "common.engine.tests.HealthTests",
  "common.engine.tests.PanelGenTests",
  "common.engine.tests.PuzzleTests",
  "common.engine.tests.ReplayTests",
  "common.engine.tests.StackReplayTests",
  "common.engine.tests.StackRollbackReplayTests",
  "common.engine.tests.StackTouchReplayTests",
}

local updateCount = 0
function love.update(dt)
  if tests[updateCount] then
    logger.info("running test file " .. tests[updateCount])
    require(tests[updateCount])
  end
  updateCount = updateCount + 1
end

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
local logger = require("common.lib.logger")

local function runTestFile(filename)
  logger.info("running " .. filename)
  require(filename)
end

runTestFile("common.engine.tests.GarbageQueueTests")
runTestFile("common.engine.tests.HealthTests")
runTestFile("common.engine.tests.PanelGenTests")
runTestFile("common.engine.tests.PuzzleTests")
runTestFile("common.engine.tests.ReplayTests")
runTestFile("common.engine.tests.StackReplayTests")
runTestFile("common.engine.tests.StackRollbackReplayTests")
runTestFile("common.engine.tests.StackTests")
runTestFile("common.engine.tests.StackTouchReplayTests")
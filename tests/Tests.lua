local logger = require("logger")

function runTestFile(filename)
  logger.info("running " .. filename)
  require(filename)
end

-- In Development, so you don't have to wait for all other tests to debug (move to correct location later)
-- Small tests (unit tests)
runTestFile("ServerQueueTests")
runTestFile("tests.JsonEncodingTests")
runTestFile("tests.NetworkProtocolTests")
runTestFile("tests.TouchDataEncodingTests")
runTestFile("tests.utf8AdditionsTests")
runTestFile("tests.QueueTests")
--runTestFile("tests.TimeQueueTests")
runTestFile("tableUtilsTest")
runTestFile("utilTests")

if SERVER_MODE then
  runTestFile("tests.ConnectionTests")
else
  runTestFile("StackTests")
  --runTestFile("tests.StackGraphicsTests")
  runTestFile("tests.InputTests")
  runTestFile("PuzzleTests")
  runTestFile("tests.PanelGenTests")
  runTestFile("tests.ThemeTests")
end
--runTestFile("AttackFileGenerator") -- TODO: Not really a unit test... generates attack files

-- Medium level tests (integration tests)
if not SERVER_MODE then
  runTestFile("tests.TcpClientTests")
  runTestFile("tests.ReplayTests")
  runTestFile("tests.StackReplayTests")
  runTestFile("tests.StackRollbackReplayTests")
  runTestFile("tests.StackTouchReplayTests")
  runTestFile("tests.GarbageQueueTests")
end
-- In Development, so you don't have to wait for all other tests to debug (move to correct location later)
-- Small tests (unit tests)
require("ServerQueueTests")
require("tests.ConnectionTests")
require("tests.HealthTests")
require("tests.JsonEncodingTests")
require("tests.NetworkProtocolTests")
require("tests.TouchDataEncodingTests")
require("tests.utf8AdditionsTests")
require("tests.QueueTests")
require("tests.TimeQueueTests")
require("tableUtilsTest")
require("utilTests")

if not SERVER_MODE then
  require("StackTests")
  require("tests.StackGraphicsTests")
  require("tests.InputTests")
  require("PuzzleTests")
  require("tests.ThemeTests")
end
--require("AttackFileGenerator") -- TODO: Not really a unit test... generates attack files

-- Medium level tests (integration tests)
if not SERVER_MODE then
  require("tests.ReplayTests")
  require("tests.StackReplayTests")
  require("tests.StackRollbackReplayTests")
  require("tests.StackTouchReplayTests")
  require("tests.GarbageQueueTests")
end
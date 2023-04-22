-- In Development, so you don't have to wait for all other tests to debug (move to correct location later)

-- Small tests (unit tests)
require("PuzzleTests")
require("ServerQueueTests")
require("StackTests")
require("tests.JsonEncodingTests")
require("tests.NetworkProtocolTests")
require("tests.ThemeTests")
require("tests.TouchDataEncodingTests")
require("tests.utf8AdditionsTests")
require("table_util_tests")
require("utilTests")
-- Medium level tests (integration tests)
require("tests.ReplayTests")
require("tests.StackReplayTests")
require("tests.StackRollbackReplayTests")
require("tests.StackTouchReplayTests")
require("tests.GarbageQueueTests")
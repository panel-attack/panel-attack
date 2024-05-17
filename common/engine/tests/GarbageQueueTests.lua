local GarbageQueueTestingUtils = require("tests.GarbageQueueTestingUtils")
local tableUtils = require("tableUtils")

-- 150 frames
local minTransferTime = GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME + GARBAGE_DELAY_LAND_TIME

local function testComboQueueing1()
  local match = GarbageQueueTestingUtils.createMatch()
  local P1 = match.P1
  GarbageQueueTestingUtils.runToFrame(match, 350)
  GarbageQueueTestingUtils.sendGarbage(P1, 4, 1)
  GarbageQueueTestingUtils.runToFrame(match, 420)
  GarbageQueueTestingUtils.sendGarbage(P1, 3, 1)
  assert(#P1.later_garbage == 0, "3 wide should delay 4 wide so that both are still in telegraph")
  assert(P1.telegraph.garbage_queue:len() == 2, "3 wide should delay 4 wide so that both are still in telegraph")
  local highestPriorityGarbage = P1.telegraph.garbage_queue:peek()
  assert(highestPriorityGarbage[1] == 3, "3 wide should queue before 4 wide")
  GarbageQueueTestingUtils.runToFrame(match, 470)
  GarbageQueueTestingUtils.sendGarbage(P1, 5, 1)
  GarbageQueueTestingUtils.runToFrame(match, 511)
  assert(tableUtils.length(P1.later_garbage) == 1, "3 and 4 wide should've left telegraph together")
  assert(P1.later_garbage[420 + minTransferTime], "3 wide should've managed to pass through telegraph in the shortest time possible")
  assert(P1.telegraph.garbage_queue:len() == 1, "5 wide should still be inside")
end

testComboQueueing1()
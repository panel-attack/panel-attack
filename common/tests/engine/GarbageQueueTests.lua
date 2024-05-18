local GarbageQueueTestingUtils = require("common.engine.tests.GarbageQueueTestingUtils")
local StackReplayTestingUtils = require("common.engine.tests.StackReplayTestingUtils")
local tableUtils = require("common.lib.tableUtils")
require("client.src.globals")

-- 150 frames
local minTransferTime = GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME + GARBAGE_DELAY_LAND_TIME

local function testComboQueueing1()
  local match = GarbageQueueTestingUtils.createMatch()
  local stack = match.stacks[1]
  GarbageQueueTestingUtils.runToFrame(match, 350)
  GarbageQueueTestingUtils.sendGarbage(stack, 4, 1)
  GarbageQueueTestingUtils.runToFrame(match, 420)
  GarbageQueueTestingUtils.sendGarbage(stack, 3, 1)
  assert(#stack.later_garbage == 0, "3 wide should delay 4 wide so that both are still in telegraph")
  assert(stack.telegraph.garbage_queue:len() == 2, "3 wide should delay 4 wide so that both are still in telegraph")
  local highestPriorityGarbage = stack.telegraph.garbage_queue:peek()
  assert(highestPriorityGarbage[1] == 3, "3 wide should queue before 4 wide")
  GarbageQueueTestingUtils.runToFrame(match, 470)
  GarbageQueueTestingUtils.sendGarbage(stack, 5, 1)
  GarbageQueueTestingUtils.runToFrame(match, 511)
  assert(tableUtils.length(stack.later_garbage) == 1, "3 and 4 wide should've left telegraph together")
  assert(stack.later_garbage[420 + minTransferTime], "3 wide should've managed to pass through telegraph in the shortest time possible")
  assert(stack.telegraph.garbage_queue:len() == 1, "5 wide should still be inside")
  StackReplayTestingUtils:cleanup(match)
end

testComboQueueing1()
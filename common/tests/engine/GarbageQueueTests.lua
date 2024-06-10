local GarbageQueueTestingUtils = require("common.tests.engine.GarbageQueueTestingUtils")
local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local tableUtils = require("common.lib.tableUtils")
require("client.src.globals")

-- 150 frames
-- (+1 because in the past the frame garbage was considered earned on had a +1 on it and the 150 was from there
-- that is now gone so the transit time effectively got extended by +1
local minTransferTime = GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME + GARBAGE_DELAY_LAND_TIME + 1

local function testComboQueueing1()
  local match = GarbageQueueTestingUtils.createMatch()
  local stack = match.stacks[1]
  GarbageQueueTestingUtils.runToFrame(match, 350)
  GarbageQueueTestingUtils.sendGarbage(stack, 4, 1)
  GarbageQueueTestingUtils.runToFrame(match, 420)
  GarbageQueueTestingUtils.sendGarbage(stack, 3, 1)
  assert(#stack.outgoingGarbage.garbageInTransit == 0, "3 wide should delay 4 wide so that both are still in staging")
  assert(stack.outgoingGarbage:len() == 2, "3 wide should delay 4 wide so that both are still in staging")
  assert(stack.outgoingGarbage:peek().width == 3, "3 wide should queue before 4 wide")
  GarbageQueueTestingUtils.runToFrame(match, 470)
  GarbageQueueTestingUtils.sendGarbage(stack, 5, 1)
  GarbageQueueTestingUtils.runToFrame(match, 512)
  assert(tableUtils.length(stack.outgoingGarbage.garbageInTransit) == 1, "3 and 4 wide should've left telegraph together")
  assert(stack.outgoingGarbage.garbageInTransit[420 + minTransferTime], "3 wide should've managed to pass through telegraph in the shortest time possible")
  assert(stack.outgoingGarbage:len() == 1, "5 wide should still be inside")
  StackReplayTestingUtils:cleanup(match)
end

testComboQueueing1()
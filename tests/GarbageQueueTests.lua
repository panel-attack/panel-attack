local GarbageQueueTestingUtils = require("tests.GarbageQueueTestingUtils")

local attackFile = "/tests/attackFiles/dumpAttackPatternGarache GQ.json"

local function testGarbageQueue1()
  local match = GarbageQueueTestingUtils.createMatch(attackFile)
  GarbageQueueTestingUtils.runToFrame(match, 1500)
end

testGarbageQueue1()
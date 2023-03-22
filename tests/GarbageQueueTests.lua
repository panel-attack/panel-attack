local AttackEngineTestingUtils = require("tests.AttackEngineTestingUtils")

local attackFile = "/tests/attackFiles/dumpAttackPatternGarache GQ.json"

local function testGarbageQueue1()
  local match = AttackEngineTestingUtils.createMatch(attackFile)
  AttackEngineTestingUtils.runToFrame(match, 500)
end
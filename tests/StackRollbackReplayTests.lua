require("table_util")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")
local testReplayFolder = "tests/replays/"


-- Vs rollback one player way behind
-- We need to make sure we remove garbage sent "in the future" so its not duplicated
local function rollbackPastAttackTest()
  match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  local startClock = 462
  local aheadTime = 500
  local garbageTelegraphPopTime = 463
  local rollbackTime = garbageTelegraphPopTime
  StackReplayTestingUtils:simulateMatch(match, startClock)
  StackReplayTestingUtils:simulateStack(match.P1, aheadTime)

  -- Simulate to a point P1 has sent an attack to P2
  assert(#match.P2.later_garbage[523] == 1)

  -- Rollback P1 past the time the attack popped off telegraph
  match:debugRollbackAndCaptureState(rollbackTime)

  -- This should cause the attack to be undone
  assert(match.P2.later_garbage[523] == nil)

  -- Simulate again, attack shoudld pop off again
  StackReplayTestingUtils:simulateMatch(match, aheadTime)

  assert(match.P2.later_garbage[523] ~= nil and #match.P2.later_garbage[523] == 1)

  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.mode == "vs")
  assert(match.seed == 2992240)
  assert(match.P1.game_over_clock == 2039)
  assert(match.P1.level == 10)
  assert(table.length(match.P1.chains) == 4)
  assert(table.length(match.P1.combos) == 4)
  assert(match.P2.game_over_clock == 0)
  assert(match.P2.level == 10)
  assert(table.length(match.P2.chains) == 4)
  assert(table.length(match.P2.combos) == 4)
end

rollbackPastAttackTest()


-- Vs rollback just one frame on both stacks
-- We need to make sure we don't remove garbage if we didn't rollback far enough to mess with it.
local function rollbackNotPastAttackTest()
  match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  local startClock = 462
  local aheadTime = 500
  local garbageTelegraphPopTime = 463
  local rollbackTime = garbageTelegraphPopTime + 1
  StackReplayTestingUtils:simulateMatch(match, startClock)
  StackReplayTestingUtils:simulateStack(match.P1, aheadTime)

  -- Simulate to a point P1 has sent an attack to P2
  assert(#match.P2.later_garbage[523] == 1)

  -- Rollback P1 but not past the time the attack popped off telegraph
  match:debugRollbackAndCaptureState(rollbackTime)
  assert(match.P2.later_garbage[523] ~= nil and #match.P2.later_garbage[523] == 1)

  -- Simulate again, attack shouldn't pop off again
  StackReplayTestingUtils:simulateMatch(match, aheadTime)

  assert(match.P2.later_garbage[523] ~= nil and #match.P2.later_garbage[523] == 1)

  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.mode == "vs")
  assert(match.seed == 2992240)
  assert(match.P1.game_over_clock == 2039)
  assert(match.P1.level == 10)
  assert(table.length(match.P1.chains) == 4)
  assert(table.length(match.P1.combos) == 4)
  assert(match.P2.game_over_clock == 0)
  assert(match.P2.level == 10)
  assert(table.length(match.P2.chains) == 4)
  assert(table.length(match.P2.combos) == 4)
end

rollbackNotPastAttackTest()
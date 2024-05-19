local tableUtils = require("common.lib.tableUtils")
local StackReplayTestingUtils = require("common.engine.tests.StackReplayTestingUtils")
local GameModes = require("common.engine.GameModes")
local logger = require("common.lib.logger")

local testReplayFolder = "common/engine/tests/replays/"

-- Vs rollback one player way behind
-- We need to make sure we remove garbage sent "in the future" so its not duplicated
local function rollbackPastAttackTest()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  local startClock = 462
  local aheadTime = 500
  local garbageTelegraphPopTime = 463
  local rollbackTime = garbageTelegraphPopTime
  StackReplayTestingUtils:simulateMatchUntil(match, startClock)
  StackReplayTestingUtils:simulateStack(match.P1, aheadTime)

  -- Simulate to a point P1 has sent an attack to P2
  assert(#match.P2.later_garbage[523] == 1)

  -- Rollback P1 past the time the attack popped off telegraph
  match:debugRollbackAndCaptureState(rollbackTime)

  -- This should cause the attack to be undone
  assert(match.P2.later_garbage[523] == nil)

  -- Simulate again, attack shoudld pop off again
  StackReplayTestingUtils:simulateMatchUntil(match, aheadTime)

  assert(match.P2.later_garbage[523] ~= nil and #match.P2.later_garbage[523] == 1)

  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.seed == 2992240)
  assert(match.P1.game_over_clock == 2039)
  assert(match.P1.level == 10)
  assert(tableUtils.length(match.P1.chains) == 4)
  assert(tableUtils.length(match.P1.combos) == 4)
  assert(match.P2.game_over_clock <= 0)
  assert(match.P2.level == 10)
  assert(tableUtils.length(match.P2.chains) == 4)
  assert(tableUtils.length(match.P2.combos) == 4)
  StackReplayTestingUtils:cleanup(match)
end

logger.info("running rollbackPastAttackTest")
rollbackPastAttackTest()

-- Vs rollback just one frame on both stacks
-- We need to make sure we don't remove garbage if we didn't rollback far enough to mess with it.
local function rollbackNotPastAttackTest()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  local startClock = 462
  local aheadTime = 500
  local garbageTelegraphPopTime = 463
  local rollbackTime = garbageTelegraphPopTime + 1
  StackReplayTestingUtils:simulateMatchUntil(match, startClock)
  StackReplayTestingUtils:simulateStack(match.P1, aheadTime)

  -- Simulate to a point P1 has sent an attack to P2
  assert(#match.P2.later_garbage[523] == 1)

  -- Rollback P1 but not past the time the attack popped off telegraph
  match:debugRollbackAndCaptureState(rollbackTime)
  assert(match.P2.later_garbage[523] ~= nil and #match.P2.later_garbage[523] == 1)

  -- Simulate again, attack shouldn't pop off again
  StackReplayTestingUtils:simulateMatchUntil(match, aheadTime)

  assert(match.P2.later_garbage[523] ~= nil and #match.P2.later_garbage[523] == 1)

  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.stackInteraction == GameModes.StackInteractions.VERSUS)
  assert(match.seed == 2992240)
  assert(match.P1.game_over_clock == 2039)
  assert(match.P1.level == 10)
  assert(tableUtils.length(match.P1.chains) == 4)
  assert(tableUtils.length(match.P1.combos) == 4)
  assert(match.P2.game_over_clock <= 0)
  assert(match.P2.level == 10)
  assert(tableUtils.length(match.P2.chains) == 4)
  assert(tableUtils.length(match.P2.combos) == 4)
  StackReplayTestingUtils:cleanup(match)
end

logger.info("running rollbackNotPastAttackTest")
rollbackNotPastAttackTest()

-- Vs rollback before attack even happened
-- Make sure the attack only happens once and only once if we rollback before it happened
local function rollbackFullyPastAttack()
  local match = StackReplayTestingUtils:setupReplayWithPath(testReplayFolder .. "v046-2023-02-01-05-38-16-vsSelf-L8.txt")

  StackReplayTestingUtils:simulateMatchUntil(match, 360)
  assert(match.P1.combos[344] ~= nil and match.P1.combos[344][1].width == 3)

  match:debugRollbackAndCaptureState(344)
  assert(match.P1.combos[344] == nil)

  StackReplayTestingUtils:simulateMatchUntil(match, 480)

  assert(match.P1.chains[428] ~= nil and match.P1.chains[428].size == 2)
  assert(match.P1.combos[344] ~= nil and match.P1.combos[344][1].width == 3)

  match:debugRollbackAndCaptureState(420)
  assert(match.P1.chains[428] == nil)
  assert(match.P1.combos[344] ~= nil and match.P1.combos[344][1].width == 3)

  StackReplayTestingUtils:simulateMatchUntil(match, 480)
  assert(match.P1.chains[428] ~= nil and match.P1.chains[428].size == 2)
  assert(match.P1.combos[344] ~= nil and match.P1.combos[344][1].width == 3)

  StackReplayTestingUtils:simulateMatchUntil(match, 637)
  assert(match.P1.chains[428] ~= nil)
  assert(match.P1.chains[428].size == 4)
  assert(match.P1.chains[428].starts[1] == 428)
  assert(match.P1.chains[428].starts[2] == 499)
  assert(match.P1.chains[428].starts[3] == 571)
  assert(match.P1.chains[428].finish == 636)

  match:debugRollbackAndCaptureState(570)
  assert(match.P1.currentChainStartFrame == 428)
  assert(match.P1.chains[428] ~= nil)
  assert(match.P1.chains[428].size == 3)
  assert(match.P1.chains[428].starts[1] == 428)
  assert(match.P1.chains[428].starts[2] == 499)
  assert(match.P1.chains[428].starts[3] == nil)
  assert(match.P1.chains[428].finish == nil)

  StackReplayTestingUtils:fullySimulateMatch(match)
  assert(match.P1.chains[428] ~= nil)
  assert(match.P1.chains[428].size == 4)
  assert(match.P1.chains[428].starts[1] == 428)
  assert(match.P1.chains[428].starts[2] == 499)
  assert(match.P1.chains[428].starts[3] == 571)
  assert(match.P1.chains[428].finish == 636)
  assert(match.P1.combos[344] ~= nil and match.P1.combos[344][1].width == 3)
  assert(match ~= nil)
  assert(match.stackInteraction == GameModes.StackInteractions.SELF)
  assert(match.seed == 3917661)
  assert(match.P1.game_over_clock == 797)
  assert(match.P1.level == 8)
  assert(tableUtils.length(match.P1.chains) == 1)
  assert(tableUtils.length(match.P1.combos) == 1)
  StackReplayTestingUtils:cleanup(match)
end

logger.info("running rollbackFullyPastAttack")
rollbackFullyPastAttack()
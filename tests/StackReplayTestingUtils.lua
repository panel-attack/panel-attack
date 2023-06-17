local logger = require("logger")

local StackReplayTestingUtils = {}

function StackReplayTestingUtils:simulateReplayWithPath(path)
  local match = self:setupReplayWithPath(path)
  return self:fullySimulateMatch(match)
end

function StackReplayTestingUtils.createEndlessMatch(speed, difficulty, level)
  local match = Match("endless")
  match.seed = 1
  local P1 = Stack{which=1, match=match, wantsCanvas=false, is_local=false, panels_dir=config.panels, speed=speed, difficulty=difficulty, level=level, character=config.character, inputMethod="controller"}
  P1.max_runs_per_frame = 1
  match.P1 = P1
  P1:wait_for_random_character()
  P1:starting_state()

  return match
end

function StackReplayTestingUtils:fullySimulateMatch(match)
  local startTime = love.timer.getTime()

  local gameResult = match.P1:gameResult()
  while gameResult == nil do
      match:run()
      gameResult = match.P1:gameResult()
  end
  local endTime = love.timer.getTime()

  self:cleanupReplay()

  return match, endTime - startTime
end

function StackReplayTestingUtils:simulateStack(stack, clockGoal)
  while stack.clock < clockGoal do
    stack:run()
    stack:saveForRollback()
  end
  assert(stack.clock == clockGoal)
end

function StackReplayTestingUtils:simulateMatchUntil(match, clockGoal)
  assert(match.P1.is_local == false, "Don't use 'local' for tests, we might simulate the clock time too much if local")
  while match.P1.clock < clockGoal do
    assert(match:matchOutcome() == nil, "Game isn't expected to end yet")
    assert(#match.P1.input_buffer > 0)
    match:run()
  end
  assert(match.P1.clock == clockGoal)
end

-- Runs the given clock time both with and without rollback
function StackReplayTestingUtils:simulateMatchWithRollbackAtClock(match, clock)
  StackReplayTestingUtils:simulateMatchUntil(match, clock)
  match:debugRollbackAndCaptureState(clock-1)
  StackReplayTestingUtils:simulateMatchUntil(match, clock)
end

function StackReplayTestingUtils:setupReplayWithPath(path)
  GAME.muteSoundEffects = true

  Replay.loadFromPath(path)
  Replay.loadFromFile(replay, false)

  assert(GAME ~= nil)
  assert(GAME.match ~= nil)
  assert(GAME.match.P1 ~= nil)

  local match = GAME.match

  return match
end

function StackReplayTestingUtils:cleanupReplay()
  reset_filters()
  stop_the_music()
  replay = {}
  GAME:reset()
end

return StackReplayTestingUtils
local StackReplayTestingUtils = {}

function StackReplayTestingUtils:simulateReplayWithPath(path)
        
  GAME.muteSoundEffects = true

  Replay.loadFromPath(path)
  Replay.loadFromFile(replay)

  assert(GAME ~= nil)
  assert(GAME.match ~= nil)
  assert(GAME.match.P1 ~= nil)
  assert(GAME.match.P2 ~= nil)

  local match = GAME.match

  local startTime = love.timer.getTime()

  local matchOutcome = match.battleRoom:matchOutcome()
  while matchOutcome == nil do
      match:run()
      matchOutcome = match.battleRoom:matchOutcome()
  end
  local endTime = love.timer.getTime()

  reset_filters()
  stop_the_music()
  replay = {}
  GAME:reset()
  return match, endTime - startTime
end

return StackReplayTestingUtils
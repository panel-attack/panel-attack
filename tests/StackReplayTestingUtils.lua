local StackReplayTestingUtils = {}

function StackReplayTestingUtils:simulateReplayWithPath(path)
        
  GAME.muteSoundEffects = true

  Replay.loadFromPath(path)
  Replay.loadFromFile(replay)

  assert(GAME ~= nil)
  assert(GAME.match ~= nil)
  assert(GAME.match.P1 ~= nil)

  local match = GAME.match

  local startTime = love.timer.getTime()

  local gameResult = match.P1:gameResult()
  while gameResult == nil do
      match:run()
      gameResult = match.P1:gameResult()
  end
  local endTime = love.timer.getTime()

  reset_filters()
  stop_the_music()
  replay = {}
  GAME:reset()
  return match, endTime - startTime
end

return StackReplayTestingUtils
local logger = require("logger")
local GameModes = require("GameModes")
local Player = require("Player")
local LevelPresets = require("LevelPresets")

local StackReplayTestingUtils = {}

function StackReplayTestingUtils:simulateReplayWithPath(path)
  local match = self:setupReplayWithPath(path)
  return self:fullySimulateMatch(match)
end

function StackReplayTestingUtils.createEndlessMatch(speed, difficulty, level, wantsCanvas, playerCount, theme)
  if playerCount == nil then
    playerCount = 1
  end
  local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_ENDLESS"))
  battleRoom.players[1].settings.speed = speed
  battleRoom.players[1].settings.difficulty = difficulty
  battleRoom.players[1].settings.level = level
  if level then
    battleRoom.players[1].settings.style = GameModes.Styles.MODERN
  else
    battleRoom.players[1].settings.style = GameModes.Styles.CLASSIC
  end

  if playerCount == 2 then
    local player = Player.getLocalPlayer()
    player.settings.speed = speed
    player.settings.difficulty = difficulty
    player.settings.level = level
    if level then
      player.settings.style = GameModes.Styles.MODERN
    else
      player.settings.style = GameModes.Styles.CLASSIC
    end
    battleRoom:addPlayer(player)
  end

  local match = battleRoom:createMatch()
  match:setSeed(1)
  match:start()
  if not wantsCanvas then
    match:removeCanvases()
  end
  for i = 1, #match.players do
    match.players[i].stack.max_runs_per_frame = 1
  end

  return match
end

function StackReplayTestingUtils:fullySimulateMatch(match)
  local startTime = love.timer.getTime()

  local gameResult = match.P1:gameResult()
  while gameResult == nil do
    if match.P1.clock == 2039 then
      local phi = 5
    end
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
    assert(not match:hasEnded(), "Game isn't expected to end yet")
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

  local success, replay = Replay.loadFromPath(path)
  local match = Match.createFromReplay(replay, false)
  match:start(replay)
  match:removeCanvases()

  assert(GAME ~= nil)
  assert(match ~= nil)
  assert(match.P1)

  return match
end

function StackReplayTestingUtils:cleanupReplay()
  stop_the_music()
  replay = {}
  GAME:reset()
end

return StackReplayTestingUtils
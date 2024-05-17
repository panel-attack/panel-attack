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
  local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_ENDLESS"))
  if playerCount == nil then
    playerCount = 1
  elseif playerCount == 2 then
    local player = Player.getLocalPlayer()
    battleRoom:addPlayer(player)
  end
  for _, player in ipairs(battleRoom.players) do
    if speed then
      player:setSpeed(speed)
    end
    if difficulty then
      player:setDifficulty(difficulty)
    end
    if level then
      player:setLevel(level)
    end
  end

  if level then
    battleRoom:setStyle(GameModes.Styles.MODERN)
  else
    battleRoom:setStyle(GameModes.Styles.CLASSIC)
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

  while not match:hasEnded() do
    match:run()
  end
  local endTime = love.timer.getTime()

  self:cleanup(match)

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
  GAME.muteSound = true

  local success, replay = Replay.loadFromPath(path)
  local match = Match.createFromReplay(replay, false)
  match:start(replay)
  match:removeCanvases()

  assert(GAME ~= nil)
  assert(match ~= nil)
  assert(match.P1)

  return match
end

function StackReplayTestingUtils:cleanup(match)
  if match then
    match:deinit()
  end
  GAME:reset()
end

return StackReplayTestingUtils
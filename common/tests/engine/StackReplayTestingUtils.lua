local logger = require("common.lib.logger")
local GameModes = require("common.engine.GameModes")
local Player = require("client.src.Player")
local Match = require("common.engine.Match")
local inputs = require("common.lib.inputManager")
local fileUtils = require("client.src.FileUtils")

local StackReplayTestingUtils = {}

function StackReplayTestingUtils:simulateReplayWithPath(path)
  local match = self:setupReplayWithPath(path)
  return self:fullySimulateMatch(match)
end

function StackReplayTestingUtils.createEndlessMatch(speed, difficulty, level, wantsCanvas, playerCount, theme)
  local endless = GameModes.getPreset("ONE_PLAYER_ENDLESS")
  local players = {}
  if playerCount == nil then
    playerCount = 1
  end
  for i = 1, playerCount do
    local player = Player.getLocalPlayer()
    player.isLocal = false
    if speed then
      player:setSpeed(speed)
    end
    if difficulty then
      player:setDifficulty(difficulty)
    end
    if level then
      player:setLevel(level)
      player:setStyle(GameModes.Styles.MODERN)
    else
      player:setStyle(GameModes.Styles.CLASSIC)
    end
    --player:restrictInputs(inputs.inputConfigurations[i])
    players[#players+1] = player
  end

  local match = Match(players, endless.doCountdown, endless.stackInteraction, endless.winConditions, endless.gameOverConditions, false)
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

function StackReplayTestingUtils.createSinglePlayerMatch(gameMode)
  local players = { Player.getLocalPlayer() }
  players[1].isLocal = false

  local match = Match(players, gameMode.doCountdown, gameMode.stackInteraction, gameMode.winConditions, gameMode.gameOverConditions, false)
  match:setSeed(1)
  match:start()
  match:removeCanvases()

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
  assert(match.stacks[1].is_local == false, "Don't use 'local' for tests, we might simulate the clock time too much if local")
  while match.stacks[1].clock < clockGoal do
    assert(not match:hasEnded(), "Game isn't expected to end yet")
    assert(#match.stacks[1].input_buffer > 0)
    match:run()
  end
  assert(match.stacks[1].clock == clockGoal)
end

-- Runs the given clock time both with and without rollback
function StackReplayTestingUtils:simulateMatchWithRollbackAtClock(match, clock)
  StackReplayTestingUtils:simulateMatchUntil(match, clock)
  match:debugRollbackAndCaptureState(clock-1)
  StackReplayTestingUtils:simulateMatchUntil(match, clock)
end

function StackReplayTestingUtils:setupReplayWithPath(path)
  GAME.muteSound = true

  local success, replay = Replay.load(fileUtils.readJsonFile(path))
  local match = Match.createFromReplay(replay, false)
  match:start(replay)
  match:removeCanvases()

  assert(GAME ~= nil)
  assert(match ~= nil)
  assert(match.stacks[1])

  return match
end

function StackReplayTestingUtils:cleanup(match)
  for _, player in ipairs(match.players) do
    if player.human and player.playerNumber and player.inputConfiguration then
      player:unrestrictInputs()
    end
  end
  if match then
    match:deinit()
  end
end

return StackReplayTestingUtils
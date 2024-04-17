local consts = require("consts")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")
local GameModes = require("GameModes")
local Player = require("Player")

local function puzzleTest()
  -- to stop rising
  local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_PUZZLE"))
  local puzzle = Puzzle(nil, nil, 1, "011010")
  battleRoom.players[1].settings.level = 5
  local match = battleRoom:createMatch()
  match:start()
  local stack = battleRoom.players[1].stack
  stack:set_puzzle_state(puzzle)

  assert(stack.panels[1][1].color == 0, "wrong color")
  assert(stack.panels[1][2].color == 1, "wrong color")

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames ?!
  match:run()
  match:run()
  assert(stack:canSwap(1, 4), "should be able to swap")

  stop_the_music()
end

puzzleTest()

local function clearPuzzleTest()
  local battleRoom = BattleRoom.createLocalFromGameMode(GameModes.getPreset("ONE_PLAYER_PUZZLE"))
  local puzzle = Puzzle("clear", false, 0, "[============================][====]246260[====]600016514213466313451511124242", 60, 0)
  battleRoom.players[1].settings.level = 5
  local match = battleRoom:createMatch()
  match:start()
  local stack = battleRoom.players[1].stack
  stack:set_puzzle_state(puzzle)

  assert(stack.panels[1][1].color == 1, "wrong color")
  assert(stack.panels[1][2].color == 2, "wrong color")

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames ?!
  match:run()
  match:run()
  assert(stack:canSwap(1, 4), "should be able to swap")

  stop_the_music()
end

clearPuzzleTest()

local function basicSwapTest()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  local stack = match.P1

  stack.do_countdown = false

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames
  StackReplayTestingUtils:simulateMatchUntil(match, 2)

  assert(stack:canSwap(1, 1), "should be able to swap")
  stack:setQueuedSwapPosition(1, 1)
  assert(stack.queuedSwapRow == 1)
  stack:new_row()
  assert(stack.queuedSwapRow == 2)

  stop_the_music()
end

basicSwapTest()

local function moveAfterCountdownV46Test()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.engineVersion = consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE
  local stack = match.P1
  stack.do_countdown = true
  stack:wait_for_random_character()
  assert(characters ~= nil, "no characters")
  local lastBlockedCursorMovementFrame = 33
  stack:receiveConfirmedInput(string.rep(stack:idleInput(), lastBlockedCursorMovementFrame + 1))

  StackReplayTestingUtils:simulateMatchUntil(match, lastBlockedCursorMovementFrame)
  assert(stack.cursorLock ~= nil, "Cursor should be locked up to last frame of countdown")

  StackReplayTestingUtils:simulateMatchUntil(match, lastBlockedCursorMovementFrame + 1)
  assert(stack.cursorLock == nil, "Cursor should not be locked after countdown")

  stop_the_music()
end

moveAfterCountdownV46Test()
local consts = require("common.engine.consts")
local StackReplayTestingUtils = require("common.tests.engine.StackReplayTestingUtils")
local GameModes = require("common.engine.GameModes")
local Puzzle = require("common.engine.Puzzle")
local Player = require("client.src.Player")

local function puzzleTest()
  -- to stop rising
  local match = StackReplayTestingUtils.createSinglePlayerMatch(GameModes.getPreset("ONE_PLAYER_PUZZLE"))
  local puzzle = Puzzle(nil, nil, 1, "011010")
  local stack = match.stacks[1]
  stack:set_puzzle_state(puzzle)

  assert(stack.panels[1][1].color == 0, "wrong color")
  assert(stack.panels[1][2].color == 1, "wrong color")

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames ?!
  match:run()
  match:run()
  assert(stack:canSwap(1, 4), "should be able to swap")
  StackReplayTestingUtils:cleanup(match)
end

puzzleTest()

local function clearPuzzleTest()
  local match = StackReplayTestingUtils.createSinglePlayerMatch(GameModes.getPreset("ONE_PLAYER_PUZZLE"))
  local puzzle = Puzzle("clear", false, 0, "[============================][====]246260[====]600016514213466313451511124242", 60, 0)
  local stack = match.stacks[1]
  stack:set_puzzle_state(puzzle)

  assert(stack.panels[1][1].color == 1, "wrong color")
  assert(stack.panels[1][2].color == 2, "wrong color")

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames ?!
  match:run()
  match:run()
  assert(stack:canSwap(1, 4), "should be able to swap")
  StackReplayTestingUtils:cleanup(match)
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
  StackReplayTestingUtils:cleanup(match)
end

basicSwapTest()

local function moveAfterCountdownV46Test()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.engineVersion = consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE
  local stack = match.P1
  stack.do_countdown = true
  assert(characters ~= nil, "no characters")
  local lastBlockedCursorMovementFrame = 33
  stack:receiveConfirmedInput(string.rep(stack:idleInput(), lastBlockedCursorMovementFrame + 1))

  StackReplayTestingUtils:simulateMatchUntil(match, lastBlockedCursorMovementFrame)
  assert(stack.cursorLock ~= nil, "Cursor should be locked up to last frame of countdown")

  StackReplayTestingUtils:simulateMatchUntil(match, lastBlockedCursorMovementFrame + 1)
  assert(stack.cursorLock == nil, "Cursor should not be locked after countdown")
  StackReplayTestingUtils:cleanup(match)
end

moveAfterCountdownV46Test()

local function testShakeFrames()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.seed = 1 -- so we consistently have a panel to swap
  match.engineVersion = consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE
  local stack = match.P1

  -- imaginary garbage should crash
  assert(pcall(stack.shakeFrameForGarbageSize, 6, 0) == false)
  assert(pcall(stack.shakeFrameForGarbageSize, 6, -1) == false)

  assert(stack:shakeFramesForGarbageSize(1, 1) == 18)
  assert(stack:shakeFramesForGarbageSize(2, 1) == 18)
  assert(stack:shakeFramesForGarbageSize(1, 2) == 18)
  assert(stack:shakeFramesForGarbageSize(3, 1) == 18)
  assert(stack:shakeFramesForGarbageSize(4, 1) == 18)
  assert(stack:shakeFramesForGarbageSize(2, 2) == 18)
  assert(stack:shakeFramesForGarbageSize(5, 1) == 24)
  assert(stack:shakeFramesForGarbageSize(6, 1) == 42)
  assert(stack:shakeFramesForGarbageSize(3, 2) == 42)
  assert(stack:shakeFramesForGarbageSize(7, 1) == 42)
  assert(stack:shakeFramesForGarbageSize(4, 2) == 42)
  assert(stack:shakeFramesForGarbageSize(3, 3) == 42)
  assert(stack:shakeFramesForGarbageSize(5, 2) == 42)
  assert(stack:shakeFramesForGarbageSize(11, 1) == 42)
  assert(stack:shakeFramesForGarbageSize(6, 2) == 66)
  assert(stack:shakeFramesForGarbageSize(13, 1) == 66)
  assert(stack:shakeFramesForGarbageSize(7, 2) == 66)
  assert(stack:shakeFramesForGarbageSize(5, 3) == 66)
  assert(stack:shakeFramesForGarbageSize(4, 4) == 66)
  assert(stack:shakeFramesForGarbageSize(17, 1) == 66)
  assert(stack:shakeFramesForGarbageSize(6, 3) == 66)
  assert(stack:shakeFramesForGarbageSize(19, 1) == 66)
  assert(stack:shakeFramesForGarbageSize(5, 4) == 66)
  assert(stack:shakeFramesForGarbageSize(7, 3) == 66)
  assert(stack:shakeFramesForGarbageSize(11, 2) == 66)
  assert(stack:shakeFramesForGarbageSize(23, 1) == 66)
  assert(stack:shakeFramesForGarbageSize(6, 4) == 76)
  assert(stack:shakeFramesForGarbageSize(5, 5) == 76)
  assert(stack:shakeFramesForGarbageSize(6, 8) == 76)
  assert(stack:shakeFramesForGarbageSize(6, 1000) == 76)
  StackReplayTestingUtils:cleanup(match)
end

testShakeFrames()
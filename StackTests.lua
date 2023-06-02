local consts = require("consts")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")

local function puzzleTest()
  local match = Match("puzzle") -- to stop rising
  local stack = Stack{which=1, match=match, wantsCanvas=false, is_local=false, level=5, inputMethod="controller"}
  match.P1 = stack
  stack.do_countdown = false
  stack:wait_for_random_character()

  assert(characters ~= nil, "no characters")
  stack:set_puzzle_state(Puzzle(nil, nil, 1, "011010"))

  assert(stack.panels[1][1].color == 0, "wrong color")
  assert(stack.panels[1][2].color == 1, "wrong color")

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames ?!
  match:run()
  match:run()
  assert(stack:canSwap(1, 4), "should be able to swap")

  reset_filters()
  stop_the_music()
end

puzzleTest()

local function clearPuzzleTest()
  local match = Match("puzzle") -- to stop rising
  local stack = Stack{which=1, match=match, wantsCanvas=false, is_local=false, level=5, inputMethod="controller"}
  match.P1 = stack
  stack.do_countdown = false
  stack:wait_for_random_character()

  assert(characters ~= nil, "no characters")
  stack:set_puzzle_state(Puzzle("clear", false, 0, "[============================][====]246260[====]600016514213466313451511124242", 60, 0))

  assert(stack.panels[1][1].color == 1, "wrong color")
  assert(stack.panels[1][2].color == 2, "wrong color")

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames ?!
  match:run()
  match:run()
  assert(stack:canSwap(1, 4), "should be able to swap")

  reset_filters()
  stop_the_music()
end

clearPuzzleTest()

local function basicSwapTest()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.seed = 1 -- so we consistently have a panel to swap
  local stack = match.P1

  stack.do_countdown = false

  stack:receiveConfirmedInput("AA") -- can't swap on first two frames
  StackReplayTestingUtils:simulateMatchUntil(match, 2)

  assert(stack:canSwap(1, 1), "should be able to swap")
  stack:setQueuedSwapPosition(1, 1)
  assert(stack.queuedSwapRow == 1)
  stack:new_row()
  assert(stack.queuedSwapRow == 2)

  reset_filters()
  stop_the_music()
end

basicSwapTest()

local function moveAfterCountdownV46Test()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.seed = 1 -- so we consistently have a panel to swap
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

  reset_filters()
  stop_the_music()
end

moveAfterCountdownV46Test()
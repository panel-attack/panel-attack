
local function puzzleTest()
  local match = Match("puzzle") -- to stop rising
  local stack = Stack{which=1, match=match, is_local=false, level=5, inputMethod="controller"}
  match.P1 = stack
  stack.do_countdown = false
  stack:wait_for_random_character()
  pick_random_stage()

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

local function basicSwapTest()
  local match = Match("endless")
  local stack = Stack{which=1, match=match, is_local=false, level=5, inputMethod="controller"}
  match.P1 = stack
  stack.do_countdown = false
  stack:wait_for_random_character()
  pick_random_stage()

  assert(characters ~= nil, "no characters")


  stack:receiveConfirmedInput("AA") -- can't swap on first two frames ?!
  match:run()
  match:run()

  stack:setQueuedSwapPosition(1, 1)
  assert(stack.queuedSwapRow == 1)
  stack:new_row()
  assert(stack.queuedSwapRow == 2)

  reset_filters()
  stop_the_music()
end

basicSwapTest()
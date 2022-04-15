
local match = Match("puzzle") -- to stop rising
local stack = Stack(1, match, true, config.panels, 5, 1, 1, false)
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
assert(stack:canSwap(1, 4), "should be able to swap")
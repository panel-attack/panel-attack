
local match = Match("puzzle") -- to stop rising
local stack = Stack(1, match, false, config.panels, 5)
make_local_panels(stack, "000000")
make_local_gpanels(stack, "000000")
stack.do_countdown = false

assert(characters ~= nil, "no characters")
stack:set_puzzle_state("011010", 1)

assert(stack.panels[1][1].color == 0, "wrong color")
assert(stack.panels[1][2].color == 1, "wrong color")

stack.input_buffer = "AA" -- can't swap on first two frames ?!
--stack:run(2)
--assert(stack:canSwap(1, 4), "should be able to swap")
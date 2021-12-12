
local battleRoom = BattleRoom()
local match = Match("vs", battleRoom)
local stack = Stack(1, match, false, config.panels, 8)
make_local_panels(stack, "000000")
make_local_gpanels(stack, "000000")
stack:starting_state()
stack.do_countdown = false

local stack2 = Stack(2, match, false, config.panels, 8)
make_local_panels(stack2, "000000")
make_local_gpanels(stack2, "000000")
stack2:starting_state()
stack2.do_countdown = false

stack.garbage_target = stack2
stack2.garbage_target = stack

local cpu = ComputerPlayer("JamesAi", "Dev")


assert(characters ~= nil, "no characters")
stack:set_puzzle_state("011010", 1)

assert(stack.panels[1][1].color == 0, "wrong color")
assert(stack.panels[1][2].color == 1, "wrong color")

stack.input_buffer = "AA" -- can't swap on first two frames ?!
stack:run(2)

-- local actions = ""
-- for index = 1, 60 do
--     cpu:run(stack)
--     assert(#stack.input_buffer >= 1)
--     actions = actions .. stack.input_buffer
--     stack:run(1)
-- end

--assert(stack.pre_stop_time > 0)
local logger = require("logger")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")


local match, _ = StackReplayTestingUtils:simulateReplayWithPath("tests/replays/v046-2022-06-04-19-06-21-Hekato-L8-vs-CoreyBLD-L8-Casual-draw.txt")

assert(match ~= nil)
assert(match.P1.game_over_clock == 10243)
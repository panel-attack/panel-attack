require("table_util")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")
local testReplayFolder = "tests/replays/"

-- Tests a catch that also did a "sync" (two separate matches on the same frame)
local function simpleTouchTest()
  match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v047-2023-02-06-05-21-16-Spd5-Dif1-endless.json")
  assert(match ~= nil)
  assert(match.mode == "endless")
  assert(match.seed == 792477)
  assert(match.P1.game_over_clock == 2382)
  assert(match.P1.difficulty == 1)
  assert(table.length(match.P1.chains) == 3)
  assert(table.length(match.P1.combos) == 0)
end

simpleTouchTest()

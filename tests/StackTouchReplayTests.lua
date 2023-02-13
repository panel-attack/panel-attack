require("table_util")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")
local testReplayFolder = "tests/replays/"

-- Tests a catch that also did a "sync" (two separate matches on the same frame)
local function simpleTouchTest()
  match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v047-2023-02-13-02-07-36-Spd3-Dif1-endless.json")
  assert(match ~= nil)
  assert(match.mode == "endless")
  assert(match.seed == 2521746)
  assert(match.P1.game_over_clock == 4347)
  assert(match.P1.difficulty == 1)
  assert(table.length(match.P1.chains) == 1)
  assert(table.length(match.P1.combos) == 0)
  assert(match.P1.analytic.data.destroyed_panels == 31)
end

simpleTouchTest()

require("table_util")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")
local testReplayFolder = "tests/replays/"

local function basicEndlessTest()
  local match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-30-00-35-24-Spd1-Dif3-endless.txt")
  assert(match ~= nil)
  assert(match.mode == "endless")
  assert(match.seed == 7161965)
  assert(match.P1.game_over_clock == 402)
  assert(match.P1.max_health == 1)
  assert(match.P1.score == 37)
  assert(match.P1.difficulty == 3)
end

basicEndlessTest()


local function basicTimeAttackTest()
  match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2022-09-12-04-02-30-Spd11-Dif1-timeattack.txt")
  assert(match ~= nil)
  assert(match.mode == "time")
  assert(match.seed == 3490465)
  assert(match.P1.game_stopwatch == 7201)
  assert(match.P1.max_health == 1)
  assert(match.P1.score == 10353)
  assert(match.P1.difficulty == 1)
  assert(table.length(match.P1.chains) == 8)
  assert(table.length(match.P1.combos) == 0)
end

basicTimeAttackTest()


local function basicVsTest()
  match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-28-02-39-32-JamBox-L10-vs-Galadic97-L10-Casual-P1wins.txt")
  assert(match ~= nil)
  assert(match.mode == "vs")
  assert(match.seed == 2992240)
  assert(match.P1.game_over_clock == 2039)
  assert(match.P1.level == 10)
  assert(table.length(match.P1.chains) == 4)
  assert(table.length(match.P1.combos) == 4)
  assert(match.P2.game_over_clock == 0)
  assert(match.P2.level == 10)
  assert(table.length(match.P2.chains) == 4)
  assert(table.length(match.P2.combos) == 4)
  assert(match.P1:gameResult() == -1)
end

basicVsTest()


local function noInputsInVsIsDrawTest()
  match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-30-22-27-36-Player 1-L10-vs-Player 2-L10-draw.txt")
  assert(match ~= nil)
  assert(match.mode == "vs")
  assert(match.seed == 1866552)
  assert(match.P1.game_over_clock == 908)
  assert(match.P1.level == 10)
  assert(table.length(match.P1.chains) == 0)
  assert(table.length(match.P1.combos) == 0)
  assert(match.P2.game_over_clock == 908)
  assert(match.P2.level == 10)
  assert(table.length(match.P2.chains) == 0)
  assert(table.length(match.P2.combos) == 0)
  assert(match.P1:gameResult() == 0)
end

noInputsInVsIsDrawTest()

-- Tests a bunch of different frame specific tricks and makes sure we still end at the expected time.
-- In the future we should probably expand this to testing each specific trick and making sure the board changes correctly.
local function frameTricksTest()
  match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-07-16-37-02-Spd10-Dif3-endless.txt")
  assert(match ~= nil)
  assert(match.mode == "endless")
  assert(match.seed == 9399683)
  assert(match.P1.game_over_clock == 10032)
  assert(match.P1.difficulty == 3)
  assert(table.length(match.P1.chains) == 13)
  assert(table.length(match.P1.combos) == 0)
end

frameTricksTest()

-- Tests a catch that also did a "sync" (two separate matches on the same frame)
local function catchAndSyncTest()
  match, _ = StackReplayTestingUtils:simulateReplayWithPath(testReplayFolder .. "v046-2023-01-31-08-57-51-Galadic97-L10-vs-iTSMEJASOn-L8-Casual-P1wins.txt")
  assert(match ~= nil)
  assert(match.mode == "vs")
  assert(match.seed == 8739468)
  assert(match.P1.game_over_clock == 0)
  assert(match.P1.level == 10)
  assert(table.length(match.P1.chains) == 4)
  assert(table.length(match.P1.combos) == 6)
  assert(match.P2.game_over_clock == 2431)
  assert(match.P2.level == 8)
  assert(table.length(match.P2.chains) == 2)
  assert(table.length(match.P2.combos) == 2)
  assert(match.P1:gameResult() == 1)
end

catchAndSyncTest()

local tableUtils = require("tableUtils")
local consts = require("consts")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")
local Replay = require("replay")


local function endlessSaveTest()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.P1:receiveConfirmedInput(string.rep(match.P1:idleInput(), 909))
  local replay = Replay.createNewReplay(match)
  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.mode == "endless")
  assert(match.seed == 1)
  assert(match.P1.game_over_clock == 908)

  Replay.finalizeReplay(match, replay)
  local replayJSON = json.encode(replay)
  
  assert(replay ~= nil)
  assert(replay.endless.in_buf == "A909")
  assert(replayJSON ~= nil)
  assert(type(replayJSON) == "string")
end

endlessSaveTest()
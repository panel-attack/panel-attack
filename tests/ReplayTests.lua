local tableUtils = require("tableUtils")
local consts = require("consts")
local StackReplayTestingUtils = require("tests.StackReplayTestingUtils")
local Replay = require("replay")
local GameModes = require("GameModes")


local function endlessSaveTest()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  match.P1:receiveConfirmedInput(string.rep(match.P1:idleInput(), 909))
  local replay = Replay.createNewReplay(match)
  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.mode.stackInteraction == GameModes.StackInteraction.NONE)
  assert(match.mode.timeLimit == nil)
  assert(tableUtils.length(match.mode.winConditions) == 0)
  assert(match.seed == 1)
  assert(match.P1.game_over_clock == 908)

  Replay.finalizeReplay(match, replay)
  local replayJSON = json.encode(replay)
  
  assert(replay ~= nil)
  assert(replay.players[1].settings.inputs == "A909")
  assert(replayJSON ~= nil)
  assert(type(replayJSON) == "string")
end

endlessSaveTest()
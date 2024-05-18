local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local StackReplayTestingUtils = require("common.engine.tests.StackReplayTestingUtils")
local Replay = require("common.engine.Replay")
local GameModes = require("common.engine.GameModes")


local function endlessSaveTest()
  local match = StackReplayTestingUtils.createEndlessMatch(nil, nil, 10)
  local puzzleString = Puzzle.toPuzzleString(match.P1.panels):sub(-36)
  assert(puzzleString == "002040054133025661353423461141644526")
  match.P1:receiveConfirmedInput(string.rep(match.P1:idleInput(), 909))
  local replay = Replay.createNewReplay(match)
  StackReplayTestingUtils:fullySimulateMatch(match)

  assert(match ~= nil)
  assert(match.stackInteraction == GameModes.StackInteractions.NONE)
  assert(match.timeLimit == nil)
  assert(tableUtils.length(match.winConditions) == 0)
  assert(match.seed == 1)
  assert(match.P1.game_over_clock == 908)

  Replay.finalizeReplay(match, replay)
  local replayJSON = json.encode(replay)

  assert(replay ~= nil)
  assert(replay.players[1].settings.inputs == "A909")
  assert(replayJSON ~= nil)
  assert(type(replayJSON) == "string")
  StackReplayTestingUtils:cleanup(match)
end

endlessSaveTest()
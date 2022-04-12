require("puzzles")

local PuzzleTests = class(function() end)

function PuzzleTests.validationCountdown()
  local puzzle = Puzzle("moves", "idc", "5", "1254216999999952")
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "doCountdown"))
end

function PuzzleTests.validationPuzzleType()
  local puzzle = Puzzle("garbageGoal", false, "5", "1254216999999952")
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "puzzle type"))
end

function PuzzleTests.validationMoves()
  local puzzle = Puzzle("moves", false, 0, "1254216999999952")
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "expecting a number greater than zero"))
end

function PuzzleTests.validationStackCharacters()
  local puzzle = Puzzle("moves", false, 3, "12542169999f9952")
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "invalid characters: f"))
end

function PuzzleTests.validationStackLength()
  local puzzle = Puzzle("moves", false, 2, "1254216999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999952")
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "Maximum allowed"))
end

function PuzzleTests.validationGarbageCoherence1()
  local puzzle = Puzzle("moves", false, 2, "929999[==========}040000224999949999")
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "invalid garbage notation"))
end

function PuzzleTests.validationGarbageCoherence2()
  local puzzle = Puzzle("moves", false, 2, "929999[====[====]]040000224999949999")
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "invalid garbage notation"))
end

function PuzzleTests.validationGarbageCoherence3()
  local puzzle = Puzzle("moves", false, 2, "{====}929999[======]040000224999949999")
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "length"))
end

function PuzzleTests.validationGarbageCoherence4()
  local puzzle = Puzzle("moves", false, 2, "9299[===]99040000224999949999")
  local isValid, validationMessage = puzzle:validate()

  assert(not isValid)
  assert(string.match(validationMessage, "extend"))
end

function PuzzleTests.validationValid()
  local puzzle = Puzzle("moves", false, 2, "{====}929999[====]040000224999949999")
  local isValid, validationMessage = puzzle:validate()

  assert(isValid)
  assert(validationMessage == "")
end

PuzzleTests.validationCountdown()
PuzzleTests.validationPuzzleType()
PuzzleTests.validationMoves()
PuzzleTests.validationStackLength()
PuzzleTests.validationStackCharacters()
PuzzleTests.validationGarbageCoherence1()
PuzzleTests.validationGarbageCoherence2()
PuzzleTests.validationGarbageCoherence3()
PuzzleTests.validationGarbageCoherence4()
PuzzleTests.validationValid()
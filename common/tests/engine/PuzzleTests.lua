local Puzzle = require("common.engine.Puzzle")
local class = require("common.lib.class")

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
  assert(string.match(validationMessage, "Panels above the top"))
end

function PuzzleTests.validationStackLength2()
  local puzzle = Puzzle("clear", false, 3, "[==================================]000060500014600011300024502542203135466243")
  local isValid = puzzle:validate()

  assert(isValid)
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
PuzzleTests.validationStackLength2()
PuzzleTests.validationStackCharacters()
PuzzleTests.validationGarbageCoherence1()
PuzzleTests.validationGarbageCoherence2()
PuzzleTests.validationGarbageCoherence3()
PuzzleTests.validationGarbageCoherence4()
PuzzleTests.validationValid()

function PuzzleTests.testFilledPuzzleString()
  local puzzle = Puzzle("moves", false, 5, "123")
  local filledString = puzzle:fillMissingPanelsInPuzzleString(6, 12)
  assert(filledString ~= puzzle.stack)
  assert(filledString:len() == 72)
  assert(filledString == "000000000000000000000000000000000000000000000000000000000000000000000123")
end

PuzzleTests.testFilledPuzzleString()

function PuzzleTests.testRandomizeColors()
  local puzzleString = "{====}929999[====]040000224999949999"
  -- Technically its correct that sometimes we will get the same colors.
  -- Pick a constant seed that we found gives a different color set then the original
  love.math.setRandomSeed(1)
  local randomizedString = Puzzle.randomizeColorsInPuzzleString(puzzleString)
  assert(randomizedString:len() == puzzleString:len())
  assert(randomizedString ~= puzzleString)
end

PuzzleTests.testRandomizeColors()

function PuzzleTests.testRandomizeColorsSometimesSameColors()
  local puzzleString = "{====}929999[====]040000224999949999"
  -- Technically its correct that sometimes we will get the same colors.
  -- Pick a constant seed that we found gives the same colors
  love.math.setRandomSeed(9)
  local randomizedString = Puzzle.randomizeColorsInPuzzleString(puzzleString)
  assert(randomizedString:len() == puzzleString:len())
  assert(randomizedString == puzzleString)
end

PuzzleTests.testRandomizeColorsSometimesSameColors()

function PuzzleTests.testHorizontallyFlippedPuzzle()
  local puzzleString = "{====}929999[====]040000224999949999"
  local puzzle = Puzzle("moves", false, 5, puzzleString)
  local flippedString = puzzle:horizontallyFlipPuzzleString()
  assert(flippedString == "000000000000000000000000000000000000{====}999929[====]000040999422999949")
end

PuzzleTests.testHorizontallyFlippedPuzzle()

function PuzzleTests.testHorizontallyFlippedSmallPuzzle()
  local puzzleString = "123"
  local puzzle = Puzzle("moves", false, 5, puzzleString)
  local flippedString = puzzle:horizontallyFlipPuzzleString()
  assert(flippedString == "000000000000000000000000000000000000000000000000000000000000000000321000")
end

PuzzleTests.testHorizontallyFlippedSmallPuzzle()

function PuzzleTests.testHorizontallyFlippedBigGarbagePuzzle()
  local puzzleString = "[============================][====]632620[====]200042543641322141354544463636"
  local puzzle = Puzzle("moves", false, 5, puzzleString)
  local flippedString = puzzle:horizontallyFlipPuzzleString()
  assert(flippedString == "[============================][====]026236[====]240002146345141223445453636364")
end

PuzzleTests.testHorizontallyFlippedBigGarbagePuzzle()

function PuzzleTests.testHorizontallyFlippedSmallGarbagePuzzle()
  local puzzleString = "[============================]00[==]632620[==]00200042543641322141354544463636"
  local puzzle = Puzzle("moves", false, 5, puzzleString)
  local flippedString = puzzle:horizontallyFlipPuzzleString()
  assert(flippedString == "[============================][==]0002623600[==]240002146345141223445453636364")
end

PuzzleTests.testHorizontallyFlippedSmallGarbagePuzzle()
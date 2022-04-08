
-- A puzzle is a particular instance of the game, where there is a specific goal for clearing the panels
Puzzle =
  class(
  function(self, puzzleType, doCountdown, moves, stack)
    self.puzzleType = puzzleType
    self.doCountdown = doCountdown
    self.moves = moves
    self.stack = stack
  end
)

-- A puzzle is a particular instance of the game, where there is a specific goal for clearing the panels
Puzzle =
  class(
  function(self, puzzleType, doCountdown, moves, stack, name, hint)
    self.puzzleType = puzzleType
    self.doCountdown = doCountdown
    self.moves = moves
    self.stack = stack
    self.name = name
    self.hint = hint
    self.replay = replay
  end
)
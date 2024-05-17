
-- A puzzle set is a set of puzzles, typically they have a common difficulty or theme.
PuzzleSet =
  class(
  function(self, setName, puzzles)
    self.setName = setName
    self.puzzles = puzzles
  end
)
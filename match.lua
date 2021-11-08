
-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
Match =
  class(
  function(self, mode)
    self.P1 = nil
    self.P2 = nil
    self.mode = mode
  end
)
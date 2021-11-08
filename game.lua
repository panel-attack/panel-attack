
-- The main game object for tracking everything in Panel Attack.
-- Not to be confused with "Match" which is the current battle / instance of the game.
Game =
  class(
  function(self)
    self.scores = require("scores")
    self.match = nil
    self.focused = true
  end
)

local game = Game()

return game

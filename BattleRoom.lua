
local logger = require("logger")

-- A Battle Room is a session of vs battles, keeping track of the room number, wins / losses etc
BattleRoom =
  class(
  function(self, mode)
    self.playerWinCounts = {}
    self.playerWinCounts[1] = 0
    self.playerWinCounts[2] = 0
    self.mode = mode
    self.playerNames = {} -- table with player which number -> display name
    self.playerNames[1] = config.name or loc("player_n", "1")
    self.playerNames[2] = loc("player_n", "2")
    self.spectating = false
  end
)

function BattleRoom.updateWinCounts(self, winCounts)
  self.playerWinCounts = winCounts
end

-- Returns the player with more win count.
-- TODO handle ties?
function BattleRoom.winningPlayer(self)
  if not P2 then
    return P1
  end

  if self.playerWinCounts[P1.player_number] >= self.playerWinCounts[P2.player_number] then
    logger.trace("Player " .. P1.which .. " (" .. P1.player_number .. ") has more wins")
    return P1
  end

  logger.trace("Player " .. P2.which .. " (" .. P2.player_number .. ") has more wins")
  return P2
end
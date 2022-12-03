
local logger = require("logger")

-- A Battle Room is a session of vs battles, keeping track of the room number, wins / losses etc
BattleRoom =
  class(
  function(self, mode)
    self.playerWinCounts = {}
    self.modifiedWinCounts = {}
    self.playerWinCounts[1] = 0
    self.playerWinCounts[2] = 0
    self.modifiedWinCounts[1] = 0
    self.modifiedWinCounts[2] = 0
    self.mode = mode
    self.playerNames = {} -- table with player which number -> display name
    self.playerNames[1] = config.name or loc("player_n", "1")
    self.playerNames[2] = loc("player_n", "2")
    self.spectating = false
    self.trainingModeSettings = nil
  end
)

function BattleRoom.updateWinCounts(self, winCounts)
  self.playerWinCounts = winCounts
end

function BattleRoom:totalGames()
  local totalGames = 0
  for _, winCount in ipairs(self.playerWinCounts) do
    totalGames = totalGames + winCount
  end
  return totalGames
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

function BattleRoom.getPlayerWinCount(self, playerNumber)
 return self.playerWinCounts[playerNumber] + self.modifiedWinCounts[playerNumber]
end

function BattleRoom.matchOutcome(self)
  
  local gameResult = P1:gameResult()

  if gameResult == nil then
    return nil
  end

  local results = {}
  if gameResult == 0 then -- draw
    results["end_text"] = loc("ss_draw")
    results["outcome_claim"] = 0
  elseif gameResult == -1 then -- P2 wins
    results["winSFX"] = P2:pick_win_sfx()
    results["end_text"] =  loc("ss_p_wins", GAME.battleRoom.playerNames[2])
    -- win_counts will get overwritten by the server in net games
    GAME.battleRoom.playerWinCounts[P2.player_number] = GAME.battleRoom.playerWinCounts[P2.player_number] + 1
    results["outcome_claim"] = P2.player_number
  elseif gameResult == 1 then -- P1 wins
    results["winSFX"] = P1:pick_win_sfx()
    results["end_text"] =  loc("ss_p_wins", GAME.battleRoom.playerNames[1])
    -- win_counts will get overwritten by the server in net games
    GAME.battleRoom.playerWinCounts[P1.player_number] = GAME.battleRoom.playerWinCounts[P1.player_number] + 1
    results["outcome_claim"] = P1.player_number
  else
    error("No win result")
  end

  return results
end

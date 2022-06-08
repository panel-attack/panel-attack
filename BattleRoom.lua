
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
    self.trainingModeSettings = nil
  end
)

function BattleRoom.updateWinCounts(self, winCounts)
  self.playerWinCounts = winCounts
end

-- Returns the player with more win count.
-- TODO handle ties?
function BattleRoom.winningPlayer(self)
  if not GAME.match.P2 then
    return GAME.match.P1
  end

  if self.playerWinCounts[GAME.match.P1.player_number] >= self.playerWinCounts[GAME.match.P2.player_number] then
    logger.trace("Player " .. GAME.match.P1.which .. " (" .. GAME.match.P1.player_number .. ") has more wins")
    return GAME.match.P1
  end

  logger.trace("Player " .. GAME.match.P2.which .. " (" .. GAME.match.P2.player_number .. ") has more wins")
  return GAME.match.P2
end

function BattleRoom.matchOutcome(self)
  
  local gameResult = GAME.match.P1:gameResult()

  if gameResult == nil then
    return nil
  end

  local results = {}
  if gameResult == 0 then -- draw
    results["end_text"] = loc("ss_draw")
    results["outcome_claim"] = 0
  elseif gameResult == -1 then -- P2 wins
    results["winSFX"] = GAME.match.P2:pick_win_sfx()
    results["end_text"] =  loc("ss_p_wins", GAME.battleRoom.playerNames[2])
    -- win_counts will get overwritten by the server in net games
    GAME.battleRoom.playerWinCounts[GAME.match.P2.player_number] = GAME.battleRoom.playerWinCounts[GAME.match.P2.player_number] + 1
    results["outcome_claim"] = GAME.match.P2.player_number
  elseif gameResult == 1 then -- P1 wins
    results["winSFX"] = GAME.match.P1:pick_win_sfx()
    results["end_text"] =  loc("ss_p_wins", GAME.battleRoom.playerNames[1])
    -- win_counts will get overwritten by the server in net games
    GAME.battleRoom.playerWinCounts[GAME.match.P1.player_number] = GAME.battleRoom.playerWinCounts[GAME.match.P1.player_number] + 1
    results["outcome_claim"] = GAME.match.P1.player_number
  else
    error("No win result")
  end

  return results
end
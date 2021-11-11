
-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
Match =
  class(
  function(self, mode)
    self.P1 = nil
    self.P2 = nil
    self.mode = mode
    self.gameEndedClock = 0 -- 0 if no one has lost, otherwise the minimum clock time of those that lost
    GAME.droppedFrames = 0
  end
)

function Match.matchOutcome(self)
  
  local gameResult = self.P1:gameResult()

  if gameResult == nil then
    return nil
  end

  local results = {}
  if gameResult == 0 then -- draw
    results["end_text"] = loc("ss_draw")
    results["outcome_claim"] = 0
  elseif gameResult == -1 then -- opponent wins
    results["winSFX"] = self.P2:pick_win_sfx()
    results["end_text"] =  loc("ss_p_wins", op_name)
    -- win_counts will get overwritten by the server in net games
    GAME.battleRoom.playerWinCounts[P2.player_number] = GAME.battleRoom.playerWinCounts[P2.player_number] + 1
    results["outcome_claim"] = P2.player_number
  elseif P2.game_over_clock == self.gameEndedClock then -- client wins
    results["winSFX"] = self.P1:pick_win_sfx()
    results["end_text"] =  loc("ss_p_wins", my_name)
    -- win_counts will get overwritten by the server in net games
    GAME.battleRoom.playerWinCounts[P1.player_number] = GAME.battleRoom.playerWinCounts[P1.player_number] + 1
    results["outcome_claim"] = P1.player_number
  else
    error("No win result")
  end

  return results
end

function Match.render(self)

  if GAME.droppedFrames > 10 and config.show_fps then
    gprint("Dropped Frames: " .. GAME.droppedFrames, 1, 12)
  end

  if game_is_paused then
    draw_pause()
  else
    -- Don't allow rendering if either player is loading for spectating
    local renderingAllowed = true
    if P1 and P1.play_to_end then
      renderingAllowed = false
    end
    if P2 and P2.play_to_end then
      renderingAllowed = false
    end

    if P1 and renderingAllowed then
      P1:render()
    end
    if P2 and renderingAllowed then
      P2:render()
    end
  end
end
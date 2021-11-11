
-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
Match =
  class(
  function(self, mode)
    self.P1 = nil
    self.P2 = nil
    self.mode = mode
    GAME.droppedFrames = 0
  end
)


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
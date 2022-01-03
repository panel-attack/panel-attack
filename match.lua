
-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
Match =
  class(
  function(self, mode, battleRoom)
    self.P1 = nil
    self.P2 = nil
    self.mode = mode
    self.gameEndedClock = 0 -- 0 if no one has lost, otherwise the minimum clock time of those that lost
    assert(mode ~= "vs" or battleRoom)
    self.battleRoom = battleRoom
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
    results["end_text"] =  loc("ss_p_wins", GAME.battleRoom.playerNames[2])
    -- win_counts will get overwritten by the server in net games
    GAME.battleRoom.playerWinCounts[P2.player_number] = GAME.battleRoom.playerWinCounts[P2.player_number] + 1
    results["outcome_claim"] = P2.player_number
  elseif P2.game_over_clock == self.gameEndedClock then -- client wins
    results["winSFX"] = self.P1:pick_win_sfx()
    results["end_text"] =  loc("ss_p_wins", GAME.battleRoom.playerNames[1])
    -- win_counts will get overwritten by the server in net games
    GAME.battleRoom.playerWinCounts[P1.player_number] = GAME.battleRoom.playerWinCounts[P1.player_number] + 1
    results["outcome_claim"] = P1.player_number
  else
    error("No win result")
  end

  return results
end

-- shows debug info for mouse hover
function Match.draw_debug_mouse_panel()
  if GAME.debug_mouse_panel then
    local str = loc("pl_panel_info", GAME.debug_mouse_panel[1], GAME.debug_mouse_panel[2])
    for k, v in spairs(GAME.debug_mouse_panel[3]) do
      str = str .. "\n" .. k .. ": " .. tostring(v)
    end
    gprintf(str, 10, 10)
  end
end

function Match.render(self)

  if GAME.droppedFrames > 10 and config.show_fps then
    gprint("Dropped Frames: " .. GAME.droppedFrames, 1, 12)
  end

  -- Stack specific values for the HUD are drawn in Stack.render

  -- Draw VS HUD
  if self.battleRoom then
    -- P1 username
    gprint((GAME.battleRoom.playerNames[1] or ""), P1.score_x + themes[config.theme].name_Pos[1], P1.score_y + themes[config.theme].name_Pos[2])
    if P2 then
      -- P1 win count graphics
      draw_label(themes[config.theme].images.IMG_wins, (P1.score_x + themes[config.theme].winLabel_Pos[1]) / GFX_SCALE, (P1.score_y + themes[config.theme].winLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].winLabel_Scale)
      draw_number(GAME.battleRoom.playerWinCounts[P1.player_number], themes[config.theme].images.IMG_timeNumber_atlas, 12, P1_win_quads, P1.score_x + themes[config.theme].win_Pos[1], P1.score_y + themes[config.theme].win_Pos[2], themes[config.theme].win_Scale, 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale, "center")
      -- P2 username
      gprint((GAME.battleRoom.playerNames[2] or ""), P2.score_x + themes[config.theme].name_Pos[1], P2.score_y + themes[config.theme].name_Pos[2])
      -- P2 win count graphics
      draw_label(themes[config.theme].images.IMG_wins, (P2.score_x + themes[config.theme].winLabel_Pos[1]) / GFX_SCALE, (P2.score_y + themes[config.theme].winLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].winLabel_Scale)
      draw_number(GAME.battleRoom.playerWinCounts[P2.player_number], themes[config.theme].images.IMG_timeNumber_atlas, 12, P2_win_quads, P2.score_x + themes[config.theme].win_Pos[1], P2.score_y + themes[config.theme].win_Pos[2], themes[config.theme].win_Scale, 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale, "center")
    end

    if not config.debug_mode then --this is printed in the same space as the debug details
      gprint(spectators_string, themes[config.theme].spectators_Pos[1], themes[config.theme].spectators_Pos[2])
    end

    if match_type == "Ranked" then
      if global_current_room_ratings and global_current_room_ratings[my_player_number] and global_current_room_ratings[my_player_number].new then
        local rating_to_print = loc("ss_rating") .. "\n"
        if global_current_room_ratings[my_player_number].new > 0 then
          rating_to_print = global_current_room_ratings[my_player_number].new
        end
        --gprint(rating_to_print, P1.score_x, P1.score_y-30)
        draw_label(themes[config.theme].images.IMG_rating_1P, (P1.score_x + themes[config.theme].ratingLabel_Pos[1]) / GFX_SCALE, (P1.score_y + themes[config.theme].ratingLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].ratingLabel_Scale)
        if type(rating_to_print) == "number" then
          draw_number(rating_to_print, themes[config.theme].images.IMG_number_atlas_1P, 10, P1_rating_quads, P1.score_x + themes[config.theme].rating_Pos[1], P1.score_y + themes[config.theme].rating_Pos[2], themes[config.theme].rating_Scale, (15 / themes[config.theme].images.numberWidth_1P * themes[config.theme].rating_Scale), (19 / themes[config.theme].images.numberHeight_1P * themes[config.theme].rating_Scale), "center")
        end
      end
      if global_current_room_ratings and global_current_room_ratings[op_player_number] and global_current_room_ratings[op_player_number].new then
        local op_rating_to_print = loc("ss_rating") .. "\n"
        if global_current_room_ratings[op_player_number].new > 0 then
          op_rating_to_print = global_current_room_ratings[op_player_number].new
        end
        --gprint(op_rating_to_print, P2.score_x, P2.score_y-30)
        draw_label(themes[config.theme].images.IMG_rating_2P, (P2.score_x + themes[config.theme].ratingLabel_Pos[1]) / GFX_SCALE, (P2.score_y + themes[config.theme].ratingLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].ratingLabel_Scale)
        if type(op_rating_to_print) == "number" then
          draw_number(op_rating_to_print, themes[config.theme].images.IMG_number_atlas_2P, 10, P2_rating_quads, P2.score_x + themes[config.theme].rating_Pos[1], P2.score_y + themes[config.theme].rating_Pos[2], themes[config.theme].rating_Scale, (15 / themes[config.theme].images.numberWidth_2P * themes[config.theme].rating_Scale), (19 / themes[config.theme].images.numberHeight_2P * themes[config.theme].rating_Scale), "center")
        end
      end
    end
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

    if renderingAllowed then
      GAME.debug_mouse_panel = nil
      self:draw_debug_mouse_panel()
      if P1 then
        P1:render()
      end
      if P2 then
        P2:render()
      end
    end
  end
end

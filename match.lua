
-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
Match =
  class(
  function(self, mode, battleRoom)
    self.P1 = nil
    self.P2 = nil
    self.attackEngine = nil
    self.mode = mode
    assert(mode ~= "vs" or battleRoom)
    self.battleRoom = battleRoom
    GAME.droppedFrames = 0
    self.timeSpentRunning = 0
    self.createTime = love.timer.getTime()
    self.supportsPause = true
    self.attackEngine = nil
    self.current_music_is_casual = true 
  end
)

function Match.gameEndedClockTime()

  local result = P1.game_over_clock
  
  if P2 and P2.game_over_clock > result then
    result = P2.game_over_clock
  end

  return result
end

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


function Match.run(self)
  local startTime = love.timer.getTime()

  -- We need to save CLOCK 0 as a base case
  if P1.CLOCK == 0 then  
    P1:saveForRollback()
  end
  if P2 and P2.CLOCK == 0 then  
    P2:saveForRollback()
  end

  if P1 and P1.is_local and P1:game_ended() == false then  
    P1:send_controls()
  end
  if P2 and P2.is_local and P2:game_ended() == false then
    P2:send_controls()
  end

  --self:rollbackIfNeeded()

  local timesToRunP1 = P1:timesToRun()
  local timesToRunP2 = P2 and P2:timesToRun() or 0

  for i = 1, math.max(timesToRunP1, timesToRunP2) do
    if P1 and i <= timesToRunP1 then
      P1:run()
    end
    if P2 and i <= timesToRunP2 then
      P2:run()
    end
    if self.attackEngine then
      self.attackEngine:run()
    end
    if P1 and i <= timesToRunP1 then
      P1:saveForRollback()
    end
    if P2 and i <= timesToRunP2 then
      P2:saveForRollback()
    end
  end

  local endTime = love.timer.getTime()
  local timeDifference = endTime - startTime
  self.timeSpentRunning = self.timeSpentRunning + timeDifference
end

function Match.framesToSimulate(self) 
  local framesToSimulate = 1

  if P1:game_ended() == false then
    local maxConfirmedFrame = string.len(P1.confirmedInput)
    if P2 and string.len(P2.confirmedInput) > maxConfirmedFrame then
      maxConfirmedFrame = string.len(P2.confirmedInput)
    end
    framesToSimulate = maxConfirmedFrame - P1.CLOCK
  end

  return framesToSimulate
end

function Match.rollbackIfNeeded(self) 

  if (P1 and P2) or config.debug_mode then

    local gameEnded = P1:game_ended()
    if P2 then
      gameEnded = false
      if P1:gameResult() then
        gameEnded = true
      end
    end

    if not gameEnded then
      if config.debug_mode then
        local rollbackLength = P1.max_runs_per_frame - 1
        if P1.CLOCK > 0 and P1.prev_states[P1.CLOCK - rollbackLength] then
          P1:rollbackToFrame(P1.CLOCK - rollbackLength)
        end
          
        if P2 then
          if P2.CLOCK > 0 and P2.prev_states[P2.CLOCK - rollbackLength] then
            P2:rollbackToFrame(P2.CLOCK - rollbackLength)
          end
        end
      end
    end
  end
end


local P1_win_quads = {}
local P1_rating_quads = {}

local P2_rating_quads = {}
local P2_win_quads = {}

function Match.render(self)

  if GAME.droppedFrames > 10 and config.show_fps then
    gprint("Dropped Frames: " .. GAME.droppedFrames, 1, 12)
  end

  -- Stack specific values for the HUD are drawn in Stack.render

  -- Draw VS HUD
  if self.battleRoom and (GAME.gameIsPaused == false or GAME.renderDuringPause) then
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


  if config.debug_mode then
    local drawX = 140
    local drawY = 10

    grectangle_color("fill", (drawX - 5) / GFX_SCALE, (drawY - 5) / GFX_SCALE, 200/GFX_SCALE, 100/GFX_SCALE, 0, 0, 0, 0.5)
    
    gprintf("P1 Clock " .. P1.CLOCK, drawX, drawY)

    -- drawY = drawY + 14
    -- gprintf("Time Spent Running " .. self.timeSpentRunning * 1000, drawX, drawY)

    -- drawY = drawY + 14
    -- local totalTime = love.timer.getTime() - self.createTime
    -- gprintf("Total Time " .. totalTime * 1000, drawX, drawY)

    drawY = drawY + 14
    local totalTime = love.timer.getTime() - self.createTime
    local timePercent = self.timeSpentRunning / totalTime
    gprintf("Time Percent Running Match: " .. timePercent, drawX, drawY)

    -- drawY = drawY + 14
    -- gprintf("P1 Panels: " .. P1.panel_buffer, drawX, drawY)

    -- drawY = drawY + 14
    -- gprintf("P1 Confirmed " .. string.len(P1.confirmedInput) , drawX, drawY)

    -- drawY = drawY + 14
    -- gprintf("P1 Ended?: " .. tostring(P1:game_ended()), drawX, drawY)
    
    drawY = drawY + 14
    gprintf("P1 attacks: " .. #P1.telegraph.attacks, drawX, drawY)

    drawY = drawY + 14
    gprintf("P1 Garbage Q: " .. P1.garbage_q:len(), drawX, drawY)

    if P2 then 
      drawY = drawY + 14
      local framesAhead = string.len(P1.confirmedInput) - string.len(P2.confirmedInput)
      gprintf("Ahead: " .. framesAhead, drawX, drawY)

      drawY = drawY + 14
      gprintf("P2 Confirmed " .. string.len(P2.confirmedInput) , drawX, drawY)
    end
  end
  
  if GAME.gameIsPaused then
    draw_pause()
  end

  if GAME.gameIsPaused == false or GAME.renderDuringPause then
    -- Don't allow rendering if either player is loading for spectating
    local renderingAllowed = true
    if P1 and P1.play_to_end then
      renderingAllowed = false
    end
    if P2 and P2.play_to_end then
      renderingAllowed = false
    end

    if renderingAllowed then
      if P1 then
        P1:render()
      end
      if P2 then
        P2:render()
      end

      if self.battleRoom then
        if P1 and P1.telegraph then
          P1:render_telegraph()
        end
        if P2 and P2.telegraph then
          P2:render_telegraph()
        end
      end
    end
  end
end

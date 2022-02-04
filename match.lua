
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
    self.seed = math.random(1,9999999)
  end
)

function Match.gameEndedClockTime()

  local result = P1.game_over_clock
  
  if P2 then
    if P2.game_over_clock > 0 then
      if result == 0 or P2.game_over_clock < result then
        result = P2.game_over_clock
      end
    end
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


function Match.debugRollbackDivergenceCheck(self)
  local targetFrame = P1.CLOCK

  local savedStack = self.prev_states[self.CLOCK]
  
  self:rollbackToFrame(self.CLOCK - 1)
  for i=1,1 do
    self:run()
  end

  assert(self.CLOCK == targetFrame, "should have got back to target frame")

  local diverged = false
  for k,v in pairs(savedStack) do
    if type(v) ~= "table" then
      local v2 = self[k]
      if v ~= v2 then
        diverged = true
      end
    end
  end

  local savedStackString = self:divergenceString(savedStack)
  local localStackString = self:divergenceString(self)

  if savedStackString ~= localStackString then
    diverged = true
  end

  if diverged then
    print("Stacks have diverged")
    self:rollbackToFrame(targetFrame-1)
    self:run()
  end

end

function Match.run(self)
  if GAME.gameIsPaused then
    return
  end

  local startTime = love.timer.getTime()

  if config.debug_mode and network_connected() == false then
    local rollbackStart = 100
    if P1 and P1:game_ended() == false and P1:behindRollback() == false and P1.CLOCK > rollbackStart then
      P1:debugRollbackTest()
    end
  end

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

  local ranP1 = true
  local ranP2 = true
  local runsSoFar = 0
  while ranP1 or ranP2 do
    
    ranP1 = false
    if P1 and P1:shouldRun(runsSoFar) then
      P1:run()
      ranP1 = true
    end

    ranP2 = false
    if P2 and P2:shouldRun(runsSoFar) then
      P2:run()
      ranP2 = true
    end

    if self.attackEngine then
      self.attackEngine:run()
    end

    -- Since the stacks can affect each other, don't save rollback until after both have run
    if ranP1 then
      P1:saveForRollback()
    end

    if ranP2 then
      P2:saveForRollback()
    end

    runsSoFar = runsSoFar + 1
  end

  if P1 and P1.is_local and string.len(P1.input_buffer) > 0 then
    error("Local games should always simulate all inputs")
  end
  if P2 and P2.is_local and string.len(P2.input_buffer) > 0 then
    error("Local games should always simulate all inputs")
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
    local padding = 14

    grectangle_color("fill", (drawX - 5) / GFX_SCALE, (drawY - 5) / GFX_SCALE, 1000/GFX_SCALE, 100/GFX_SCALE, 0, 0, 0, 0.5)
    
    gprintf("Clock " .. P1.CLOCK, drawX, drawY)


    drawY = drawY + padding
    gprintf("Confirmed " .. string.len(P1.confirmedInput) , drawX, drawY)

    drawY = drawY + padding
    gprintf("input_buffer " .. string.len(P1.input_buffer) , drawX, drawY)

    drawY = drawY + padding
    gprintf("rollbackCount " .. P1.rollbackCount , drawX, drawY)

    -- drawY = drawY + padding
    -- gprintf("P1 Panels: " .. P1.panel_buffer, drawX, drawY)

    -- drawY = drawY + padding
    -- gprintf("P1 Confirmed " .. string.len(P1.confirmedInput) , drawX, drawY)

    -- drawY = drawY + padding
    -- gprintf("P1 Ended?: " .. tostring(P1:game_ended()), drawX, drawY)
    
    -- drawY = drawY + padding
    -- gprintf("P1 attacks: " .. #P1.telegraph.attacks, drawX, drawY)

    -- drawY = drawY + padding
    -- gprintf("P1 Garbage Q: " .. P1.garbage_q:len(), drawX, drawY)

    if P1.game_over_clock > 0 then
      drawY = drawY + padding
      gprintf("game_over_clock " .. P1.game_over_clock, drawX, drawY)
    end

    drawY = drawY + padding
    gprintf("chain panels " .. P1.n_chain_panels, drawX, drawY)

    -- if P1.telegraph then
    --   drawY = drawY + padding
    --   gprintf("incoming chains " .. P1.telegraph.garbage_queue.chain_garbage:len(), drawX, drawY)

    --   for combo_garbage_width=3,6 do
    --     drawY = drawY + padding
    --     gprintf("incoming combos " .. P1.telegraph.garbage_queue.combo_garbage[combo_garbage_width]:len(), drawX, drawY)
    --   end
    -- end



    drawX = 400
    drawY = 10 - padding
    -- drawY = drawY + padding
    -- gprintf("Time Spent Running " .. self.timeSpentRunning * 1000, drawX, drawY)

    -- drawY = drawY + padding
    -- local totalTime = love.timer.getTime() - self.createTime
    -- gprintf("Total Time " .. totalTime * 1000, drawX, drawY)

    drawY = drawY + padding
    local totalTime = love.timer.getTime() - self.createTime
    local timePercent = self.timeSpentRunning / totalTime
    gprintf("Time Percent Running Match: " .. timePercent, drawX, drawY)

    drawY = drawY + padding
    gprintf("Seed " .. GAME.match.seed, drawX, drawY)

    local gameEndedClockTime = self:gameEndedClockTime()

    if gameEndedClockTime > 0 then
      drawY = drawY + padding
      gprintf("gameEndedClockTime " .. gameEndedClockTime, drawX, drawY)
    end

    if P2 then 
      drawX = 800
      drawY = 10 - padding

      drawY = drawY + padding
      gprintf("Clock " .. P2.CLOCK, drawX, drawY)

      drawY = drawY + padding
      local framesAhead = string.len(P1.confirmedInput) - string.len(P2.confirmedInput)
      gprintf("Ahead: " .. framesAhead, drawX, drawY)

      drawY = drawY + padding
      gprintf("Confirmed " .. string.len(P2.confirmedInput) , drawX, drawY)

      drawY = drawY + padding
      gprintf("input_buffer " .. string.len(P2.input_buffer) , drawX, drawY)

      drawY = drawY + padding
      gprintf("rollbackCount " .. P2.rollbackCount , drawX, drawY)

      if P2.game_over_clock > 0 then
        drawY = drawY + padding
        gprintf("game_over_clock " .. P2.game_over_clock, drawX, drawY)
      end

      -- if P2.telegraph then
      --   drawY = drawY + padding
      --   gprintf("incoming chains " .. P2.telegraph.garbage_queue.chain_garbage:len(), drawX, drawY)
  
      --   for combo_garbage_width=3,6 do
      --     drawY = drawY + padding
      --     gprintf("incoming combos " .. P2.telegraph.garbage_queue.combo_garbage[combo_garbage_width]:len(), drawX, drawY)
      --   end
      -- end
  
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

local logger = require("logger")

-- A match is a particular instance of the game, for example 1 time attack round, or 1 vs match
Match =
  class(
  function(self, mode, battleRoom)
    self.P1 = nil
    self.P2 = nil
    self.engineVersion = VERSION
    self.mode = mode
    assert(mode ~= "vs" or battleRoom)
    self.battleRoom = battleRoom
    GAME.droppedFrames = 0
    self.timeSpentRunning = 0
    self.maxTimeSpentRunning = 0
    self.createTime = love.timer.getTime()
    self.supportsPause = true
    self.current_music_is_casual = true
    self.seed = math.random(1,9999999)
    self.isFromReplay = false
    self.current_music_is_casual = true
    self.startTimestamp = os.time(os.date("*t"))
    if (P2 or mode == "vs") and GAME.battleRoom then
      GAME.rich_presence:setPresence(
      (GAME.battleRoom.spectating and "Spectating" or "Playing") .. " a " .. match_type .. " match",
      GAME.battleRoom.playerNames[1] .. " vs " .. (GAME.battleRoom.playerNames[2] or "themselves"),
      true)
    else
      GAME.rich_presence:setPresence(
      "Playing " .. mode .. " mode",
      nil,
      true)
    end

    self.time_quads = {}
  end
)

-- Should be called prior to clearing the match.
-- Consider recycling any memory that might leave around a lot of garbage.
-- Note: You can just leave the variables to clear / garbage collect on their own if they aren't large.
function Match:deinit()
  if self.P1 then
    self.P1:deinit()
  end
  if self.P2 then
    self.P2:deinit()
  end
  for _, quad in ipairs(self.time_quads) do
    GraphicsUtil:releaseQuad(quad)
  end
end

function Match:gameEndedClockTime()

  local result = self.P1.game_over_clock
  
  if self.P1.opponentStack then
    local otherPlayer = self.P1.opponentStack
    if otherPlayer.game_over_clock > 0 then
      if result == 0 or otherPlayer.game_over_clock < result then
        result = otherPlayer.game_over_clock
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
    GAME.battleRoom.playerWinCounts[self.P2.player_number] = GAME.battleRoom.playerWinCounts[self.P2.player_number] + 1
    results["outcome_claim"] = self.P2.player_number
  elseif self.P2.game_over_clock == self:gameEndedClockTime() then -- client wins
    results["winSFX"] = self.P1:pick_win_sfx()
    results["end_text"] =  loc("ss_p_wins", GAME.battleRoom.playerNames[1])
    -- win_counts will get overwritten by the server in net games
    GAME.battleRoom.playerWinCounts[self.P1.player_number] = GAME.battleRoom.playerWinCounts[self.P1.player_number] + 1
    results["outcome_claim"] = self.P1.player_number
  else
    error("No win result")
  end

  return results
end

function Match:debugRollbackAndCaptureState(clockGoal)
  local P1 = self.P1
  local P2 = self.P2

  if P1.clock <= clockGoal then
    return
  end

  self.savedStackP1 = P1.prev_states[P1.clock]
  if P2 then
    self.savedStackP2 = P2.prev_states[P2.clock]
  end

  local rollbackResult = P1:rollbackToFrame(clockGoal)
  assert(rollbackResult)
  if P2 then
    rollbackResult = P2:rollbackToFrame(clockGoal)
    assert(rollbackResult)
  end
end

function Match:warningOccurred()
  local P1 = self.P1
  local P2 = self.P2
  
  if (P1 and table.length(P1.warningsTriggered) > 0) or (P2 and table.length(P2.warningsTriggered) > 0) then
    return true
  end
  return false
end

function Match:debugAssertDivergence(stack, savedStack)

  for k,v in pairs(savedStack) do
    if type(v) ~= "table" then
      local v2 = stack[k]
      if v ~= v2 then
        error("Stacks have diverged")
      end
    end
  end

  local savedStackString = Stack.divergenceString(savedStack)
  local localStackString = Stack.divergenceString(stack)

  if savedStackString ~= localStackString then
    error("Stacks have diverged")
  end
end

function Match:debugCheckDivergence()

  if not self.savedStackP1 or self.savedStackP1.clock ~= self.P1.clock then
    return
  end

  self:debugAssertDivergence(self.P1, self.savedStackP1)
  self.savedStackP1 = nil

  if not self.savedStackP2 or self.savedStackP2.clock ~= self.P2.clock then
    return
  end

  self:debugAssertDivergence(self.P2, self.savedStackP2)
  self.savedStackP2 = nil
end

function Match:run()
  local P1 = self.P1
  local P2 = self.P2

  if GAME.gameIsPaused then
    return
  end

  local startTime = love.timer.getTime()

  -- We need to save clock 0 as a base case
  if P1.clock == 0 then  
    P1:saveForRollback()
  end
  if P2 and P2.clock == 0 then  
    P2:saveForRollback()
  end

  if self.P1CPU then
    self.P1CPU:run(P1)
  end

  if self.P2CPU then
    self.P2CPU:run(P2)
  end

  if P1 and P1.is_local and not self.P1CPU and P1:game_ended() == false then
    P1:send_controls()
  end
  if P2 and P2.is_local and not self.P2CPU and P2:game_ended() == false then
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

    if ranP1 and P1:gameResult() == nil then
      if self.simulatedOpponent then
        self.simulatedOpponent:run()
      end
    end

    -- Since the stacks can affect each other, don't save rollback until after both have run
    if ranP1 then
      P1:updateFramesBehind()
      P1:saveForRollback()
    end

    if ranP2 then
      P2:updateFramesBehind()
      P2:saveForRollback()
    end

    self:debugCheckDivergence()

    runsSoFar = runsSoFar + 1
  end

  if P1 then
    if P1.is_local and not P1:game_ended() then
      assert(#P1.input_buffer == 0, "Local games should always simulate all inputs")
    end
  end
  if P2 then
    if P2.is_local and not P2:game_ended() then
      assert(#P2.input_buffer == 0, "Local games should always simulate all inputs")
    end
  end

  local endTime = love.timer.getTime()
  local timeDifference = endTime - startTime
  self.timeSpentRunning = self.timeSpentRunning + timeDifference
  self.maxTimeSpentRunning = math.max(self.maxTimeSpentRunning, timeDifference)
end


function Match:matchelementOriginX()
  local x = 375 + (464) / 2
  if themes[config.theme]:offsetsAreFixed() then
    x = 0
  end
  return x
end

function Match:matchelementOriginY()
  local y = 118
  if themes[config.theme]:offsetsAreFixed() then
    y = 0
  end
  return y
end

function Match:drawMatchLabel(drawable, themePositionOffset, scale)
  local x = self:matchelementOriginX() + themePositionOffset[1]
  local y = self:matchelementOriginY() + themePositionOffset[2]

  local hAlign = "left"
  local vAlign = "left"
  if themes[config.theme]:offsetsAreFixed() then
    hAlign = "center"
  end
  menu_drawf(drawable, x, y, hAlign, vAlign, 0, scale, scale)
end

function Match:drawMatchTime(timeString, quads, themePositionOffset, scale)
  local x = self:matchelementOriginX() + themePositionOffset[1]
  local y = self:matchelementOriginY() + themePositionOffset[2]
  GraphicsUtil.draw_time(timeString, quads, x, y, scale)
end

function Match:drawTimer()
  local stack = self.P1
  if stack == nil or stack.game_stopwatch == nil or tonumber(stack.game_stopwatch) == nil then
    -- Make sure we have a valid time to base off of
    return
  end

  -- Draw the timer for time attack
  if self.mode == "puzzle" then
    -- puzzles don't have a timer...yet?
  else
    local frames = stack.game_stopwatch
    if self.mode == "time" then
      frames = (TIME_ATTACK_TIME * 60) - stack.game_stopwatch
      if frames < 0 then
        frames = 0
      end
    end
    --frames = frames + 60 * 60 * 80 -- debug large timer rendering
    local timeString = frames_to_time_string(frames, self.mode == "endless")
    
    self:drawMatchLabel(stack.theme.images.IMG_time, stack.theme.timeLabel_Pos, stack.theme.timeLabel_Scale)
    self:drawMatchTime(timeString, self.time_quads, stack.theme.time_Pos, stack.theme.time_Scale)
  end
end

function Match:drawMatchType()
  if match_type ~= "" then
    local matchImage = nil
    if match_type == "Ranked" then
      matchImage = themes[config.theme].images.IMG_ranked
    end
    if match_type == "Casual" then
      matchImage = themes[config.theme].images.IMG_casual
    end
    if matchImage then
      self:drawMatchLabel(matchImage, themes[config.theme].matchtypeLabel_Pos, themes[config.theme].matchtypeLabel_Scale)
    end
  end
end

function Match:drawCommunityMessage()
  -- Draw the community message
  if not config.debug_mode then
    gprintf(join_community_msg or "", 0, 668, canvas_width, "center")
  end
end

function Match.render(self)
  local P1 = self.P1
  local P2 = self.P2
  
  if GAME.droppedFrames > 10 and config.show_fps then
    gprint("Dropped Frames: " .. GAME.droppedFrames, 1, 12)
  end

  if config.show_fps and P1 and P2 then

    local P1Behind = P1:averageFramesBehind()
    local P2Behind = P2:averageFramesBehind()
    local behind = math.abs(P1.clock - P2.clock)

    if P1Behind > 0 then
      gprint("P1 Average Latency: " .. P1Behind, 1, 23)
    end
    if P2Behind > 0 then
      gprint("P2 Average Latency: " .. P2Behind, 1, 34)
    end
    
    if GAME.battleRoom.spectating and behind > MAX_LAG * 0.75 then
      local iconSize = 20
      local icon_width, icon_height = themes[config.theme].images.IMG_bug:getDimensions()
      local x = (canvas_width / 2) - (iconSize / 2)
      local y = (canvas_height / 2) - (iconSize / 2)
      draw(themes[config.theme].images.IMG_bug, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
    end
  end
  
  self:drawCommunityMessage()

  if config.debug_mode then

    local drawX = 240
    local drawY = 10
    local padding = 14

    grectangle_color("fill", (drawX - 5) / GFX_SCALE, (drawY - 5) / GFX_SCALE, 1000/GFX_SCALE, 100/GFX_SCALE, 0, 0, 0, 0.5)
    
    gprintf("Clock " .. P1.clock, drawX, drawY)


    drawY = drawY + padding
    gprintf("Confirmed " .. #P1.confirmedInput , drawX, drawY)

    drawY = drawY + padding
    gprintf("input_buffer " .. #P1.input_buffer , drawX, drawY)

    drawY = drawY + padding
    gprintf("rollbackCount " .. P1.rollbackCount , drawX, drawY)

    -- drawY = drawY + padding
    -- gprintf("P1 Panels: " .. P1.panel_buffer, drawX, drawY)

    -- drawY = drawY + padding
    -- gprintf("P1 Confirmed " .. #P1.confirmedInput , drawX, drawY)

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
    gprintf("has chain panels " .. tostring(P1:hasChainingPanels()), drawX, drawY)

    drawY = drawY + padding
    gprintf("has active panels " .. tostring(P1:hasActivePanels()), drawX, drawY)

    drawY = drawY + padding
    gprintf("riselock " .. tostring(P1.rise_lock), drawX, drawY)

    -- if P1.telegraph then
    --   drawY = drawY + padding
    --   gprintf("incoming chains " .. P1.telegraph.garbage_queue.chain_garbage:len(), drawX, drawY)

    --   for combo_garbage_width=3,6 do
    --     drawY = drawY + padding
    --     gprintf("incoming combos " .. P1.telegraph.garbage_queue.combo_garbage[combo_garbage_width]:len(), drawX, drawY)
    --   end
    -- end



    drawX = 500
    drawY = 10 - padding
    -- drawY = drawY + padding
    -- gprintf("Time Spent Running " .. self.timeSpentRunning * 1000, drawX, drawY)

    -- drawY = drawY + padding
    -- local totalTime = love.timer.getTime() - self.createTime
    -- gprintf("Total Time " .. totalTime * 1000, drawX, drawY)

    drawY = drawY + padding
    local totalTime = love.timer.getTime() - self.createTime
    local timePercent = round(self.timeSpentRunning / totalTime, 5)
    gprintf("Time Percent Running Match: " .. timePercent, drawX, drawY)

    drawY = drawY + padding
    local maxTime = round(self.maxTimeSpentRunning, 5)
    gprintf("Max Stack Update: " .. maxTime, drawX, drawY)

    drawY = drawY + padding
    gprintf("Seed " .. GAME.match.seed, drawX, drawY)

    local gameEndedClockTime = self:gameEndedClockTime()

    if gameEndedClockTime > 0 then
      drawY = drawY + padding
      gprintf("gameEndedClockTime " .. gameEndedClockTime, drawX, drawY)
    end

    -- drawY = drawY + padding
    -- local memoryCount = collectgarbage("count")
    -- memoryCount = round(memoryCount / 1000, 1)
    -- gprintf("Memory " .. memoryCount .. " MB", drawX, drawY)

    -- drawY = drawY + padding
    -- gprintf("quadPool " .. #GraphicsUtil.quadPool, drawX, drawY)

    if P2 then 
      drawX = 800
      drawY = 10 - padding

      drawY = drawY + padding
      gprintf("Clock " .. P2.clock, drawX, drawY)

      drawY = drawY + padding
      local framesAhead = P1.clock - P2.clock
      gprintf("P1 Ahead: " .. framesAhead, drawX, drawY)

      drawY = drawY + padding
      gprintf("Confirmed " .. #P2.confirmedInput , drawX, drawY)

      drawY = drawY + padding
      gprintf("input_buffer " .. #P2.input_buffer , drawX, drawY)

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
      
      if self.simulatedOpponent then
        self.simulatedOpponent:render()
      end

      local challengeMode = self.battleRoom and self.battleRoom.trainingModeSettings and self.battleRoom.trainingModeSettings.challengeMode
      if challengeMode then
        challengeMode:render()
      end

      if self.battleRoom then
        if P1 and P1.telegraph then
          P1.telegraph:render()
        end
        if P2 and P2.telegraph then
          P2.telegraph:render()
        end
      end

      -- Draw VS HUD
      if self.battleRoom then
        if not config.debug_mode then --this is printed in the same space as the debug details
          gprint(spectators_string, themes[config.theme].spectators_Pos[1], themes[config.theme].spectators_Pos[2])
        end

        self:drawMatchType()
      end
      
      self:drawTimer()
    end
  end

  if (self:warningOccurred()) then
    local iconSize = 20
    local icon_width, icon_height = themes[config.theme].images.IMG_bug:getDimensions()
    local x = 5
    local y = 5
    draw(themes[config.theme].images.IMG_bug, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
    gprint("A warning has occurred, please post your warnings.txt file and this replay to #panel-attack-bugs in the discord.", x + iconSize, y)
  end
end

function Match:getInfo()
  local info = {}
  info.mode = self.mode
  info.stage = current_stage
  info.stacks = {}
  if P1 then
    info.stacks[1] = P1:getInfo()
  end
  if P2 then
    info.stacks[2] = P2:getInfo()
  end

  return info
end

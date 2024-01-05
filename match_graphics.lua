local GameModes = require("GameModes")

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
  if self.puzzle then
    -- puzzles don't have a timer...yet?
  else
    local frames = stack.game_stopwatch
    if self.timeLimit then
      frames = (self.timeLimit * 60) - stack.game_stopwatch
      if frames < 0 then
        frames = 0
      end
    end
    -- frames = frames + 60 * 60 * 80 -- debug large timer rendering
    local timeString = frames_to_time_string(frames, not self.timeLimit)

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

function Match:render()
  local P1 = self.P1
  local P2 = self.P2

  if GAME.droppedFrames > 0 and config.show_fps then
    gprint("Dropped Frames: " .. GAME.droppedFrames, 1, 12)
  end

  if config.show_fps and P1 and P2 then

    local P1Behind = P1.framesBehind
    local P2Behind = P2.framesBehind
    local behind = math.abs(P1.clock - P2.clock)

    if P1Behind > 0 then
      gprint("P1 Average Latency: " .. P1Behind, 1, 23)
    end
    if P2Behind > 0 then
      gprint("P2 Average Latency: " .. P2Behind, 1, 34)
    end

    if not self:hasLocalPlayer() and behind > MAX_LAG * 0.75 then
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

    grectangle_color("fill", (drawX - 5) / GFX_SCALE, (drawY - 5) / GFX_SCALE, 1000 / GFX_SCALE, 100 / GFX_SCALE, 0, 0, 0, 0.5)

    gprintf("Clock " .. P1.clock, drawX, drawY)

    drawY = drawY + padding
    gprintf("Confirmed " .. #P1.confirmedInput, drawX, drawY)

    drawY = drawY + padding
    gprintf("input_buffer " .. #P1.input_buffer, drawX, drawY)

    drawY = drawY + padding
    gprintf("rollbackCount " .. P1.rollbackCount, drawX, drawY)

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
    gprintf("Seed " .. self.seed, drawX, drawY)

    if self.gameOverClock > 0 then
      drawY = drawY + padding
      gprintf("gameOverClock " .. self.gameOverClock, drawX, drawY)
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
      gprintf("Confirmed " .. #P2.confirmedInput, drawX, drawY)

      drawY = drawY + padding
      gprintf("input_buffer " .. #P2.input_buffer, drawX, drawY)

      drawY = drawY + padding
      gprintf("rollbackCount " .. P2.rollbackCount, drawX, drawY)

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

  if self.isPaused then
    self:draw_pause()
  end

  if self.isPaused == false or self.renderDuringPause then
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

      -- should invert the relationship between trainingModeSettings and challengeMode in the future
      -- challenge mode should probably live on battleRoom instead as match only really runs a single ChallengeStage at a time
      -- local challengeMode = self.battleRoom and self.battleRoom.trainingModeSettings and self.battleRoom.trainingModeSettings.challengeMode
      -- if challengeMode then
      --   challengeMode:render()
      -- end

      if self.stackInteraction ~= GameModes.StackInteractions.NONE then
        if P1 and P1.telegraph then
          P1.telegraph:render()
        end
        if P2 and P2.telegraph then
          P2.telegraph:render()
        end
      end

      -- Draw VS HUD
      if self.stackInteraction == GameModes.StackInteractions.VERSUS then
        if not config.debug_mode then -- this is printed in the same space as the debug details
          -- TODO: get spectator string from battleRoom
          -- gprint(spectators_string, themes[config.theme].spectators_Pos[1], themes[config.theme].spectators_Pos[2])
        end

        self:drawMatchType()
      end

      self:drawTimer()
    end
  end

  if P2 and P1.clock >= P2.clock + GARBAGE_DELAY_LAND_TIME then
    -- let the player know that rollback is active
    local iconSize = 20
    local icon_width, icon_height = themes[config.theme].images.IMG_bug:getDimensions()
    local x = 5
    local y = 30
    draw(themes[config.theme].images.IMG_bug, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
  end
end

-- a helper function for tests
-- prevents running graphics related processes, e.g. cards, popFX
function Match:removeCanvases()
  for i = 1, #self.players do
    self.players[i].stack.canvas = nil
  end
end

  -- Draw the pause menu
function Match:draw_pause()
  if not self.renderDuringPause then
    local image = themes[config.theme].images.pause
    local scale = canvas_width / math.max(image:getWidth(), image:getHeight()) -- keep image ratio
    menu_drawf(image, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end
  gprintf(loc("pause"), 0, 330, canvas_width, "center", nil, 1, large_font)
  gprintf(loc("pl_pause_help"), 0, 360, canvas_width, "center", nil, 1)
end
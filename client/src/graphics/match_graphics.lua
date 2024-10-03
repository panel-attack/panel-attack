local GameModes = require("common.engine.GameModes")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local prof = require("common.lib.jprof.jprof")
local MatchParticipant = require("client.src.MatchParticipant")
local Telegraph = require("client.src.graphics.Telegraph")

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

  if themes[config.theme]:offsetsAreFixed() then
    -- align in center
    x = x - math.floor(drawable:getWidth() * 0.5 * scale)
  else 
    -- align left, no adjustment
  end
  GraphicsUtil.draw(drawable, x, y, 0, scale, scale)
end

function Match:drawMatchTime(timeString, themePositionOffset, scale)
  local x = self:matchelementOriginX() + themePositionOffset[1]
  local y = self:matchelementOriginY() + themePositionOffset[2]
  GraphicsUtil.draw_time(timeString, x, y, scale)
end

function Match:drawTimer()
  -- Draw the timer for time attack
  if self.puzzle then
    -- puzzles don't have a timer...yet?
  else
    local frames = 0
    local stack = self.stacks[1]
    if stack ~= nil and stack.game_stopwatch ~= nil and tonumber(stack.game_stopwatch) ~= nil then
      frames = stack.game_stopwatch
    end

    if self.timeLimit then
      frames = (self.timeLimit * 60) - frames
      if frames < 0 then
        frames = 0
      end
    end

    local timeString = frames_to_time_string(frames, self.ended)

    self:drawMatchLabel(themes[config.theme].images.IMG_time, themes[config.theme].timeLabel_Pos, themes[config.theme].timeLabel_Scale)
    self:drawMatchTime(timeString, themes[config.theme].time_Pos, themes[config.theme].time_Scale)
  end
end

function Match:drawMatchType()
  local matchImage = nil
  if self.ranked then
    matchImage = themes[config.theme].images.IMG_ranked
  else
    matchImage = themes[config.theme].images.IMG_casual
  end

  self:drawMatchLabel(matchImage, themes[config.theme].matchtypeLabel_Pos, themes[config.theme].matchtypeLabel_Scale)
end

function Match:drawCommunityMessage()
  -- Draw the community message
  if not config.debug_mode then
    GraphicsUtil.printf(join_community_msg or "", 0, 668, consts.CANVAS_WIDTH, "center")
  end
end

local function isRollbackActive(stack)
  return stack.framesBehind > GARBAGE_DELAY_LAND_TIME
end

function Match:render()
  if config.show_fps then
    GraphicsUtil.print("Dropped Frames: " .. GAME.droppedFrames, 1, 12)
  end

  if config.show_fps and #self.stacks > 1 then
    local drawY = 23
    for i = 1, #self.stacks do
      local stack = self.stacks[i]
      GraphicsUtil.print("P" .. stack.which .." Average Latency: " .. stack.framesBehind, 1, drawY)
      drawY = drawY + 11
    end

    if self:hasLocalPlayer() then
      if tableUtils.trueForAny(self.stacks, isRollbackActive) then
        -- let the player know that rollback is active
        local iconSize = 60
        local icon_width, icon_height = themes[config.theme].images.IMG_bug:getDimensions()
        local x = 5
        local y = 30
        GraphicsUtil.draw(themes[config.theme].images.IMG_bug, x, y, 0, iconSize / icon_width, iconSize / icon_height)
      end
    else
      if tableUtils.trueForAny(self.stacks, function(s) return s.framesBehind > MAX_LAG * 0.75 end) then
        -- let the spectator know the game is about to die
        local iconSize = 60
        local icon_width, icon_height = themes[config.theme].images.IMG_bug:getDimensions()
        local x = (consts.CANVAS_WIDTH / 2) - (iconSize / 2)
        local y = (consts.CANVAS_HEIGHT / 2) - (iconSize / 2)
        GraphicsUtil.draw(themes[config.theme].images.IMG_bug, x, y, 0, iconSize / icon_width, iconSize / icon_height)
      end
    end
  end

  if config.debug_mode then
    local padding = 14
    local drawX = 500
    local drawY = -4

    -- drawY = drawY + padding
    -- GraphicsUtil.printf("Time Spent Running " .. self.timeSpentRunning * 1000, drawX, drawY)

    -- drawY = drawY + padding
    -- local totalTime = love.timer.getTime() - self.createTime
    -- GraphicsUtil.printf("Total Time " .. totalTime * 1000, drawX, drawY)

    drawY = drawY + padding
    local totalTime = love.timer.getTime() - self.createTime
    local timePercent = math.round(self.timeSpentRunning / totalTime, 5)
    GraphicsUtil.printf("Time Percent Running Match: " .. timePercent, drawX, drawY)

    drawY = drawY + padding
    local maxTime = math.round(self.maxTimeSpentRunning, 5)
    GraphicsUtil.printf("Max Stack Update: " .. maxTime, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("Seed " .. self.seed, drawX, drawY)

    if self.gameOverClock and self.gameOverClock > 0 then
      drawY = drawY + padding
      GraphicsUtil.printf("gameOverClock " .. self.gameOverClock, drawX, drawY)
    end
  end

  if not self.isPaused or self.renderDuringPause then
    for _, stack in ipairs(self.stacks) do
      -- don't render stacks that only have an attack engine
      if stack.player or stack.healthEngine then
        stack:render()
      end

      if stack.garbageTarget then
        Telegraph:render(stack, stack.garbageTarget)
      end
    end

    -- Draw VS HUD
    if self.stackInteraction == GameModes.StackInteractions.VERSUS then
      if tableUtils.trueForAll(self.players, MatchParticipant.isHuman) or self.ranked then
        self:drawMatchType()
      end
    end

    self:drawTimer()
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
    local scale = consts.CANVAS_WIDTH / math.max(image:getWidth(), image:getHeight()) -- keep image ratio
    -- adjust coordinates to be centered
    local x = consts.CANVAS_WIDTH / 2
    local y = consts.CANVAS_HEIGHT / 2
    local xOffset = math.floor(image:getWidth() * 0.5)
    local yOffset = math.floor(image:getHeight() * 0.5)

    GraphicsUtil.draw(image, x, y, 0, scale, scale, xOffset, yOffset)
  end
  GraphicsUtil.printf(loc("pause"), 0, 330, consts.CANVAS_WIDTH, "center", nil, 1, 10)
  GraphicsUtil.printf(loc("pl_pause_help"), 0, 360, consts.CANVAS_WIDTH, "center", nil, 1)
end
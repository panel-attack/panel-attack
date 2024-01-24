local class = require("class")
local GraphicsUtil = require("graphics_util")
local consts = require("consts")
local GFX_SCALE = consts.GFX_SCALE

local StackBase = class(function(self, args)
  assert(args.which)
  assert(args.is_local ~= nil)
  assert(args.character)
  self.which = args.which
  self.is_local = args.is_local
  self.character = CharacterLoader.fullyResolveCharacterSelection(args.character)
  CharacterLoader.load(self.character)
  CharacterLoader.wait()

  -- basics
  self.framesBehindArray = {}
  self.framesBehind = 0
  self.clock = 0
  self.game_over_clock = -1 -- the exact clock frame the player lost, -1 while alive
  self.health = 1


  -- rollback
  self.rollbackCopies = {}
  self.rollbackCopyPool = Queue()
  self.rollbackCount = 0
  self.lastRollbackFrame = -1 -- the last frame we had to rollback from

  -- graphics
  self.canvas = love.graphics.newCanvas(312, 612, {dpiscale = GAME:newCanvasSnappedScale()})
  self.healthQuad = GraphicsUtil:newRecycledQuad(0, 0, themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight(), themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight())
  self.wins_quads = {}
end)

-- Provides the X origin to draw an element of the stack
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
function StackBase:elementOriginX(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  assert(cameFromLegacyScoreOffset ~= nil)
  assert(legacyOffsetIsAlreadyScaled ~= nil)
  local x = 546
  if self.which == 2 then
    x = 642
  end
  if cameFromLegacyScoreOffset == false or themes[config.theme]:offsetsAreFixed() then
    x = self.origin_x
    if legacyOffsetIsAlreadyScaled == false or themes[config.theme]:offsetsAreFixed() then
      x = x * GFX_SCALE
    end
  end
  return x
end

-- Provides the Y origin to draw an element of the stack
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
function StackBase:elementOriginY(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  assert(cameFromLegacyScoreOffset ~= nil)
  assert(legacyOffsetIsAlreadyScaled ~= nil)
  local y = 208
  if cameFromLegacyScoreOffset == false or themes[config.theme]:offsetsAreFixed() then
    y = self.panelOriginY
    if legacyOffsetIsAlreadyScaled == false or themes[config.theme]:offsetsAreFixed() then
      y = y * GFX_SCALE
    end
  end
  return y
end

-- Provides the X position to draw an element of the stack, shifted by the given offset and mirroring
-- themePositionOffset - the theme offset array
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
-- legacyOffsetIsAlreadyScaled - set to true if the offset used to be already scaled in legacy themes
function StackBase:elementOriginXWithOffset(themePositionOffset, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  if legacyOffsetIsAlreadyScaled == nil then
    legacyOffsetIsAlreadyScaled = false
  end
  local xOffset = themePositionOffset[1]
  if cameFromLegacyScoreOffset == false or themes[config.theme]:offsetsAreFixed() then
    xOffset = xOffset * self.mirror_x
  end
  if cameFromLegacyScoreOffset == false and themes[config.theme]:offsetsAreFixed() == false and legacyOffsetIsAlreadyScaled == false then
    xOffset = xOffset * GFX_SCALE
  end
  local x = self:elementOriginX(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled) + xOffset
  return x
end

-- Provides the Y position to draw an element of the stack, shifted by the given offset and mirroring
-- themePositionOffset - the theme offset array
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
function StackBase:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  if legacyOffsetIsAlreadyScaled == nil then
    legacyOffsetIsAlreadyScaled = false
  end
  local yOffset = themePositionOffset[2]
  if cameFromLegacyScoreOffset == false and themes[config.theme]:offsetsAreFixed() == false and legacyOffsetIsAlreadyScaled == false then
    yOffset = yOffset * GFX_SCALE
  end
  local y = self:elementOriginY(cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled) + yOffset
  return y
end

-- Provides the X position to draw a label of the stack, shifted by the given offset, mirroring and label width
-- themePositionOffset - the theme offset array
-- cameFromLegacyScoreOffset - set to true if this used to use the "score" position in legacy themes
-- width - width of the drawable
-- percentWidthShift - the percent of the width you want shifted left
function StackBase:labelOriginXWithOffset(themePositionOffset, scale, cameFromLegacyScoreOffset, width, percentWidthShift, legacyOffsetIsAlreadyScaled)
  local x = self:elementOriginXWithOffset(themePositionOffset, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)

  if percentWidthShift > 0 then
    x = x - math.floor((percentWidthShift * width * scale))
  end

  return x
end

function StackBase:drawLabel(drawable, themePositionOffset, scale, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)
  if cameFromLegacyScoreOffset == nil then
    cameFromLegacyScoreOffset = false
  end

  local percentWidthShift = 0
  -- If we are mirroring from the right, move the full width left
  if cameFromLegacyScoreOffset == false or themes[config.theme]:offsetsAreFixed() then
    if self.multiplication > 0 then
      percentWidthShift = 1
    end
  end

  local x = self:labelOriginXWithOffset(themePositionOffset, scale, cameFromLegacyScoreOffset, drawable:getWidth(), percentWidthShift, legacyOffsetIsAlreadyScaled)
  local y = self:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset, legacyOffsetIsAlreadyScaled)

  GraphicsUtil.draw(drawable, x, y, 0, scale, scale)
end

function StackBase:drawBar(image, quad, themePositionOffset, height, yOffset, rotate, scale)
  local imageWidth, imageHeight = image:getDimensions()
  local barYScale = height / imageHeight
  local quadY = 0
  if barYScale < 1 then
    barYScale = 1
    quadY = imageHeight - height
  end
  local x = self:elementOriginXWithOffset(themePositionOffset, false)
  local y = self:elementOriginYWithOffset(themePositionOffset, false)
  quad:setViewport(0, quadY, imageWidth, imageHeight - quadY)
  GraphicsUtil.drawQuad(image, quad, x, y - height - yOffset, rotate, scale, scale * barYScale, 0, 0, self.mirror_x)
end

function StackBase:drawNumber(number, themePositionOffset, scale, cameFromLegacyScoreOffset)
  if cameFromLegacyScoreOffset == nil then
    cameFromLegacyScoreOffset = false
  end
  local x = self:elementOriginXWithOffset(themePositionOffset, cameFromLegacyScoreOffset)
  local y = self:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset)
  GraphicsUtil.drawPixelFont(number, themes[config.theme].fontMaps.numbers[self.which], x, y, scale, "center", 0)
end

function StackBase:drawString(string, themePositionOffset, cameFromLegacyScoreOffset, fontSize)
  if cameFromLegacyScoreOffset == nil then
    cameFromLegacyScoreOffset = false
  end
  local x = self:elementOriginXWithOffset(themePositionOffset, cameFromLegacyScoreOffset)
  local y = self:elementOriginYWithOffset(themePositionOffset, cameFromLegacyScoreOffset)
  
  local limit = consts.CANVAS_WIDTH - x
  local alignment = "left"
  if themes[config.theme]:offsetsAreFixed() then
    if self.which == 1 then
      limit = x
      x = 0
      alignment = "right"
    end
  end

  if fontSize == nil then
    fontSize = GraphicsUtil.fontSize
  end
  local fontDelta = fontSize - GraphicsUtil.fontSize

  gprintf(string, x, y, limit, alignment, nil, nil, fontDelta)
end

-- Positions the stack draw position for the given player
function StackBase:moveForRenderIndex(renderIndex)
    -- Position of elements should ideally be on even coordinates to avoid non pixel alignment
    if renderIndex == 1 then
      self.mirror_x = 1
      self.multiplication = 0
    elseif renderIndex == 2 then
      self.mirror_x = -1
      self.multiplication = 1
    end
    local centerX = (consts.CANVAS_WIDTH / 2)
    local stackWidth = self:stackCanvasWidth()
    local innerStackXMovement = 100
    local outerStackXMovement = stackWidth + innerStackXMovement
    self.panelOriginXOffset = 4
    self.panelOriginYOffset = 4

    local outerNonScaled = centerX - (outerStackXMovement * self.mirror_x)
    self.origin_x = (self.panelOriginXOffset * self.mirror_x) + (outerNonScaled / GFX_SCALE) -- The outer X value of the frame

    local frameOriginNonScaled = outerNonScaled
    if self.mirror_x == -1 then
      frameOriginNonScaled = outerNonScaled - stackWidth
    end
    self.frameOriginX = frameOriginNonScaled / GFX_SCALE -- The left X value where the frame is drawn
    self.frameOriginY = 108 / GFX_SCALE

    self.panelOriginX = self.frameOriginX + self.panelOriginXOffset
    self.panelOriginY = self.frameOriginY + self.panelOriginYOffset
end

local mask_shader = love.graphics.newShader [[
   vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      if (Texel(texture, texture_coords).rgb == vec3(0.0)) {
         // a discarded pixel wont be applied as the stencil.
         discard;
      }
      return vec4(1.0);
   }
]]


function StackBase:setCanvas()
  local function frameMask()
    love.graphics.setShader(mask_shader)
    love.graphics.setBackgroundColor(1, 1, 1)
    local canvas_w, canvas_h = self.canvas:getDimensions()
    love.graphics.rectangle("fill", 0, 0, canvas_w, canvas_h)
    love.graphics.setBackgroundColor(unpack(GAME.backgroundColor))
    love.graphics.setShader()
  end

  love.graphics.setCanvas({self.canvas, stencil = true})
  love.graphics.clear()
  love.graphics.stencil(frameMask, "replace", 1)
  love.graphics.setStencilTest("greater", 0)

  self:drawCharacter()
  self:drawFrame()
end

function StackBase:drawCharacter()
  -- Update portrait fade if needed
  if self.do_countdown then
    -- self.portraitFade starts at 0 (no fade)
    if self.clock and self.clock > 0 then
      local desiredFade = config.portrait_darkness / 100
      local startFrame = 50
      local fadeDuration = 30
      if self.clock <= 50 then
        self.portraitFade = 0
      elseif self.clock > 50 and self.clock <= startFrame + fadeDuration then
        local percent = (self.clock - startFrame) / fadeDuration
        self.portraitFade = desiredFade * percent
      end
    end
  end

  characters[self.character]:drawPortrait(self.which, self.panelOriginXOffset, self.panelOriginYOffset, self.portraitFade)
end

function StackBase:drawFrame()
  local frameImage = themes[config.theme].images.frames[self.which]

  if frameImage then
    local scaleX = 312 / frameImage:getWidth()
    local scaleY = 612 / frameImage:getHeight()
    love.graphics.draw(frameImage, 0, 0, 0, scaleX, scaleY)
  end
end

function StackBase:drawWall(displacement, rowCount)
  local wallImage = themes[config.theme].images.walls[self.which]

  if wallImage then
    local y = (4 - displacement + rowCount * 16) * GFX_SCALE
    local width = 288
    local scaleX = width / wallImage:getWidth()
    love.graphics.draw(wallImage, 12, y, 0, scaleX, scaleX)
  end
end

function StackBase:drawCountdown()
  if self.do_countdown and self.countdown_timer and self.countdown_timer > 0 then
    local ready_x = 16
    local initial_ready_y = 4
    local ready_y_drop_speed = 6
    local ready_y = initial_ready_y + (math.min(8, self.clock) - 1) * ready_y_drop_speed
    local countdown_x = 44
    local countdown_y = 68
    if self.clock <= 8 then
      GraphicsUtil.drawGfxScaled(themes[config.theme].images.IMG_ready, ready_x, ready_y)
    elseif self.clock >= 9 and self.countdown_timer and self.countdown_timer > 0 then
      if self.countdown_timer >= 100 then
        GraphicsUtil.drawGfxScaled(themes[config.theme].images.IMG_ready, ready_x, ready_y)
      end
      local IMG_number_to_draw = themes[config.theme].images.IMG_numbers[math.ceil(self.countdown_timer / 60)]
      if IMG_number_to_draw then
        GraphicsUtil.drawGfxScaled(IMG_number_to_draw, countdown_x, countdown_y)
      end
    end
  end
end

function StackBase:stackCanvasWidth()
  local stackCanvasWidth = 0
  if self.canvas then
    stackCanvasWidth = math.floor(self.canvas:getWidth())
  end
  return stackCanvasWidth
end

function StackBase:drawCanvas()
  love.graphics.setStencilTest()
  love.graphics.setCanvas(GAME.globalCanvas)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(self.canvas, self.frameOriginX * GFX_SCALE, self.frameOriginY * GFX_SCALE)
  love.graphics.setBlendMode("alpha", "alphamultiply")
end

function StackBase:drawAbsoluteMultibar(stop_time, shake_time)
  self:drawLabel(themes[config.theme].images.healthbarFrames.absolute[self.which], themes[config.theme].healthbar_frame_Pos, themes[config.theme].healthbar_frame_Scale)

  local multiBarFrameCount = self.multiBarFrameCount
  local multiBarMaxHeight = 589 * themes[config.theme].multibar_Scale
  local bottomOffset = 0

  local healthHeight = (self.health / multiBarFrameCount) * multiBarMaxHeight
  self:drawBar(themes[config.theme].images.IMG_healthbar, self.healthQuad, themes[config.theme].multibar_Pos, healthHeight, 0, 0, themes[config.theme].multibar_Scale)

  bottomOffset = healthHeight

  local stopHeight = 0
  local preStopHeight = 0

  if shake_time > 0 and shake_time > (stop_time + self.pre_stop_time) then
    -- shake is only drawn if it is greater than prestop + stop
    -- shake is always guaranteed to fit
    local shakeHeight = (shake_time / multiBarFrameCount) * multiBarMaxHeight
    self:drawBar(themes[config.theme].images.IMG_multibar_shake_bar, self.multi_shakeQuad, themes[config.theme].multibar_Pos, shakeHeight, bottomOffset, 0, themes[config.theme].multibar_Scale)
  else
    -- stop/prestop are only drawn if greater than shake
    if stop_time > 0 then
      stopHeight = math.min(stop_time, multiBarFrameCount - self.health) / multiBarFrameCount * multiBarMaxHeight
      self:drawBar(themes[config.theme].images.IMG_multibar_stop_bar, self.multi_stopQuad, themes[config.theme].multibar_Pos, stopHeight, bottomOffset, 0, themes[config.theme].multibar_Scale)

      bottomOffset = bottomOffset + stopHeight
    end
    if self.pre_stop_time and self.pre_stop_time > 0 then
      local totalInvincibility = self.health + self.stop_time + self.pre_stop_time
      local remainingSeconds = 0
      if totalInvincibility > multiBarFrameCount then
        -- total invincibility exceeds what the multibar can display -> fill only the remaining space with prestop
        preStopHeight = (1 - (self.health + stop_time) / multiBarFrameCount) * multiBarMaxHeight
        remainingSeconds = (totalInvincibility - multiBarFrameCount) / 60
      else
        preStopHeight = self.pre_stop_time / multiBarFrameCount * multiBarMaxHeight
      end

      self:drawBar(themes[config.theme].images.IMG_multibar_prestop_bar, self.multi_prestopQuad, themes[config.theme].multibar_Pos, preStopHeight, bottomOffset, 0, themes[config.theme].multibar_Scale)

      if remainingSeconds > 0 then
        self:drawString(tostring(math.floor(remainingSeconds)), themes[config.theme].multibar_LeftoverTime_Pos, false, 20)
      end
    end
  end
end

function StackBase:drawPlayerName()
  local username = (self.player.name or "")
  self:drawString(username, themes[config.theme].name_Pos, true, themes[config.theme].name_Font_Size)
end

function StackBase:drawWinCount()
  self:drawLabel(themes[config.theme].images.IMG_wins, themes[config.theme].winLabel_Pos, themes[config.theme].winLabel_Scale, true)
  self:drawNumber(self.player:getWinCountForDisplay(), themes[config.theme].win_Pos, themes[config.theme].win_Scale, true)
end

--------------------------------
------ abstract functions ------
--------------------------------

function StackBase:receiveGarbage(frameToReceive, garbageArray)
  error("did not implement receiveGarbage")
end

function StackBase:saveForRollback()
  error("did not implement saveForRollback")
end

function StackBase:rollbackToFrame(frame)
  error("did not implement rollbackToFrame")
end

function StackBase:starting_state()
  error("did not implement starting_state")
end

function StackBase:deinit()
  error("did not implement deinit")
end

function StackBase:render()
  error("did not implement render")
end

function StackBase:game_ended()
  error("did not implement game_ended")
end

function StackBase:shouldRun()
  error("did not implement shouldRun")
end

function StackBase:run()
  error("did not implement run")
end

function StackBase:runGameOver()
  error("did not implement runGameOver")
end

return StackBase

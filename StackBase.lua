local class = require("class")
local graphicsUtil = require("graphics_util")

local StackBase = class(function(self)
  self.canvas = love.graphics.newCanvas(104 * GFX_SCALE, 204 * GFX_SCALE, {dpiscale = GAME:newCanvasSnappedScale()})
end)

local mask_shader = love.graphics.newShader [[
   vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      if (Texel(texture, texture_coords).rgb == vec3(0.0)) {
         // a discarded pixel wont be applied as the stencil.
         discard;
      }
      return vec4(1.0);
   }
]]

function StackBase:frameMask()
  love.graphics.setShader(mask_shader)
  love.graphics.setBackgroundColor(1, 1, 1)
  local canvas_w, canvas_h = self.canvas:getDimensions()
  love.graphics.rectangle("fill", 0, 0, canvas_w, canvas_h)
  love.graphics.setBackgroundColor(unpack(global_background_color))
  love.graphics.setShader()
end

function StackBase:setCanvas()
  love.graphics.setCanvas({self.canvas, stencil = true})
  love.graphics.clear()
  love.graphics.stencil(self.frameMask, "replace", 1)
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

  characters[self.character]:drawPortrait(self.which, 4, 4, self.portraitFade)
end

function StackBase:drawFrame()
  local frameImage = themes[config.theme].images.frames[self.which]

  if frameImage then
    graphicsUtil.drawScaledImage(frameImage, 0, 0, 312, 612)
  end
end

function StackBase:drawWall(displacement, rowCount)
  local wallImage = themes[config.theme].images.walls[self.which]

  if wallImage then
    graphicsUtil.drawScaledWidthImage(wallImage, 12, (4 - displacement + rowCount * 16) * GFX_SCALE, 288)
  end
end

function StackBase:drawCountdown()
  if self.do_countdown and self.countdown_timer > 0 then
    local ready_x = 16
    local initial_ready_y = 4
    local ready_y_drop_speed = 6
    local ready_y = initial_ready_y + (math.min(8, self.clock) - 1) * ready_y_drop_speed
    local countdown_x = 44
    local countdown_y = 68
    if self.clock <= 8 then
      draw(themes[config.theme].images.IMG_ready, ready_x, ready_y)
    elseif self.clock >= 9 and self.countdown_timer and self.countdown_timer > 0 then
      if self.countdown_timer >= 100 then
        draw(themes[config.theme].images.IMG_ready, ready_x, ready_y)
      end
      local IMG_number_to_draw = themes[config.theme].images.IMG_numbers[math.ceil(self.countdown_timer / 60)]
      if IMG_number_to_draw then
        draw(IMG_number_to_draw, countdown_x, countdown_y)
      end
    end
  end
end

function StackBase:drawCanvas()
  love.graphics.setStencilTest()
  love.graphics.setCanvas(GAME.globalCanvas)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(self.canvas, self.frameOriginX * GFX_SCALE, self.frameOriginY * GFX_SCALE)
  love.graphics.setBlendMode("alpha", "alphamultiply")
end

function StackBase:drawAbsoluteMultibar(stop_time, shake_time)
  self:drawLabel(themes[config.theme].images["IMG_healthbar_frame" .. self.id .. "_absolute"], themes[config.theme].healthbar_frame_Pos, themes[config.theme].healthbar_frame_Scale)

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

return StackBase

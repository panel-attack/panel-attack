require("util")
local GraphicsUtil = require("graphics_util")
local TouchDataEncoding = require("engine.TouchDataEncoding")
local consts = require("consts")

local floor = math.floor
local ceil = math.ceil

-- frames to use for bounce animation
local BOUNCE_TABLE = {1, 1, 1, 1,
                2, 2, 2,
                3, 3, 3,
                4, 4, 4}

-- frames to use for garbage bounce animation
local GARBAGE_BOUNCE_TABLE = {2, 2, 2,
                              3, 3, 3,
                              4, 4, 4,
                              1, 1}

-- frames to use for in danger animation
local DANGER_BOUNCE_TABLE = {1, 1, 1,
                              2, 2, 2,
                              3, 3, 3,
                              2, 2, 2,
                              1, 1, 1,
                              4, 4, 4}

-- The popping particle animation. First number is how far the particles go, second is which frame to show from the spritesheet
local POPFX_BURST_ANIMATION = {{1, 1}, {4, 1}, {7, 1}, {8, 1}, {9, 1}, {9, 1},
                               {10, 1}, {10, 2}, {10, 2}, {10, 3}, {10, 3}, {10, 4},
                               {10, 4}, {10, 5}, {10, 5}, {10, 6}, {10, 6}, {10, 7},
                               {10, 7}, {10, 8}, {10, 8}, {10, 8}}

local POPFX_FADE_ANIMATION = {1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8}

local GFX_SCALE = consts.GFX_SCALE

local shake_arr = {}

-- Setup the shake_arr data used for rendering the stack shake animation
local shake_idx = -6
for i = 14, 6, -1 do
  local x = -math.pi
  local step = math.pi * 2 / i
  for j = 1, i do
    shake_arr[shake_idx] = (1 + math.cos(x)) / 2
    x = x + step
    shake_idx = shake_idx + 1
  end
end

-- 1 -> 1
-- #shake -> 0
local shake_step = 1 / (#shake_arr - 1)
local shake_mult = 1
for i = 1, #shake_arr do
  shake_arr[i] = shake_arr[i] * shake_mult
  -- print(shake_arr[i])
  shake_mult = shake_mult - shake_step
end

-- Update all the card frames used for doing the card animation
function Stack.update_cards(self)
  if self.canvas == nil then
    return
  end

  for i = self.card_q.first, self.card_q.last do
    local card = self.card_q[i]
    if consts.CARD_ANIMATION[card.frame] then
      card.frame = card.frame + 1
      if (consts.CARD_ANIMATION[card.frame] == nil) then
        if config.popfx == true then
          GraphicsUtil:releaseQuad(card.burstParticle)
        end
        self.card_q:pop()
      end
    else
      card.frame = card.frame + 1
    end
  end
end

-- Render the card animations used to show "bursts" when a combo or chain happens
function Stack.draw_cards(self)
  for i = self.card_q.first, self.card_q.last do
    local card = self.card_q[i]
    if consts.CARD_ANIMATION[card.frame] then
      local draw_x = (self.panelOriginX) + (card.x - 1) * 16
      local draw_y = (self.panelOriginY) + (11 - card.y) * 16 + self.displacement - consts.CARD_ANIMATION[card.frame]
      if config.popfx == true and card.frame then
        burstFrameDimension = card.burstAtlas:getWidth() / 9
        -- draw cardfx
        if card.frame <= 21 then
          radius = (200 - (card.frame * 7)) * (config.cardfx_scale / 100)
        end
        if card.frame > 21 then
          radius = (100 - (card.frame * 3)) * (config.cardfx_scale / 100)
        end
        if radius < 10 then
          radius = 10
        end
        for i = 1, 6, 1 do
          local cardfx_x = draw_x + math.cos(math.rad((i * 60) + (card.frame * 5))) * radius
          local cardfx_y = draw_y + math.sin(math.rad((i * 60) + (card.frame * 5))) * radius
          GraphicsUtil.drawQuadGfxScaled(card.burstAtlas, card.burstParticle, cardfx_x, cardfx_y, 0, 16 / burstFrameDimension, 16 / burstFrameDimension)
        end
      end
      -- draw card
      local iconSize = 48 / GFX_SCALE
      local cardImage = nil
      if card.chain then
        cardImage = self.theme:chainImage(card.n)
      else
        cardImage = self.theme:comboImage(card.n)
      end
      if cardImage then
        local icon_width, icon_height = cardImage:getDimensions()
        local fade = 1 - math.min(0.5 * ((card.frame-1) / 22), 0.5)
        GraphicsUtil.setColor(1, 1, 1, fade)
        GraphicsUtil.drawGfxScaled(cardImage, draw_x, draw_y, 0, iconSize / icon_width, iconSize / icon_height)
        GraphicsUtil.setColor(1, 1, 1, 1)
      end
    end
  end
end

-- Update all the pop animations
function Stack.update_popfxs(self)
  if self.canvas == nil then
    return
  end
  
  for i = self.pop_q.first, self.pop_q.last do
    local popfx = self.pop_q[i]
    if characters[self.character].popfx_style == "burst" or characters[self.character].popfx_style == "fadeburst" then
      popfx_animation = POPFX_BURST_ANIMATION
    end
    if characters[self.character].popfx_style == "fade" then
      popfx_animation = POPFX_FADE_ANIMATION
    end
    if POPFX_BURST_ANIMATION[popfx.frame] then
      popfx.frame = popfx.frame + 1
      if (POPFX_BURST_ANIMATION[popfx.frame] == nil) then
        if characters[self.character].images["burst"] then
          GraphicsUtil:releaseQuad(popfx.burstParticle)
        end
        if characters[self.character].images["fade"] then
          GraphicsUtil:releaseQuad(popfx.fadeParticle)
        end
        if characters[self.character].images["burst"] then
          GraphicsUtil:releaseQuad(popfx.bigParticle)
        end
        self.pop_q:pop()
      end
    else
      popfx.frame = popfx.frame + 1
    end
  end
end

-- Draw the pop animations that happen when matches are made
function Stack.draw_popfxs(self)
  for i = self.pop_q.first, self.pop_q.last do
    local popfx = self.pop_q[i]
    local draw_x = (self.panelOriginX) + (popfx.x - 1) * 16
    local draw_y = (self.panelOriginY) + (11 - popfx.y) * 16 + self.displacement
    local burstScale = characters[self.character].popfx_burstScale
    local fadeScale = characters[self.character].popfx_fadeScale
    local burstParticle_atlas = popfx.burstAtlas
    local burstParticle = popfx.burstParticle
    local burstFrameDimension = popfx.burstFrameDimension
    local fadeParticle_atlas = popfx.fadeAtlas
    local fadeParticle = popfx.fadeParticle
    local fadeFrameDimension = popfx.fadeFrameDimension
    if characters[self.character].popfx_style == "burst" or characters[self.character].popfx_style == "fadeburst" then
      if characters[self.character].images["burst"] then
        burstFrame = POPFX_BURST_ANIMATION[popfx.frame]
        if POPFX_BURST_ANIMATION[popfx.frame] then
          burstParticle:setViewport(burstFrame[2] * burstFrameDimension, 0, burstFrameDimension, burstFrameDimension, burstParticle_atlas:getDimensions())
          positions = {
            -- four corner
            {x = draw_x - burstFrame[1], y = draw_y - burstFrame[1]},
            {x = draw_x + 15 + burstFrame[1], y = draw_y - burstFrame[1]},
            {x = draw_x - burstFrame[1], y = draw_y + 15 + burstFrame[1]},
            {x = draw_x + 15 + burstFrame[1], y = draw_y + 15 + burstFrame[1]},
            -- top and bottom
            {x = draw_x, y = draw_y - (burstFrame[1] * 2)},
            {x = draw_x, y = draw_y + 10 + (burstFrame[1] * 2)},
            -- left and right
            {x = draw_x + 5 - (burstFrame[1] * 2), y = draw_y},
            {x = draw_x + 10 + (burstFrame[1] * 2), y = draw_y}
          }

          if characters[self.character].popfx_burstrotate == true then
            topRot = {math.rad(45), (16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale}
            bottomRot = {math.rad(-135), (16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale}
            leftRot = {math.rad(-45), (16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale}
            rightRot = {math.rad(135), (16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale}
          else
            topRot = {0, (16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale}
            bottomRot = {0, (16 / burstFrameDimension) * burstScale, -(16 / burstFrameDimension) * burstScale}
            leftRot = {0, (16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale}
            rightRot = {0, -(16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale}
          end

          randomMax = 0

          if popsize == "normal" then
            randomMax = 4
          end
          if popsize == "big" then
            randomMax = 6
          end
          if popsize == "giant" then
            randomMax = 8
          end
          if popsize ~= "small" and popfx.bigTimer == 0 then
            big_position = math.random(randomMax)
            big_position = 0
            popfx.bigTimer = 2
          end
          popfx.bigTimer = popfx.bigTimer - 1

          -- four corner
          if big_position ~= 1 then
            GraphicsUtil.drawQuadGfxScaled(burstParticle_atlas, burstParticle, positions[1].x, positions[1].y, 0, (16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
          end
          if big_position ~= 2 then
            GraphicsUtil.drawQuadGfxScaled(burstParticle_atlas, burstParticle, positions[2].x, positions[2].y, 0, -(16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
          end
          if big_position ~= 3 then
            GraphicsUtil.drawQuadGfxScaled(burstParticle_atlas, burstParticle, positions[3].x, positions[3].y, 0, (16 / burstFrameDimension) * burstScale, -(16 / burstFrameDimension) * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
          end
          if big_position ~= 4 then
            GraphicsUtil.drawQuadGfxScaled(burstParticle_atlas, burstParticle, positions[4].x, positions[4].y, 0, -(16 / burstFrameDimension) * burstScale, -16 / burstFrameDimension * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
          end
          -- top and bottom
          if popfx.popsize == "big" or popfx.popsize == "giant" then
            if big_position ~= 5 then
              GraphicsUtil.drawQuadGfxScaled(burstParticle_atlas, burstParticle, positions[5].x + 8, positions[5].y, topRot[1], topRot[2], topRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
            end
            if big_position ~= 6 then
              GraphicsUtil.drawQuadGfxScaled(burstParticle_atlas, burstParticle, positions[6].x + 8, positions[6].y, bottomRot[1], bottomRot[2], bottomRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
            end
          end
          -- left and right
          if popfx.popsize == "giant" then
            if big_position ~= 7 then
              GraphicsUtil.drawQuadGfxScaled(burstParticle_atlas, burstParticle, positions[7].x, positions[7].y + 8, leftRot[1], leftRot[2], leftRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
            end
            if big_position ~= 8 then
              GraphicsUtil.drawQuadGfxScaled(burstParticle_atlas, burstParticle, positions[8].x, positions[8].y + 8, rightRot[1], rightRot[2], rightRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
            end
          end
        --big particle
        --[[
          if popsize ~= "small" then
            GraphicsUtil.drawQuadGfxScaled(particle_atlas, popfx.bigParticle, 
            positions[big_position].x, positions[big_position].y, 0, 16/frameDimension, 16/frameDimension, frameDimension/2, frameDimension/2)
          end
        ]]
        end
      end
    end
    if characters[self.character].popfx_style == "fade" or characters[self.character].popfx_style == "fadeburst" then
      if characters[self.character].images["fade"] then
        fadeFrame = POPFX_FADE_ANIMATION[popfx.frame]
        if (fadeFrame ~= nil) then
          fadeParticle:setViewport(fadeFrame * fadeFrameDimension, 0, fadeFrameDimension, fadeFrameDimension, fadeParticle_atlas:getDimensions())
          GraphicsUtil.drawQuadGfxScaled(fadeParticle_atlas, fadeParticle, draw_x + 8, draw_y + 8, 0, (32 / fadeFrameDimension) * fadeScale, (32 / fadeFrameDimension) * fadeScale, fadeFrameDimension / 2, fadeFrameDimension / 2)
        end
      end
    end
  end
end

function Stack:drawDebug()
  if config.debug_mode then
    local x = self.origin_x + 480
    local y = self.frameOriginY + 160

    if self.danger then
      GraphicsUtil.print("danger", x, y + 135)
    end
    if self.danger_music then
      GraphicsUtil.print("danger music", x, y + 150)
    end

    GraphicsUtil.print(loc("pl_cleared", (self.panels_cleared or 0)), x, y + 165)
    GraphicsUtil.print(loc("pl_metal", (self.metal_panels_queued or 0)), x, y + 180)

    if self.input_state or self.taunt_up or self.taunt_down then
      local iraise, iswap, iup, idown, ileft, iright
      if self.inputMethod == "touch" then
        iraise, _, _ = TouchDataEncoding.latinStringToTouchData(self.input_state, self.width)
      else 
        iraise, iswap, iup, idown, ileft, iright = unpack(base64decode[self.input_state])
      end
      local inputs_to_print = "inputs:"
      if iraise then
        inputs_to_print = inputs_to_print .. "\nraise"
      end --◄▲▼►
      if iswap then
        inputs_to_print = inputs_to_print .. "\nswap"
      end
      if iup then
        inputs_to_print = inputs_to_print .. "\nup"
      end
      if idown then
        inputs_to_print = inputs_to_print .. "\ndown"
      end
      if ileft then
        inputs_to_print = inputs_to_print .. "\nleft"
      end
      if iright then
        inputs_to_print = inputs_to_print .. "\nright"
      end
      if self.taunt_down then
        inputs_to_print = inputs_to_print .. "\ntaunt_down"
      end
      if self.taunt_up then
        inputs_to_print = inputs_to_print .. "\ntaunt_up"
      end
      if self.inputMethod == "touch" then
        inputs_to_print = inputs_to_print .. self.touchInputController:debugString()
      end
      GraphicsUtil.print(inputs_to_print, x, y + 195)
    end

    local drawX = self.frameOriginX + self:stackCanvasWidth() / 2
    local drawY = 10
    local padding = 14

    GraphicsUtil.drawRectangle("fill", drawX - 5, drawY - 5, 1000, 100, 0, 0, 0, 0.5)
    GraphicsUtil.printf("Clock " .. self.clock, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("Confirmed " .. #self.confirmedInput, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("input_buffer " .. #self.input_buffer, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("rollbackCount " .. self.rollbackCount, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("game_over_clock " .. (self.game_over_clock or 0), drawX, drawY)

    drawY = drawY + padding
      GraphicsUtil.printf("has chain panels " .. tostring(self:hasChainingPanels()), drawX, drawY)

    drawY = drawY + padding
      GraphicsUtil.printf("has active panels " .. tostring(self:hasActivePanels()), drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("riselock " .. tostring(self.rise_lock), drawX, drawY)

    -- drawY = drawY + padding
    -- GraphicsUtil.printf("P" .. stack.which .." Panels: " .. stack.panel_buffer, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("P" .. self.which .." Ended?: " .. tostring(self:game_ended()), drawX, drawY)

    -- drawY = drawY + padding
    -- GraphicsUtil.printf("P" .. stack.which .." attacks: " .. #stack.telegraph.attacks, drawX, drawY)

    -- drawY = drawY + padding
    -- GraphicsUtil.printf("P" .. stack.which .." Garbage Q: " .. stack.garbage_q:len(), drawX, drawY)

    -- if stack.telegraph then
    --   drawY = drawY + padding
    --   GraphicsUtil.printf("incoming chains " .. stack.telegraph.garbage_queue.chain_garbage:len(), drawX, drawY)

    --   for combo_garbage_width=3,6 do
    --     drawY = drawY + padding
    --     GraphicsUtil.printf("incoming combos " .. stack.telegraph.garbage_queue.combo_garbage[combo_garbage_width]:len(), drawX, drawY)
    --   end
    -- end
  end
end

function Stack:drawDebugPanels(shakeOffset)
  if not config.debug_mode then
    return
  end

  local mouseX, mouseY = GAME:transform_coordinates(love.mouse.getPosition())

    for row = 0, math.min(self.height + 1, #self.panels) do
      for col = 1, self.width do
        local panel = self.panels[row][col]
        local draw_x = (self.panelOriginX + (col - 1) * 16) * GFX_SCALE
        local draw_y = (self.panelOriginY + (11 - (row)) * 16 + self.displacement - shakeOffset) * GFX_SCALE

        -- Require hovering over a stack to show details
        if mouseX >= self.panelOriginX * GFX_SCALE and mouseX <= (self.panelOriginX + self.width * 16) * GFX_SCALE then
          if not (panel.color == 0 and panel.state == "normal") then
            GraphicsUtil.print(panel.state, draw_x, draw_y)
            if panel.matchAnyway then
              GraphicsUtil.print(tostring(panel.matchAnyway), draw_x, draw_y + 10)
              if panel.debug_tag then
                GraphicsUtil.print(tostring(panel.debug_tag), draw_x, draw_y + 20)
              end
            end
            if panel.chaining then
              GraphicsUtil.print("chaining", draw_x, draw_y + 30)
            end
          end
        end

        if mouseX >= draw_x and mouseX < draw_x + 16 * GFX_SCALE and mouseY >= draw_y and mouseY < draw_y + 16 * GFX_SCALE then
          local str = loc("pl_panel_info", row, col)
          for k, v in pairsSortedByKeys(panel) do
            str = str .. "\n" .. k .. ": " .. tostring(v)
          end

          local drawX = 30
          local drawY = 10

          GraphicsUtil.drawRectangle("fill", drawX - 5, drawY - 5, 100, 100, 0, 0, 0, 0.5)
          GraphicsUtil.printf(str, drawX, drawY)
        end
      end
    end
end

-- Renders the player's stack on screen
function Stack.render(self)
  if self.canvas == nil then
    return
  end

  self:setCanvas()
  self:drawCharacter()

  local garbageImages
  local shockGarbageImages
  if not self.garbageTarget then
    garbageImages = characters[self.character].images
  else
    garbageImages = characters[self.garbageTarget.character].images
  end

  if self.opponentStack then
    shockGarbageImages = panels[self.opponentStack.panels_dir].images.metals
  else
    shockGarbageImages = panels[self.panels_dir].images.metals
  end

  local shake_idx = #shake_arr - self.shake_time
  local shake = ceil((shake_arr[shake_idx] or 0) * 13)

  self:drawPanels(garbageImages, shockGarbageImages, shake)

  self:drawFrame()
  self:drawWall(shake, self.height)

  -- Draw the cursor
  if self:game_ended() == false then
    self:render_cursor()
  end

  self:drawCountdown()
  self:drawCanvas()

  self:draw_popfxs()
  self:draw_cards()

  self:drawDebugPanels(shake)
  self:drawDebug()
end

function Stack:drawRating()
  local rating
  if self.player.rating and tonumber(self.player.rating) then
    rating = self.player.rating
  elseif config.debug_mode then
    rating = 1544 + self.player.playerNumber
  end

  if rating then
    self:drawLabel(self.theme.images["IMG_rating_" .. self.which .. "P"], self.theme.ratingLabel_Pos, self.theme.ratingLabel_Scale, true)
    self:drawNumber(rating, self.theme.rating_Pos, self.theme.rating_Scale, true)
  end
end

-- Draw the stacks cursor
function Stack.render_cursor(self)
  if self.inputMethod == "touch" then
    if self.cur_row == 0 and self.cur_col == 0 then
      --no panel is touched, let's not draw the cursor
      return
    end
  end

  local cursorImage = self.theme.images.IMG_cursor[(floor(self.clock / 16) % 2) + 1]
  local shake_idx = #shake_arr - self.shake_time
  local shake = ceil((shake_arr[shake_idx] or 0) * 13)
  local desiredCursorWidth = 40
  local panelWidth = 16
  local scale_x = desiredCursorWidth / cursorImage:getWidth()
  local scale_y = 24 / cursorImage:getHeight()

  local renderCursor = true
  if self.countdown_timer then
    if self.clock % 2 ~= 0 then
      renderCursor = false
    end
  end
  if renderCursor then
    local xPosition = (self.cur_col - 1) * panelWidth
    GraphicsUtil.drawQuadGfxScaled(cursorImage, self.cursorQuads[1], xPosition, (11 - (self.cur_row)) * panelWidth + self.displacement - shake, 0, scale_x, scale_y)
    if self.inputMethod == "touch" then
      GraphicsUtil.drawQuadGfxScaled(cursorImage, self.cursorQuads[2], xPosition + 12, (11 - (self.cur_row)) * panelWidth + self.displacement - shake, 0, scale_x, scale_y)
    end
  end
end

-- Draw the stop time and healthbars
function Stack:drawMultibar()
  local stop_time = self.stop_time
  local shake_time = self.shake_time

  -- before the first move, display the stop time from the puzzle, not the stack
  if self.puzzle and self.puzzle.puzzleType == "clear" and self.puzzle.moves == self.puzzle.remaining_moves then
    stop_time = self.puzzle.stop_time
    shake_time = self.puzzle.shake_time
  end

  if self.theme.multibar_is_absolute then
    -- absolute multibar is *only* supported for v3 themes
    self:drawAbsoluteMultibar(stop_time, shake_time)
  else
    self:drawRelativeMultibar(stop_time, shake_time)
  end
end

function Stack:drawRelativeMultibar(stop_time, shake_time)
  self:drawLabel(self.theme.images.healthbarFrames.relative[self.which], self.theme.healthbar_frame_Pos, self.theme.healthbar_frame_Scale)

  -- Healthbar
  local healthbar = self.health * (self.theme.images.IMG_healthbar:getHeight() / self.levelData.maxHealth)
  self.healthQuad:setViewport(0, self.theme.images.IMG_healthbar:getHeight() - healthbar, self.theme.images.IMG_healthbar:getWidth(), healthbar)
  local x = self:elementOriginXWithOffset(self.theme.healthbar_Pos, false) / GFX_SCALE
  local y = self:elementOriginYWithOffset(self.theme.healthbar_Pos, false) + (self.theme.images.IMG_healthbar:getHeight() - healthbar) / GFX_SCALE
  GraphicsUtil.drawQuadGfxScaled(self.theme.images.IMG_healthbar, self.healthQuad, x, y, self.theme.healthbar_Rotate, self.theme.healthbar_Scale, self.theme.healthbar_Scale, 0, 0, self.multiplication)

  -- Prestop bar
  if self.pre_stop_time == 0 or self.maxPrestop == nil then
    self.maxPrestop = 0
  end
  if self.pre_stop_time > self.maxPrestop then
    self.maxPrestop = self.pre_stop_time
  end

  -- Stop bar
  if stop_time == 0 or self.maxStop == nil then
    self.maxStop = 0
  end
  if stop_time > self.maxStop then
    self.maxStop = stop_time
  end

  -- Shake bar
  if shake_time == 0 or self.maxShake == nil then
    self.maxShake = 0
  end
  if shake_time > self.maxShake then
    self.maxShake = shake_time
  end

  local multi_shake_bar, multi_stop_bar, multi_prestop_bar = 0, 0, 0
  if self.maxShake > 0 and shake_time >= self.pre_stop_time + stop_time then
    multi_shake_bar = shake_time * (self.theme.images.IMG_multibar_shake_bar:getHeight() / self.maxShake) * 3
  end
  if self.maxStop > 0 and shake_time < self.pre_stop_time + stop_time then
    multi_stop_bar = stop_time * (self.theme.images.IMG_multibar_stop_bar:getHeight() / self.maxStop) * 1.5
  end
  if self.maxPrestop > 0 and shake_time < self.pre_stop_time + stop_time then
    multi_prestop_bar = self.pre_stop_time * (self.theme.images.IMG_multibar_prestop_bar:getHeight() / self.maxPrestop) * 1.5
  end
  self.multi_shakeQuad:setViewport(0, self.theme.images.IMG_multibar_shake_bar:getHeight() - multi_shake_bar, self.theme.images.IMG_multibar_shake_bar:getWidth(), multi_shake_bar)
  self.multi_stopQuad:setViewport(0, self.theme.images.IMG_multibar_stop_bar:getHeight() - multi_stop_bar, self.theme.images.IMG_multibar_stop_bar:getWidth(), multi_stop_bar)
  self.multi_prestopQuad:setViewport(0, self.theme.images.IMG_multibar_prestop_bar:getHeight() - multi_prestop_bar, self.theme.images.IMG_multibar_prestop_bar:getWidth(), multi_prestop_bar)

  --Shake
  x = self:elementOriginXWithOffset(self.theme.multibar_Pos, false)
  y = self:elementOriginYWithOffset(self.theme.multibar_Pos, false)
  if self.theme.images.IMG_multibar_shake_bar then
    GraphicsUtil.drawQuad(self.theme.images.IMG_multibar_shake_bar, self.multi_shakeQuad, x, y + self.theme.images.IMG_multibar_shake_bar:getHeight() - multi_shake_bar, 0, self.theme.multibar_Scale, self.theme.multibar_Scale, 0, 0, self.multiplication)
  end
  --Stop
  if self.theme.images.IMG_multibar_stop_bar then
    GraphicsUtil.drawQuad(self.theme.images.IMG_multibar_stop_bar, self.multi_stopQuad, x, y - multi_shake_bar + self.theme.images.IMG_multibar_stop_bar:getHeight() - multi_stop_bar, 0, self.theme.multibar_Scale, self.theme.multibar_Scale, 0, 0, self.multiplication)
  end
  -- Prestop
  if self.theme.images.IMG_multibar_prestop_bar then
    GraphicsUtil.drawQuad(self.theme.images.IMG_multibar_prestop_bar, self.multi_prestopQuad, x, y - multi_shake_bar + multi_stop_bar + self.theme.images.IMG_multibar_prestop_bar:getHeight() - multi_prestop_bar, 0, self.theme.multibar_Scale, self.theme.multibar_Scale, 0, 0, self.multiplication)
  end
end

function Stack:drawScore()
  self:drawLabel(self.theme.images["IMG_score_" .. self.which .. "P"], self.theme.scoreLabel_Pos, self.theme.scoreLabel_Scale)
  self:drawNumber(self.score, self.theme.score_Pos, self.theme.score_Scale)
end

function Stack:drawSpeed()
  self:drawLabel(self.theme.images["IMG_speed_" .. self.which .. "P"], self.theme.speedLabel_Pos, self.theme.speedLabel_Scale)
  self:drawNumber(self.speed, self.theme.speed_Pos, self.theme.speed_Scale)
end

function Stack:drawLevel()
  if self.level then
    self:drawLabel(self.theme.images["IMG_level_" .. self.which .. "P"], self.theme.levelLabel_Pos, self.theme.levelLabel_Scale)

    local x = self:elementOriginXWithOffset(self.theme.level_Pos, false)
    local y = self:elementOriginYWithOffset(self.theme.level_Pos, false)
    local levelAtlas = self.theme.images.levelNumberAtlas[self.which]
    self.level_quad:setViewport(tonumber(self.level - 1) * levelAtlas.charWidth, 0, levelAtlas.charWidth, levelAtlas.charHeight, levelAtlas.image:getDimensions())
    GraphicsUtil.drawQuad(levelAtlas.image, self.level_quad, x, y, 0, 28 / levelAtlas.charWidth * self.theme.level_Scale, 26 / levelAtlas.charHeight * self.theme.level_Scale, 0, 0, self.multiplication)
  end
end

function Stack:drawAnalyticData()
  if not config.enable_analytics or not self.drawsAnalytics then
    return
  end

  local analytic = self.analytic
  local backgroundPadding = 18
  local paddingToAnalytics = 16
  local width = 160
  local height = 600
  local x = paddingToAnalytics + backgroundPadding
  if self.which == 2 then
    x = consts.CANVAS_WIDTH - paddingToAnalytics - width + backgroundPadding
  end
  local y = self.frameOriginY * GFX_SCALE + backgroundPadding

  local iconToTextSpacing = 30
  local nextIconIncrement = 30
  local column2Distance = 70

  local fontIncrement = 8
  local iconSize = 8
  local icon_width
  local icon_height

  -- Background
  GraphicsUtil.drawRectangle("fill", x - backgroundPadding , y - backgroundPadding, width, height, 0, 0, 0, 0.5)

  -- Panels cleared
  icon_width, icon_height = panels[self.panels_dir].images.classic[1][6]:getDimensions()
  GraphicsUtil.draw(panels[self.panels_dir].images.classic[1][6], x, y, 0, iconSize / icon_width * GFX_SCALE, iconSize / icon_height * GFX_SCALE)
  GraphicsUtil.printf(analytic.data.destroyed_panels, x + iconToTextSpacing, y + 0, consts.CANVAS_WIDTH, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  -- Garbage sent
  icon_width, icon_height = characters[self.character].images.face:getDimensions()
  GraphicsUtil.draw(characters[self.character].images.face, x, y, 0, iconSize / icon_width * GFX_SCALE, iconSize / icon_height * GFX_SCALE)
  GraphicsUtil.printf(analytic.data.sent_garbage_lines, x + iconToTextSpacing, y + 0, consts.CANVAS_WIDTH, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  -- GPM
  if analytic.lastGPM == 0 or math.fmod(self.clock, 60) < self.max_runs_per_frame then
    if self.clock > 0 and (analytic.data.sent_garbage_lines > 0) then
      analytic.lastGPM = analytic:getRoundedGPM(self.clock)
    end
  end
  icon_width, icon_height = self.theme.images.IMG_gpm:getDimensions()
  GraphicsUtil.draw(self.theme.images.IMG_gpm, x, y, 0, iconSize / icon_width * GFX_SCALE, iconSize / icon_height * GFX_SCALE)
  GraphicsUtil.printf(analytic.lastGPM .. "/m", x + iconToTextSpacing, y + 0, consts.CANVAS_WIDTH, "left", nil, 1, fontIncrement)  

  y = y + nextIconIncrement

  -- Moves
  icon_width, icon_height = self.theme.images.IMG_cursorCount:getDimensions()
  GraphicsUtil.draw(self.theme.images.IMG_cursorCount, x, y, 0, iconSize / icon_width * GFX_SCALE, iconSize / icon_height * GFX_SCALE)
  GraphicsUtil.printf(analytic.data.move_count, x + iconToTextSpacing, y + 0, consts.CANVAS_WIDTH, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  -- Swaps
  if self.theme.images.IMG_swap then
    icon_width, icon_height = self.theme.images.IMG_swap:getDimensions()
    GraphicsUtil.draw(self.theme.images.IMG_swap, x, y, 0, iconSize / icon_width * GFX_SCALE, iconSize / icon_height * GFX_SCALE)
  end
  GraphicsUtil.printf(analytic.data.swap_count, x + iconToTextSpacing, y + 0, consts.CANVAS_WIDTH, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  -- APM
  if analytic.lastAPM == 0 or math.fmod(self.clock, 60) < self.max_runs_per_frame then
    if self.clock > 0 and (analytic.data.swap_count + analytic.data.move_count > 0) then
      local actionsPerMinute = (analytic.data.swap_count + analytic.data.move_count) / (self.clock / 60 / 60)
      analytic.lastAPM = string.format("%0.0f", round(actionsPerMinute, 0))
    end
  end
  if self.theme.images.IMG_apm then
    icon_width, icon_height = self.theme.images.IMG_apm:getDimensions()
    GraphicsUtil.draw(self.theme.images.IMG_apm, x, y, 0, iconSize / icon_width * GFX_SCALE, iconSize / icon_height * GFX_SCALE)
  end
  GraphicsUtil.printf(analytic.lastAPM .. "/m", x + iconToTextSpacing, y + 0, consts.CANVAS_WIDTH, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  local yCombo = y

  -- Clean up the chain data so we only show chains up to the highest chain the user has done
  local chainData = {}
  local chain_above_limit = analytic:compute_above_chain_card_limit()

  for i = 2, self.theme.chainCardLimit, 1 do
    if not analytic.data.reached_chains[i] then
      chainData[i] = 0
    else
      chainData[i] = analytic.data.reached_chains[i]
    end
  end
  table.insert(chainData, chain_above_limit)
  for i = #chainData, 0, -1 do
    if chainData[i] and chainData[i] == 0 then
      chainData[i] = nil
    else
      break
    end
  end

  -- Draw the chain images
  for i = 2, self.theme.chainCardLimit + 1 do
    local chain_amount = chainData[i]
    if chain_amount and chain_amount > 0 then
      local cardImage = self.theme:chainImage(i)
      if cardImage then
        icon_width, icon_height = cardImage:getDimensions()
        GraphicsUtil.draw(cardImage, x, y, 0, iconSize / icon_width * GFX_SCALE, iconSize / icon_height * GFX_SCALE)
        GraphicsUtil.printf(chain_amount, x + iconToTextSpacing, y + 0, consts.CANVAS_WIDTH, "left", nil, 1, fontIncrement)
        y = y + nextIconIncrement
      end
    end
  end

  -- Clean up the combo data so we only show combos up to the highest combo the user has done
  local comboData = shallowcpy(analytic.data.used_combos)

  for i = 4, 15, 1 do
    if not comboData[i] then
      comboData[i] = 0
    end
  end
  local maxCombo = maxComboReached(analytic.data)
  for i = maxCombo, 0, -1 do
    if comboData[i] and comboData[i] == 0 then
      comboData[i] = nil
    else
      break
    end
  end

  -- Draw the combo images
  local xCombo = x + column2Distance
  for i, combo_amount in pairs(comboData) do
    if combo_amount and combo_amount > 0 then
      local cardImage = self.theme:comboImage(i)
      if cardImage then
        icon_width, icon_height = cardImage:getDimensions()
        GraphicsUtil.draw(cardImage, xCombo, yCombo, 0, iconSize / icon_width * GFX_SCALE, iconSize / icon_height * GFX_SCALE)
        GraphicsUtil.printf(combo_amount, xCombo + iconToTextSpacing, yCombo + 0, consts.CANVAS_WIDTH, "left", nil, 1, fontIncrement)
        yCombo = yCombo + nextIconIncrement
      end
    end
  end
end

function Stack:drawMoveCount()
  -- draw outside of stack's frame canvas
  if self.puzzle then
    self:drawLabel(self.theme.images.IMG_moves, self.theme.moveLabel_Pos, self.theme.moveLabel_Scale, false, true)
    local moveNumber = math.abs(self.puzzle.remaining_moves)
    if self.puzzle.puzzleType == "moves" then
      moveNumber = self.puzzle.remaining_moves
    end
    self:drawNumber(moveNumber, self.theme.move_Pos, self.theme.move_Scale, true)
  end
end

function Stack:drawPanels(garbageImages, shockGarbageImages, shakeOffset)
  local metal_w, metal_h = shockGarbageImages.mid:getDimensions()
  local metall_w, metall_h = shockGarbageImages.left:getDimensions()
  local metalr_w, metalr_h = shockGarbageImages.right:getDimensions()

  -- Draw all the panels
  for row = 0, self.height do
    for col = 1, self.width do
      local panel = self.panels[row][col]
      local draw_x = 4 + (col - 1) * 16
      local draw_y = 4 + (11 - (row)) * 16 + self.displacement - shakeOffset
      if panel.color ~= 0 and panel.state ~= "popped" then
        local draw_frame = 1
        if panel.isGarbage then
          local imgs = {flash = shockGarbageImages.flash}
          if not panel.metal then
            imgs = garbageImages
          end
          if panel.x_offset == 0 and panel.y_offset == 0 then
            -- draw the entire block!
            if panel.metal then
              GraphicsUtil.drawGfxScaled(shockGarbageImages.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h)
              GraphicsUtil.drawGfxScaled(shockGarbageImages.right, draw_x + 16 * (panel.width - 1) + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h)
              for i = 1, 2 * (panel.width - 1) do
                GraphicsUtil.drawGfxScaled(shockGarbageImages.mid, draw_x + 8 * i, draw_y, 0, 8 / metal_w, 16 / metal_h)
              end
            else
              local height, width = panel.height, panel.width
              local top_y = draw_y - (height - 1) * 16
              local use_1 = ((height - (height % 2)) / 2) % 2 == 0
              local filler_w, filler_h = imgs.filler1:getDimensions()
              for i = 0, height - 1 do
                for j = 1, width - 1 do
                  GraphicsUtil.drawGfxScaled((use_1 or height < 3) and imgs.filler1 or imgs.filler2, draw_x + 16 * j - 8, top_y + 16 * i, 0, 16 / filler_w, 16 / filler_h)
                  use_1 = not use_1
                end
              end
              if height % 2 == 1 then
                local face
                if imgs.face2 and width % 2 == 1 then
                  face = imgs.face2
                else
                  face = imgs.face
                end
                local face_w, face_h = face:getDimensions()
                GraphicsUtil.drawGfxScaled(face, draw_x + 8 * (width - 1), top_y + 16 * ((height - 1) / 2), 0, 16 / face_w, 16 / face_h)
              else
                local face_w, face_h = imgs.doubleface:getDimensions()
                GraphicsUtil.drawGfxScaled(imgs.doubleface, draw_x + 8 * (width - 1), top_y + 16 * ((height - 2) / 2), 0, 16 / face_w, 32 / face_h)
              end
              local corner_w, corner_h = imgs.topleft:getDimensions()
              local lr_w, lr_h = imgs.left:getDimensions()
              local topbottom_w, topbottom_h = imgs.top:getDimensions()
              GraphicsUtil.drawGfxScaled(imgs.left, draw_x, top_y, 0, 8 / lr_w, (1 / lr_h) * height * 16)
              GraphicsUtil.drawGfxScaled(imgs.right, draw_x + 16 * (width - 1) + 8, top_y, 0, 8 / lr_w, (1 / lr_h) * height * 16)
              GraphicsUtil.drawGfxScaled(imgs.top, draw_x, top_y, 0, (1 / topbottom_w) * width * 16, 2 / topbottom_h)
              GraphicsUtil.drawGfxScaled(imgs.bot, draw_x, draw_y + 14, 0, (1 / topbottom_w) * width * 16, 2 / topbottom_h)
              GraphicsUtil.drawGfxScaled(imgs.topleft, draw_x, top_y, 0, 8 / corner_w, 3 / corner_h)
              GraphicsUtil.drawGfxScaled(imgs.topright, draw_x + 16 * width - 8, top_y, 0, 8 / corner_w, 3 / corner_h)
              GraphicsUtil.drawGfxScaled(imgs.botleft, draw_x, draw_y + 13, 0, 8 / corner_w, 3 / corner_h)
              GraphicsUtil.drawGfxScaled(imgs.botright, draw_x + 16 * width - 8, draw_y + 13, 0, 8 / corner_w, 3 / corner_h)
            end
          end
          if panel.state == "matched" then
            local flash_time = panel.initial_time - panel.timer
            if flash_time >= self.levelData.frameConstants.FLASH then
              if panel.timer > panel.pop_time then
                if panel.metal then
                  GraphicsUtil.drawGfxScaled(shockGarbageImages.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h)
                  GraphicsUtil.drawGfxScaled(shockGarbageImages.right, draw_x + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h)
                else
                  local popped_w, popped_h = imgs.pop:getDimensions()
                  GraphicsUtil.drawGfxScaled(imgs.pop, draw_x, draw_y, 0, 16 / popped_w, 16 / popped_h)
                end
              elseif panel.y_offset == -1 then
                local p_w, p_h = panels[self.panels_dir].images.classic[panel.color][1]:getDimensions()
                GraphicsUtil.drawGfxScaled(panels[self.panels_dir].images.classic[panel.color][1], draw_x, draw_y, 0, 16 / p_w, 16 / p_h)
              end
            elseif flash_time % 2 == 1 then
              if panel.metal then
                GraphicsUtil.drawGfxScaled(shockGarbageImages.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h)
                GraphicsUtil.drawGfxScaled(shockGarbageImages.right, draw_x + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h)
              else
                local popped_w, popped_h = imgs.pop:getDimensions()
                GraphicsUtil.drawGfxScaled(imgs.pop, draw_x, draw_y, 0, 16 / popped_w, 16 / popped_h)
              end
            else
              local flashed_w, flashed_h = imgs.flash:getDimensions()
              GraphicsUtil.drawGfxScaled(imgs.flash, draw_x, draw_y, 0, 16 / flashed_w, 16 / flashed_h)
            end
          end
        else
          if panel.state == "matched" then
            local flash_time = self.levelData.frameConstants.FACE - panel.timer
            if flash_time >= 0 then
              draw_frame = 6
            elseif flash_time % 2 == 1 then
              draw_frame = 1
            else
              draw_frame = 5
            end
          elseif panel.state == "popping" then
            draw_frame = 6
          elseif panel.state == "landing" then
            draw_frame = BOUNCE_TABLE[panel.timer + 1]
          elseif panel.state == "swapping" then
            if panel.isSwappingFromLeft then
              draw_x = draw_x - panel.timer * 4
            else
              draw_x = draw_x + panel.timer * 4
            end
          elseif panel.state == "dead" then
            draw_frame = 6
          elseif panel.state == "dimmed" then
            draw_frame = 7
          elseif panel.fell_from_garbage then
            draw_frame = GARBAGE_BOUNCE_TABLE[panel.fell_from_garbage] or 1
          elseif self.danger_col[col] then
            draw_frame = DANGER_BOUNCE_TABLE[wrap(1, self.danger_timer + 1 + floor((col - 1) / 2), #DANGER_BOUNCE_TABLE)]
          else
            draw_frame = 1
          end
          local panel_w, panel_h = panels[self.panels_dir].images.classic[panel.color][draw_frame]:getDimensions()
          GraphicsUtil.drawGfxScaled(panels[self.panels_dir].images.classic[panel.color][draw_frame], draw_x, draw_y, 0, 16 / panel_w, 16 / panel_h)
        end
      end
    end
  end
end
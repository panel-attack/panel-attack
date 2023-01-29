require("input")
require("util")
local graphicsUtil = require("graphics_util")

local floor = math.floor
local ceil = math.ceil

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
    if card_animation[card.frame] then
      card.frame = card.frame + 1
      if (card_animation[card.frame] == nil) then
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
    if card_animation[card.frame] then
      local draw_x = (self.pos_x) + (card.x - 1) * 16
      local draw_y = (self.pos_y) + (11 - card.y) * 16 + self.displacement - card_animation[card.frame]
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
          qdraw(card.burstAtlas, card.burstParticle, cardfx_x, cardfx_y, 0, 16 / burstFrameDimension, 16 / burstFrameDimension, nil, nil, nil, true)
        end
      end
      -- draw card
      local iconSize = 48 / GFX_SCALE
      local cardImage = themes[config.theme].images.IMG_cards[card.chain][card.n]
      if cardImage == nil then
       cardImage = themes[config.theme].images.IMG_cards[card.chain][0]
      end
      local icon_width, icon_height = cardImage:getDimensions()
      local fade = 1 - math.min(0.5 * ((card.frame-1) / 22), 0.5)
      set_color(1, 1, 1, fade)
      draw(cardImage, draw_x, draw_y, 0, iconSize / icon_width, iconSize / icon_height, true)
      set_color(1, 1, 1, 1)
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
      popfx_animation = popfx_burst_animation
    end
    if characters[self.character].popfx_style == "fade" then
      popfx_animation = popfx_fade_animation
    end
    if popfx_burst_animation[popfx.frame] then
      popfx.frame = popfx.frame + 1
      if (popfx_burst_animation[popfx.frame] == nil) then
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
    local draw_x = (self.pos_x) + (popfx.x - 1) * 16
    local draw_y = (self.pos_y) + (11 - popfx.y) * 16 + self.displacement
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
        burstFrame = popfx_burst_animation[popfx.frame]
        if popfx_burst_animation[popfx.frame] then
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
            qdraw(burstParticle_atlas, burstParticle, positions[1].x, positions[1].y, 0, (16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2, nil, true)
          end
          if big_position ~= 2 then
            qdraw(burstParticle_atlas, burstParticle, positions[2].x, positions[2].y, 0, -(16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2, nil, true)
          end
          if big_position ~= 3 then
            qdraw(burstParticle_atlas, burstParticle, positions[3].x, positions[3].y, 0, (16 / burstFrameDimension) * burstScale, -(16 / burstFrameDimension) * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2, nil, true)
          end
          if big_position ~= 4 then
            qdraw(burstParticle_atlas, burstParticle, positions[4].x, positions[4].y, 0, -(16 / burstFrameDimension) * burstScale, -16 / burstFrameDimension * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2, nil, true)
          end
          -- top and bottom
          if popfx.popsize == "big" or popfx.popsize == "giant" then
            if big_position ~= 5 then
              qdraw(burstParticle_atlas, burstParticle, positions[5].x + 8, positions[5].y, topRot[1], topRot[2], topRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2, nil, true)
            end
            if big_position ~= 6 then
              qdraw(burstParticle_atlas, burstParticle, positions[6].x + 8, positions[6].y, bottomRot[1], bottomRot[2], bottomRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2, nil, true)
            end
          end
          -- left and right
          if popfx.popsize == "giant" then
            if big_position ~= 7 then
              qdraw(burstParticle_atlas, burstParticle, positions[7].x, positions[7].y + 8, leftRot[1], leftRot[2], leftRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2, nil, true)
            end
            if big_position ~= 8 then
              qdraw(burstParticle_atlas, burstParticle, positions[8].x, positions[8].y + 8, rightRot[1], rightRot[2], rightRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2, nil, true)
            end
          end
        --big particle
        --[[
          if popsize ~= "small" then
            qdraw(particle_atlas, popfx.bigParticle, 
            positions[big_position].x, positions[big_position].y, 0, 16/frameDimension, 16/frameDimension, frameDimension/2, frameDimension/2)
          end
        ]]
        end
      end
    end
    if characters[self.character].popfx_style == "fade" or characters[self.character].popfx_style == "fadeburst" then
      if characters[self.character].images["fade"] then
        fadeFrame = popfx_fade_animation[popfx.frame]
        if (fadeFrame ~= nil) then
          fadeParticle:setViewport(fadeFrame * fadeFrameDimension, 0, fadeFrameDimension, fadeFrameDimension, fadeParticle_atlas:getDimensions())
          qdraw(fadeParticle_atlas, fadeParticle, draw_x + 8, draw_y + 8, 0, (32 / fadeFrameDimension) * fadeScale, (32 / fadeFrameDimension) * fadeScale, fadeFrameDimension / 2, fadeFrameDimension / 2, nil, true)
        end
      end
    end
  end
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

-- Renders the player's stack on screen
function Stack.render(self)
  if self.canvas == nil then
    return
  end

  local function frame_mask(x_pos, y_pos)
    love.graphics.setShader(mask_shader)
    love.graphics.setBackgroundColor(1, 1, 1)
    local canvas_w, canvas_h = self.canvas:getDimensions()
    love.graphics.rectangle("fill", 0, 0, canvas_w, canvas_h)
    love.graphics.setBackgroundColor(unpack(global_background_color))
    love.graphics.setShader()
  end

  love.graphics.setCanvas({self.canvas, stencil = true})
  love.graphics.clear()
  love.graphics.stencil(frame_mask, "replace", 1)
  love.graphics.setStencilTest("greater", 0)

  -- draw inside stack's frame canvas
  local portrait_image = "portrait"
  if not (self.which == 1) and characters[self.character].images["portrait2"] then
    portrait_image = "portrait2"
  end

  local portrait_w, portrait_h = characters[self.character].images[portrait_image]:getDimensions()

  -- Draw the portrait (with fade and inversion if needed)
  if self.do_countdown == false then
    self.portraitFade = 0.3
  else
    if self.countdown_CLOCK then
      if self.countdown_CLOCK > 50 and self.countdown_CLOCK < 80 then
        self.portraitFade = ((config.portrait_darkness / 100) / 79) * self.countdown_CLOCK
      end
    elseif self.CLOCK > 200 then
      self.portraitFade = config.portrait_darkness / 100
    end
  end
  if self.which == 1 or portrait_image == "portrait2" then
    draw(characters[self.character].images[portrait_image], 4, 4, 0, 96 / portrait_w, 192 / portrait_h, true)
  else
    draw(characters[self.character].images[portrait_image], 100, 4, 0, (96/portrait_w)*-1, 192/portrait_h, true)
  end
  grectangle_color("fill", 4, 4, 96, 192, 0, 0, 0, self.portraitFade, true)

  local metals
  if self.garbage_target then
    metals = panels[self.garbage_target.panels_dir].images.metals
  else
    metals = panels[self.panels_dir].images.metals
  end
  local metal_w, metal_h = metals.mid:getDimensions()
  local metall_w, metall_h = metals.left:getDimensions()
  local metalr_w, metalr_h = metals.right:getDimensions()

  local shake_idx = #shake_arr - self.shake_time
  local shake = ceil((shake_arr[shake_idx] or 0) * 13)

  -- Draw all the panels
  for row = 0, self.height do
    for col = 1, self.width do
      local panel = self.panels[row][col]
      local draw_x = 4 + (col - 1) * 16
      local draw_y = 4 + (11 - (row)) * 16 + self.displacement - shake
      if panel.color ~= 0 and panel.state ~= "popped" then
        local draw_frame = 1
        if panel.garbage then
          local imgs = {flash = metals.flash}
          if not panel.metal then
            if not self.garbage_target then 
              imgs = characters[self.character].images
            else
              imgs = characters[self.garbage_target.character].images
            end
          end
          if panel.x_offset == 0 and panel.y_offset == 0 then
            -- draw the entire block!
            if panel.metal then
              draw(metals.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h, true)
              draw(metals.right, draw_x + 16 * (panel.width - 1) + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h, true)
              for i = 1, 2 * (panel.width - 1) do
                draw(metals.mid, draw_x + 8 * i, draw_y, 0, 8 / metal_w, 16 / metal_h, true)
              end
            else
              local height, width = panel.height, panel.width
              local top_y = draw_y - (height - 1) * 16
              local use_1 = ((height - (height % 2)) / 2) % 2 == 0
              local filler_w, filler_h = imgs.filler1:getDimensions()
              for i = 0, height - 1 do
                for j = 1, width - 1 do
                  draw((use_1 or height < 3) and imgs.filler1 or imgs.filler2, draw_x + 16 * j - 8, top_y + 16 * i, 0, 16 / filler_w, 16 / filler_h, true)
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
                draw(face, draw_x + 8 * (width - 1), top_y + 16 * ((height - 1) / 2), 0, 16 / face_w, 16 / face_h, true)
              else
                local face_w, face_h = imgs.doubleface:getDimensions()
                draw(imgs.doubleface, draw_x + 8 * (width - 1), top_y + 16 * ((height - 2) / 2), 0, 16 / face_w, 32 / face_h, true)
              end
              local corner_w, corner_h = imgs.topleft:getDimensions()
              local lr_w, lr_h = imgs.left:getDimensions()
              local topbottom_w, topbottom_h = imgs.top:getDimensions()
              draw(imgs.left, draw_x, top_y, 0, 8 / lr_w, (1 / lr_h) * height * 16, true)
              draw(imgs.right, draw_x + 16 * (width - 1) + 8, top_y, 0, 8 / lr_w, (1 / lr_h) * height * 16, true)
              draw(imgs.top, draw_x, top_y, 0, (1 / topbottom_w) * width * 16, 2 / topbottom_h, true)
              draw(imgs.bot, draw_x, draw_y + 14, 0, (1 / topbottom_w) * width * 16, 2 / topbottom_h, true)
              draw(imgs.topleft, draw_x, top_y, 0, 8 / corner_w, 3 / corner_h, true)
              draw(imgs.topright, draw_x + 16 * width - 8, top_y, 0, 8 / corner_w, 3 / corner_h, true)
              draw(imgs.botleft, draw_x, draw_y + 13, 0, 8 / corner_w, 3 / corner_h, true)
              draw(imgs.botright, draw_x + 16 * width - 8, draw_y + 13, 0, 8 / corner_w, 3 / corner_h, true)
            end
          end
          if panel.state == "matched" then
            local flash_time = panel.initial_time - panel.timer
            if flash_time >= self.FRAMECOUNT_FLASH then
              if panel.timer > panel.pop_time then
                if panel.metal then
                  draw(metals.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h, true)
                  draw(metals.right, draw_x + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h, true)
                else
                  local popped_w, popped_h = imgs.pop:getDimensions()
                  draw(imgs.pop, draw_x, draw_y, 0, 16 / popped_w, 16 / popped_h, true)
                end
              elseif panel.y_offset == -1 then
                local p_w, p_h = panels[self.panels_dir].images.classic[panel.color][1]:getDimensions()
                draw(panels[self.panels_dir].images.classic[panel.color][1], draw_x, draw_y, 0, 16 / p_w, 16 / p_h, true)
              end
            elseif flash_time % 2 == 1 then
              if panel.metal then
                draw(metals.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h, true)
                draw(metals.right, draw_x + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h, true)
              else
                local popped_w, popped_h = imgs.pop:getDimensions()
                draw(imgs.pop, draw_x, draw_y, 0, 16 / popped_w, 16 / popped_h, true)
              end
            else
              local flashed_w, flashed_h = imgs.flash:getDimensions()
              draw(imgs.flash, draw_x, draw_y, 0, 16 / flashed_w, 16 / flashed_h, true)
            end
          end
        else
          if panel.state == "matched" then
            local flash_time = self.FRAMECOUNT_MATCH - panel.timer
            if flash_time >= self.FRAMECOUNT_FLASH then
              draw_frame = 6
            elseif flash_time % 2 == 1 then
              draw_frame = 1
            else
              draw_frame = 5
            end
          elseif panel.state == "popping" then
            draw_frame = 6
          elseif panel.state == "landing" then
            draw_frame = bounce_table[panel.timer + 1]
          elseif panel.state == "swapping" then
            if panel.is_swapping_from_left then
              draw_x = draw_x - panel.timer * 4
            else
              draw_x = draw_x + panel.timer * 4
            end
          elseif panel.state == "dead" then
            draw_frame = 6
          elseif panel.state == "dimmed" then
            draw_frame = 7
          elseif panel.fell_from_garbage then
            draw_frame = garbage_bounce_table[panel.fell_from_garbage] or 1
          elseif self.danger_col[col] then
            draw_frame = danger_bounce_table[wrap(1, self.danger_timer + 1 + floor((col - 1) / 2), #danger_bounce_table)]
          else
            draw_frame = 1
          end
          local panel_w, panel_h = panels[self.panels_dir].images.classic[panel.color][draw_frame]:getDimensions()
          draw(panels[self.panels_dir].images.classic[panel.color][draw_frame], draw_x, draw_y, 0, 16 / panel_w, 16 / panel_h, true)
        end
      end
    end
  end

  -- Draw the frames and wall at the bottom
  local frameImage = nil
  local wallImage = nil
  if self.which == 1 then
    frameImage = themes[config.theme].images.IMG_frame1P
    wallImage = themes[config.theme].images.IMG_wall1P
  else
    frameImage = themes[config.theme].images.IMG_frame2P
    wallImage = themes[config.theme].images.IMG_wall2P
  end
  if frameImage then
    graphicsUtil.drawScaledImage(frameImage, 0, 0, 312, 612, true)
  end
  if wallImage then
    graphicsUtil.drawScaledWidthImage(wallImage, 12, (4 - shake + self.height * 16)*GFX_SCALE, 288, true)
  end

  -- Draw the cursor
  if self:game_ended() == false then
    self:render_cursor()
  end

  -- Draw the countdown timer
  if self.do_countdown then
    self:render_countdown()
  end
  -- ends here

  love.graphics.setStencilTest()
  love.graphics.setCanvas(GAME.globalCanvas)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(self.canvas, (self.pos_x - 4) * GFX_SCALE, (self.pos_y - 4) * GFX_SCALE)
  love.graphics.setBlendMode("alpha", "alphamultiply")

  self:draw_popfxs()
  self:draw_cards()

  -- Draw debug graphics if set
  if config.debug_mode then
    local mx, my = GAME:transform_coordinates(love.mouse.getPosition())

    for row = 0, self.height do
      for col = 1, self.width do
        local panel = self.panels[row][col]
        local draw_x = (self.pos_x + (col - 1) * 16) * GFX_SCALE
        local draw_y = (self.pos_y + (11 - (row)) * 16 + self.displacement - shake) * GFX_SCALE

        -- Require hovering over a stack to show details
        if mx >= self.pos_x * GFX_SCALE and mx <= (self.pos_x + self.width * 16) * GFX_SCALE then
          if panel.color ~= 0 and panel.state ~= "popped" then
            gprint(panel.state, draw_x, draw_y, nil, nil, true)
            if panel.match_anyway ~= nil then
              gprint(tostring(panel.match_anyway), draw_x, draw_y + 10, nil, nil, true)
              if panel.debug_tag then
                gprint(tostring(panel.debug_tag), draw_x, draw_y + 20, nil, nil, true)
              end
            end
            if panel.chaining then
              gprint("chaining", draw_x, draw_y + 30, nil, nil, true)
            end
          end
        end

        if mx >= draw_x and mx < draw_x + 16 * GFX_SCALE and my >= draw_y and my < draw_y + 16 * GFX_SCALE then
          local str = loc("pl_panel_info", row, col)
          for k, v in pairsSortedByKeys(panel) do
            str = str .. "\n" .. k .. ": " .. tostring(v)
          end

          local drawX = 30
          local drawY = 10

          grectangle_color("fill", (drawX - 5) / GFX_SCALE, (drawY - 5) / GFX_SCALE, 100/GFX_SCALE, 100/GFX_SCALE, 0, 0, 0, 0.5, true)
          gprintf({str, drawX, drawY, drawDirectly = true})
        end
      end
    end
  end

  local main_infos_screen_pos = {x = 375 + (464) / 2, y = 118}

  local function drawMoveCount()
    -- draw outside of stack's frame canvas
    if self.match.mode == "puzzle" then
      --gprint(loc("pl_moves", self.puzzle.remaining_moves), self.score_x, self.score_y)
      draw_label(themes[config.theme].images.IMG_moves, (self.origin_x + themes[config.theme].moveLabel_Pos[1]) / GFX_SCALE, (self.pos_y + themes[config.theme].moveLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].moveLabel_Scale, nil, true)
      if self.puzzle.puzzleType == "moves" then
        -- display moves left
        GraphicsUtil.draw_number(self.puzzle.remaining_moves, themes[config.theme].images.IMG_number_atlas_1P, self.move_quads, self.score_x + themes[config.theme].move_Pos[1], self.score_y + themes[config.theme].move_Pos[2], themes[config.theme].move_Scale, "center", true)
      else
        -- display total amount of moves
        GraphicsUtil.draw_number(math.abs(self.puzzle.remaining_moves), themes[config.theme].images.IMG_number_atlas_1P, self.move_quads, self.score_x + themes[config.theme].move_Pos[1], self.score_y + themes[config.theme].move_Pos[2], themes[config.theme].move_Scale, "center", true)
      end
    end
  end

  local function drawScore()
    --gprint(loc("pl_score", self.score), self.score_x, self.score_y-40)
    draw_label(themes[config.theme].images["IMG_score" .. self.id], self.origin_x + (themes[config.theme].scoreLabel_Pos[1] * self.mirror_x), self.pos_y + themes[config.theme].scoreLabel_Pos[2], 0, themes[config.theme].scoreLabel_Scale, self.multiplication, true)
    GraphicsUtil.draw_number(self.score, themes[config.theme].images["IMG_number_atlas" .. self.id], self.score_quads, (self.origin_x + (themes[config.theme].score_Pos[1] * self.mirror_x)) * GFX_SCALE, (self.pos_y + themes[config.theme].score_Pos[2]) * GFX_SCALE, themes[config.theme].score_Scale, "center", true)
  end

  local function drawSpeed()
    --gprint(loc("pl_speed", self.speed), self.score_x, self.score_y+45)
    draw_label(themes[config.theme].images["IMG_speed" .. self.id], self.origin_x + themes[config.theme].speedLabel_Pos[1] * self.mirror_x, (self.pos_y + themes[config.theme].speedLabel_Pos[2]), 0, themes[config.theme].speedLabel_Scale, self.multiplication, true)
    GraphicsUtil.draw_number(self.speed, themes[config.theme].images["IMG_number_atlas" .. self.id], self.speed_quads, (self.origin_x + (themes[config.theme].speed_Pos[1] * self.mirror_x)) * GFX_SCALE, (self.pos_y + themes[config.theme].speed_Pos[2]) * GFX_SCALE, themes[config.theme].speed_Scale, "center", true)
  end

  local function drawTimer()
    -- Draw the timer for time attack
    if self.match.mode == "time" then
      local time_left = time_attack_time - ((self.game_stopwatch or (time_attack_time * 60)) / 60) -- time left in seconds
      if time_left < 0 then
        time_left = 0
      end
      local mins = math.floor(time_left / 60)
      local secs = math.ceil(time_left % 60)
      if secs == 60 then
        secs = 0
        mins = mins + 1
      end
      --gprint(loc("pl_time", string.format("%01d:%02d",mins,secs)), self.score_x, self.score_y+60)
      draw_label(themes[config.theme].images.IMG_time, (main_infos_screen_pos.x + themes[config.theme].timeLabel_Pos[1]) / GFX_SCALE, (main_infos_screen_pos.y + themes[config.theme].timeLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].timeLabel_Scale, nil, true)
      GraphicsUtil.draw_time(string.format("%01d:%02d", mins, secs), self.time_quads, main_infos_screen_pos.x + themes[config.theme].time_Pos[1], main_infos_screen_pos.y + themes[config.theme].time_Pos[2], themes[config.theme].time_Scale, true)
    elseif self.match.mode == "puzzle" then
      -- puzzles don't have a timer...yet?
    else
      -- Draw the time for non time attack modes
      if self and self.which == 1 and self.game_stopwatch and tonumber(self.game_stopwatch) then
        --gprint(frames_to_time_string(self.game_stopwatch, self.match.mode == "endless"), main_infos_screen_pos.x+10, main_infos_screen_pos.y+6)
        draw_label(themes[config.theme].images.IMG_time, (main_infos_screen_pos.x + themes[config.theme].timeLabel_Pos[1]) / GFX_SCALE, (main_infos_screen_pos.y + themes[config.theme].timeLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].timeLabel_Scale, nil, true)
        GraphicsUtil.draw_time(frames_to_time_string(self.game_stopwatch, self.match.mode == "endless"), self.time_quads, main_infos_screen_pos.x + themes[config.theme].time_Pos[1], main_infos_screen_pos.y + themes[config.theme].time_Pos[2], themes[config.theme].time_Scale, true)
      end
    end
  end

  local function drawLevel()
    if self.level then
      --gprint(loc("pl_level", self.level), self.score_x, self.score_y+70)
      draw_label(themes[config.theme].images["IMG_level" .. self.id], self.origin_x + themes[config.theme].levelLabel_Pos[1] * self.mirror_x, self.pos_y + themes[config.theme].levelLabel_Pos[2], 0, themes[config.theme].levelLabel_Scale, self.multiplication, true)
  
      level_atlas = themes[config.theme].images["IMG_levelNumber_atlas" .. self.id]
      self.level_quad:setViewport(tonumber(self.level - 1) * (level_atlas:getWidth() / 11), 0, level_atlas:getWidth() / 11, level_atlas:getHeight(), level_atlas:getDimensions())
      qdraw(level_atlas, self.level_quad, (self.origin_x + themes[config.theme].level_Pos[1] * self.mirror_x), (self.pos_y + themes[config.theme].level_Pos[2]), 0, (28 / themes[config.theme].images["levelNumberWidth" .. self.id] * themes[config.theme].level_Scale) / GFX_SCALE, (26 / themes[config.theme].images["levelNumberHeight" .. self.id] * themes[config.theme].level_Scale / GFX_SCALE), 0, 0, self.multiplication, true)
    end
  end

  local function drawMultibar()
    -- Draw the stop time and healthbars
    --gprint(loc("pl_health", self.health), self.score_x, self.score_y-40)
    --(self.pos_x-4)*GFX_SCALE, (self.pos_y-4)*GFX_SCALE
    --if self.healthQuad == nil then local self.healthQuad = GraphicsUtil:newRecycledQuad(0, 0, themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight(),
    --  themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight()) end
    local stop_time = self.stop_time
    local shake_time = self.shake_time

    -- before the first move, display the stop time from the puzzle, not the stack
    if self.match.mode == "puzzle" and self.puzzle.puzzleType == "clear" and self.puzzle.moves == self.puzzle.remaining_moves then
      stop_time = self.puzzle.stop_time
      shake_time = self.puzzle.shake_time
    end

    -- If we have a healthbar frame draw it.
    -- (It may be the absolute version or the normal version)
    if themes[config.theme].images["IMG_healthbar_frame" .. self.id] then
      draw_label(themes[config.theme].images["IMG_healthbar_frame" .. self.id], self.origin_x + themes[config.theme].healthbar_frame_Pos[1] * self.mirror_x, self.pos_y + themes[config.theme].healthbar_frame_Pos[2], 0, themes[config.theme].healthbar_frame_Scale, self.multiplication, true)
    end

    if not themes[config.theme].multibar_is_absolute then
      -- Healthbar
      local healthbar = self.health * (themes[config.theme].images.IMG_healthbar:getHeight() / self.max_health)
      self.healthQuad:setViewport(0, themes[config.theme].images.IMG_healthbar:getHeight() - healthbar, themes[config.theme].images.IMG_healthbar:getWidth(), healthbar)
      qdraw(themes[config.theme].images.IMG_healthbar, self.healthQuad, self.origin_x + themes[config.theme].healthbar_Pos[1] * self.mirror_x, (self.pos_y + themes[config.theme].healthbar_Pos[2]) + (themes[config.theme].images.IMG_healthbar:getHeight() - healthbar), themes[config.theme].healthbar_Rotate, themes[config.theme].healthbar_Scale, themes[config.theme].healthbar_Scale, 0, 0, self.multiplication, true)
    end

    --gprint(loc("pl_stop", stop_time), self.score_x, self.score_y+300)
    --gprint(loc("pl_shake", shake_time), self.score_x, self.score_y+320)
    --gprint(loc("pl_pre_stop", self.pre_stop_time), self.score_x, self.score_y+340)

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

    -- Scaled Multibar
    if not themes[config.theme].multibar_is_absolute then
      local multi_shake_bar, multi_stop_bar, multi_prestop_bar = 0, 0, 0
      if self.maxShake > 0 and shake_time >= self.pre_stop_time + stop_time then
        multi_shake_bar = shake_time * (themes[config.theme].images.IMG_multibar_shake_bar:getHeight() / self.maxShake) * 3
      end
      if self.maxStop > 0 and shake_time < self.pre_stop_time + stop_time then
        multi_stop_bar = stop_time * (themes[config.theme].images.IMG_multibar_stop_bar:getHeight() / self.maxStop) * 1.5
      end
      if self.maxPrestop > 0 and shake_time < self.pre_stop_time + stop_time then
        multi_prestop_bar = self.pre_stop_time * (themes[config.theme].images.IMG_multibar_prestop_bar:getHeight() / self.maxPrestop) * 1.5
      end
      self.multi_shakeQuad:setViewport(0, themes[config.theme].images.IMG_multibar_shake_bar:getHeight() - multi_shake_bar, themes[config.theme].images.IMG_multibar_shake_bar:getWidth(), multi_shake_bar)
      self.multi_stopQuad:setViewport(0, themes[config.theme].images.IMG_multibar_stop_bar:getHeight() - multi_stop_bar, themes[config.theme].images.IMG_multibar_stop_bar:getWidth(), multi_stop_bar)
      self.multi_prestopQuad:setViewport(0, themes[config.theme].images.IMG_multibar_prestop_bar:getHeight() - multi_prestop_bar, themes[config.theme].images.IMG_multibar_prestop_bar:getWidth(), multi_prestop_bar)

      --Shake
      qdraw(themes[config.theme].images.IMG_multibar_shake_bar, self.multi_shakeQuad, self.origin_x + themes[config.theme].multibar_Pos[1] * self.mirror_x, ((self.pos_y + themes[config.theme].multibar_Pos[2]) + ((themes[config.theme].images.IMG_multibar_shake_bar:getHeight() - multi_shake_bar) / GFX_SCALE)), 0, themes[config.theme].multibar_Scale / GFX_SCALE, themes[config.theme].multibar_Scale / GFX_SCALE, 0, 0, self.multiplication, true)
      --Stop
      qdraw(themes[config.theme].images.IMG_multibar_stop_bar, self.multi_stopQuad, self.origin_x + themes[config.theme].multibar_Pos[1] * self.mirror_x, (((self.pos_y - (multi_shake_bar / GFX_SCALE)) + themes[config.theme].multibar_Pos[2]) + ((themes[config.theme].images.IMG_multibar_stop_bar:getHeight() - multi_stop_bar) / GFX_SCALE)), 0, themes[config.theme].multibar_Scale / GFX_SCALE, themes[config.theme].multibar_Scale / GFX_SCALE, 0, 0, self.multiplication, true)
      -- Prestop
      qdraw(themes[config.theme].images.IMG_multibar_prestop_bar, self.multi_prestopQuad, self.origin_x + (themes[config.theme].multibar_Pos[1] * self.mirror_x), (((self.pos_y - (multi_shake_bar / GFX_SCALE + multi_stop_bar / GFX_SCALE)) + themes[config.theme].multibar_Pos[2]) + ((themes[config.theme].images.IMG_multibar_prestop_bar:getHeight() - multi_prestop_bar) / GFX_SCALE)), 0, themes[config.theme].multibar_Scale / GFX_SCALE, themes[config.theme].multibar_Scale / GFX_SCALE, 0, 0, self.multiplication, true)
    else -- Absolute Multibar
      -- Healthbar
      local iconX = (self.origin_x + themes[config.theme].multibar_Pos[1] * self.mirror_x) * GFX_SCALE
      local iconY = 709
      local multiBarMaxHeight = 590
      local multiBarFrameScale = 3

      local healthBar = self.health * multiBarFrameScale
      local shakeTimeBar, stopTimeBar, preStopBar = 0, 0, 0
      if self.maxShake > 0 and shake_time >= self.pre_stop_time + stop_time then
        shakeTimeBar = math.min(shake_time * multiBarFrameScale, multiBarMaxHeight - healthBar)
      end
      if self.maxStop > 0 and shake_time < self.pre_stop_time + stop_time then
        stopTimeBar = math.min(stop_time * multiBarFrameScale, multiBarMaxHeight - shakeTimeBar - healthBar)
      end
      if self.maxPrestop > 0 and shake_time < self.pre_stop_time + stop_time then
        preStopBar = math.min(self.pre_stop_time * multiBarFrameScale, multiBarMaxHeight - stopTimeBar - shakeTimeBar - healthBar)
      end

      local desiredWidth, _ = themes[config.theme].images.IMG_multibar_shake_bar:getDimensions()
      local iconXScale, iconYScale, icon_width, icon_height
      icon_width, icon_height = themes[config.theme].images.IMG_healthbar:getDimensions()
      iconXScale = (desiredWidth / GFX_SCALE) / icon_width * self.mirror_x
      iconYScale = -(healthBar / icon_height) / GFX_SCALE
      draw(themes[config.theme].images.IMG_healthbar, iconX / GFX_SCALE, iconY / GFX_SCALE, 0, iconXScale, iconYScale, true)

      iconY = iconY - healthBar

      --Shake
      icon_width, icon_height = themes[config.theme].images.IMG_multibar_shake_bar:getDimensions()
      iconXScale = (desiredWidth / GFX_SCALE) / icon_width * self.mirror_x
      iconYScale = -(shakeTimeBar / icon_height) / GFX_SCALE
      draw(themes[config.theme].images.IMG_multibar_shake_bar, iconX / GFX_SCALE, iconY / GFX_SCALE, 0, iconXScale, iconYScale, true)

      --Stop
      icon_width, icon_height = themes[config.theme].images.IMG_multibar_stop_bar:getDimensions()
      iconXScale = (desiredWidth / GFX_SCALE) / icon_width * self.mirror_x
      iconYScale = -(stopTimeBar / icon_height) / GFX_SCALE
      draw(themes[config.theme].images.IMG_multibar_stop_bar, iconX / GFX_SCALE, iconY / GFX_SCALE, 0, iconXScale, iconYScale, true)

      -- Prestop
      icon_width, icon_height = themes[config.theme].images.IMG_multibar_prestop_bar:getDimensions()
      iconXScale = (desiredWidth / GFX_SCALE) / icon_width * self.mirror_x
      iconYScale = -(preStopBar / icon_height) / GFX_SCALE
      iconY = iconY - math.max(shakeTimeBar, stopTimeBar)
      draw(themes[config.theme].images.IMG_multibar_prestop_bar, iconX / GFX_SCALE, iconY / GFX_SCALE, 0, iconXScale, iconYScale, true)
    end

    if config.debug_mode and self.danger then
      gprint({"danger", self.score_x, self.score_y + 135, drawDirectly = true})
    end
    if config.debug_mode and self.danger_music then
      gprint({"danger music", self.score_x, self.score_y + 150, drawDirectly = true})
    end
    if config.debug_mode then
      gprint({loc("pl_cleared", (self.panels_cleared or 0)), self.score_x, self.score_y + 165, drawDirectly = true})
    end
    if config.debug_mode then
      gprint({loc("pl_metal", (self.metal_panels_queued or 0)), self.score_x, self.score_y + 180, drawDirectly = true})
    end
    if config.debug_mode and (self.input_state or self.taunt_up or self.taunt_down) then
      local iraise, iswap, iup, idown, ileft, iright = unpack(base64decode[self.input_state])
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
      gprint({inputs_to_print, self.score_x, self.score_y + 195, drawDirectly = true})
    end
  end

  local function drawMatchType()
    if match_type ~= "" then
      local matchImage = nil
      --gprint(match_type, main_infos_screen_pos.x, main_infos_screen_pos.y-50)
      if match_type == "Ranked" then
        matchImage = themes[config.theme].images.IMG_ranked
      end
      if match_type == "Casual" then
        matchImage = themes[config.theme].images.IMG_casual
      end
      if matchImage then
        draw_label(matchImage, (main_infos_screen_pos.x + themes[config.theme].matchtypeLabel_Pos[1]) / GFX_SCALE, (main_infos_screen_pos.y + themes[config.theme].matchtypeLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].matchtypeLabel_Scale, nil, true)
      end
    end
  end

  local function drawCommunityMessage()
    -- Draw the community message
    if not config.debug_mode then
      gprintf({join_community_msg or "", 0, main_infos_screen_pos.y + 550, canvas_width, "center", drawDirectly = true})
    end
  end

  local function drawAnalyticData()
    if not config.enable_analytics or not self.drawsAnalytics then
      return
    end
  
    local analytic = self.analytic
    local x = self.score_x - 512
    if self.which == 2 then
      x = x + 990
    end
    local y = self.score_y - 81
  
    local backgroundPadding = 6
    local iconToTextSpacing = 30
    local nextIconIncrement = 30
    local column2Distance = 70
  
    local fontIncrement = 8
    local iconSize = 8
    local icon_width
    local icon_height
  
    -- Background
    grectangle_color("fill", x / GFX_SCALE - backgroundPadding, y / GFX_SCALE - backgroundPadding, 160/GFX_SCALE, 600/GFX_SCALE, 0, 0, 0, 0.5, true)

    -- Panels cleared
    icon_width, icon_height = panels[self.panels_dir].images.classic[1][6]:getDimensions()
    draw(panels[self.panels_dir].images.classic[1][6], x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height, true)
    gprintf(analytic.data.destroyed_panels, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement, true)

    y = y + nextIconIncrement

    -- Garbage sent
    icon_width, icon_height = characters[self.character].images.face:getDimensions()
    draw(characters[self.character].images.face, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height, true)
    gprintf(analytic.data.sent_garbage_lines, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement, true)

    y = y + nextIconIncrement

    -- GPM
    if analytic.lastGPM == 0 or math.fmod(self.CLOCK, 60) < self.max_runs_per_frame then
      if self.CLOCK > 0 and (analytic.data.sent_garbage_lines > 0) then
        local garbagePerMinute = analytic.data.sent_garbage_lines / (self.CLOCK / 60 / 60)
        analytic.lastGPM = string.format("%0.1f", round(garbagePerMinute, 1))
      end
    end
    icon_width, icon_height = themes[config.theme].images.IMG_gpm:getDimensions()
    draw(themes[config.theme].images.IMG_gpm, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height, true)
    gprintf(analytic.lastGPM .. "/m", x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement, true)

    y = y + nextIconIncrement

    -- Moves
    icon_width, icon_height = themes[config.theme].images.IMG_cursorCount:getDimensions()
    draw(themes[config.theme].images.IMG_cursorCount, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height, true)
    gprintf(analytic.data.move_count, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement, true)
  
    y = y + nextIconIncrement
  
    -- Swaps
    if themes[config.theme].images.IMG_swap then
      icon_width, icon_height = themes[config.theme].images.IMG_swap:getDimensions()
      draw(themes[config.theme].images.IMG_swap, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height, true)
    end
    gprintf(analytic.data.swap_count, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement, true)
  
    y = y + nextIconIncrement
  
    -- APM
    if analytic.lastAPM == 0 or math.fmod(self.CLOCK, 60) < self.max_runs_per_frame then
      if self.CLOCK > 0 and (analytic.data.swap_count + analytic.data.move_count > 0) then
        local actionsPerMinute = (analytic.data.swap_count + analytic.data.move_count) / (self.CLOCK / 60 / 60)
        analytic.lastAPM = string.format("%0.0f", round(actionsPerMinute, 0))
      end
    end
    if themes[config.theme].images.IMG_apm then
      icon_width, icon_height = themes[config.theme].images.IMG_apm:getDimensions()
      draw(themes[config.theme].images.IMG_apm, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height, true)
    end
    gprintf(analytic.lastAPM .. "/m", x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement, true)
  
    y = y + nextIconIncrement
  
    local yCombo = y
  
    -- Clean up the chain data so we only show chains up to the highest chain the user has done
    local chainData = {}
    local chain_above_limit = analytic:compute_above_chain_card_limit()
  
    for i = 2, themes[config.theme].chainCardLimit, 1 do
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
    for i = 2, themes[config.theme].chainCardLimit + 1 do
      local chain_amount = chainData[i]
      if chain_amount and chain_amount > 0 then
        local cardImage = themes[config.theme].images.IMG_cards[true][i]
        if cardImage == nil then
          cardImage = themes[config.theme].images.IMG_cards[true][0]
        end
        icon_width, icon_height = cardImage:getDimensions()
        draw(cardImage, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height, true)
        gprintf(chain_amount, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement, true)
        y = y + nextIconIncrement
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
        icon_width, icon_height = themes[config.theme].images.IMG_cards[false][i]:getDimensions()
        draw(themes[config.theme].images.IMG_cards[false][i], xCombo / GFX_SCALE, yCombo / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height, true)
        gprintf(combo_amount, xCombo + iconToTextSpacing, yCombo + 0, canvas_width, "left", nil, 1, fontIncrement, true)
        yCombo = yCombo + nextIconIncrement
      end
    end
  end

  drawMoveCount()
  -- Draw the "extra" game info
  if config.show_ingame_infos then
    if self.match.mode ~= "puzzle" then
      drawScore()
      drawSpeed()
    end
    drawMultibar()
  end

  drawTimer()
  drawLevel()
  drawMatchType()
  drawCommunityMessage()
  drawAnalyticData()
end

-- Calculates the proper dimensions to not stretch the game for various sizes
function scale_letterbox(width, height, w_ratio, h_ratio)
  if height / h_ratio > width / w_ratio then
    local scaled_height = h_ratio * width / w_ratio
    return 0, (height - scaled_height) / 2, width, scaled_height
  end
  local scaled_width = w_ratio * height / h_ratio
  return (width - scaled_width) / 2, 0, scaled_width, height
end

-- Draw the stacks cursor
function Stack.render_cursor(self)
  local cursorImage = themes[config.theme].images.IMG_cursor[(floor(self.CLOCK / 16) % 2) + 1]
  local shake_idx = #shake_arr - self.shake_time
  local shake = ceil((shake_arr[shake_idx] or 0) * 13)
  local scale_x = 40 / cursorImage:getWidth()
  local scale_y = 24 / cursorImage:getHeight()

  if self.countdown_timer then
    if self.CLOCK % 2 == 0 then
      draw(themes[config.theme].images.IMG_cursor[1], (self.cur_col - 1) * 16, (11 - (self.cur_row)) * 16 + self.displacement - shake, 0, scale_x, scale_y, true)
    end
  else
    draw(cursorImage, (self.cur_col - 1) * 16, (11 - (self.cur_row)) * 16 + self.displacement - shake, 0, scale_x, scale_y, true)
  end
end

-- Draw the stacks countdown timer
function Stack.render_countdown(self)
  if self.do_countdown and self.countdown_CLOCK then
    local ready_x = 16
    local initial_ready_y = 4
    local ready_y_drop_speed = 6
    local countdown_x = 44
    local countdown_y = 68
    if self.countdown_CLOCK <= 8 then
      local ready_y = initial_ready_y + (self.CLOCK - 1) * ready_y_drop_speed
      draw(themes[config.theme].images.IMG_ready, ready_x, ready_y, true)
      if self.countdown_CLOCK == 8 then
        self.ready_y = ready_y
      end
    elseif self.countdown_CLOCK >= 9 and self.countdown_timer and self.countdown_timer > 0 then
      if self.countdown_timer >= 100 then
        draw(themes[config.theme].images.IMG_ready, ready_x, self.ready_y or initial_ready_y + 8 * 6, true)
      end
      local IMG_number_to_draw = themes[config.theme].images.IMG_numbers[math.ceil(self.countdown_timer / 60)]
      if IMG_number_to_draw then
        draw(IMG_number_to_draw, countdown_x, countdown_y, true)
      end
    end
  end
end

-- Draw the pause menu
function draw_pause()
  if not GAME.renderDuringPause then
    local image = themes[config.theme].images.pause
    local scale = canvas_width / math.max(image:getWidth(), image:getHeight()) -- keep image ratio
    menu_drawf(image, canvas_width / 2, canvas_height / 2, "center", "center", 0, scale, scale)
  end
  gprintf(loc("pause"), 0, 330, canvas_width, "center", nil, 1, large_font)
  gprintf(loc("pl_pause_help"), 0, 360, canvas_width, "center", nil, 1)
end

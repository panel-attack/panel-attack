require("input")
require("util")

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
          card.burstParticle:release()
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
          qdraw(card.burstAtlas, card.burstParticle, cardfx_x, cardfx_y, 0, 16 / burstFrameDimension, 16 / burstFrameDimension)
        end
      end
      -- draw card
      local iconSize = 48 / GFX_SCALE
      local cardImage = themes[config.theme].images.IMG_cards[card.chain][card.n]
      local icon_width, icon_height = cardImage:getDimensions()
      draw(cardImage, draw_x, draw_y, 0, iconSize / icon_width, iconSize / icon_height)
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
          popfx.burstParticle:release()
        end
        if characters[self.character].images["fade"] then
          popfx.fadeParticle:release()
        end
        if characters[self.character].images["burst"] then
          popfx.bigParticle:release()
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
            qdraw(burstParticle_atlas, burstParticle, positions[1].x, positions[1].y, 0, (16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
          end
          if big_position ~= 2 then
            qdraw(burstParticle_atlas, burstParticle, positions[2].x, positions[2].y, 0, -(16 / burstFrameDimension) * burstScale, (16 / burstFrameDimension) * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
          end
          if big_position ~= 3 then
            qdraw(burstParticle_atlas, burstParticle, positions[3].x, positions[3].y, 0, (16 / burstFrameDimension) * burstScale, -(16 / burstFrameDimension) * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
          end
          if big_position ~= 4 then
            qdraw(burstParticle_atlas, burstParticle, positions[4].x, positions[4].y, 0, -(16 / burstFrameDimension) * burstScale, -16 / burstFrameDimension * burstScale, (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
          end
          -- top and bottom
          if popfx.popsize == "big" or popfx.popsize == "giant" then
            if big_position ~= 5 then
              qdraw(burstParticle_atlas, burstParticle, positions[5].x + 8, positions[5].y, topRot[1], topRot[2], topRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
            end
            if big_position ~= 6 then
              qdraw(burstParticle_atlas, burstParticle, positions[6].x + 8, positions[6].y, bottomRot[1], bottomRot[2], bottomRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
            end
          end
          -- left and right
          if popfx.popsize == "giant" then
            if big_position ~= 7 then
              qdraw(burstParticle_atlas, burstParticle, positions[7].x, positions[7].y + 8, leftRot[1], leftRot[2], leftRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
            end
            if big_position ~= 8 then
              qdraw(burstParticle_atlas, burstParticle, positions[8].x, positions[8].y + 8, rightRot[1], rightRot[2], rightRot[3], (burstFrameDimension * burstScale) / 2, (burstFrameDimension * burstScale) / 2)
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
          qdraw(fadeParticle_atlas, fadeParticle, draw_x + 8, draw_y + 8, 0, (32 / fadeFrameDimension) * fadeScale, (32 / fadeFrameDimension) * fadeScale, fadeFrameDimension / 2, fadeFrameDimension / 2)
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

  gfx_q:push({love.graphics.setCanvas, {{self.canvas, stencil = true}}})
  gfx_q:push({love.graphics.clear, {}})
  gfx_q:push({love.graphics.stencil, {frame_mask, "replace", 1}})
  gfx_q:push({love.graphics.setStencilTest, {"greater", 0}})

  time_quads = {}
  move_quads = {}
  score_quads = {}
  speed_quads = {}
  level_quad = love.graphics.newQuad(0, 0, themes[config.theme].images["IMG_levelNumber_atlas" .. self.id]:getWidth() / 11, themes[config.theme].images["IMG_levelNumber_atlas" .. self.id]:getHeight(), themes[config.theme].images["IMG_levelNumber_atlas" .. self.id]:getDimensions())
  win_quads = {}
  healthQuad = love.graphics.newQuad(0, 0, themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight(), themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight())
  prestopQuad = love.graphics.newQuad(0, 0, themes[config.theme].images.IMG_prestop_bar:getWidth(), themes[config.theme].images.IMG_prestop_bar:getHeight(), themes[config.theme].images.IMG_prestop_bar:getWidth(), themes[config.theme].images.IMG_prestop_bar:getHeight())
  stopQuad = love.graphics.newQuad(0, 0, themes[config.theme].images.IMG_stop_bar:getWidth(), themes[config.theme].images.IMG_stop_bar:getHeight(), themes[config.theme].images.IMG_stop_bar:getWidth(), themes[config.theme].images.IMG_stop_bar:getHeight())
  shakeQuad = love.graphics.newQuad(0, 0, themes[config.theme].images.IMG_shake_bar:getWidth(), themes[config.theme].images.IMG_shake_bar:getHeight(), themes[config.theme].images.IMG_shake_bar:getWidth(), themes[config.theme].images.IMG_shake_bar:getHeight())
  prestop_quads = {}
  stop_quads = {}
  shake_quads = {}
  multi_prestopQuad = love.graphics.newQuad(0, 0, themes[config.theme].images.IMG_multibar_prestop_bar:getWidth(), themes[config.theme].images.IMG_multibar_prestop_bar:getHeight(), themes[config.theme].images.IMG_multibar_prestop_bar:getWidth(), themes[config.theme].images.IMG_multibar_prestop_bar:getHeight())
  multi_stopQuad = love.graphics.newQuad(0, 0, themes[config.theme].images.IMG_multibar_stop_bar:getWidth(), themes[config.theme].images.IMG_multibar_stop_bar:getHeight(), themes[config.theme].images.IMG_multibar_stop_bar:getWidth(), themes[config.theme].images.IMG_multibar_stop_bar:getHeight())
  multi_shakeQuad = love.graphics.newQuad(0, 0, themes[config.theme].images.IMG_multibar_shake_bar:getWidth(), themes[config.theme].images.IMG_multibar_shake_bar:getHeight(), themes[config.theme].images.IMG_multibar_shake_bar:getWidth(), themes[config.theme].images.IMG_multibar_shake_bar:getHeight())

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
    draw(characters[self.character].images[portrait_image], 4, 4, 0, 96 / portrait_w, 192 / portrait_h)
  else
    draw(characters[self.character].images[portrait_image], 100, 4, 0, (96/portrait_w)*-1, 192/portrait_h)
  end
  grectangle_color("fill", 4, 4, 96, 192, 0, 0, 0, self.portraitFade)

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
            imgs = characters[self.garbage_target.character].images
          end
          if panel.x_offset == 0 and panel.y_offset == 0 then
            -- draw the entire block!
            if panel.metal then
              draw(metals.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h)
              draw(metals.right, draw_x + 16 * (panel.width - 1) + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h)
              for i = 1, 2 * (panel.width - 1) do
                draw(metals.mid, draw_x + 8 * i, draw_y, 0, 8 / metal_w, 16 / metal_h)
              end
            else
              local height, width = panel.height, panel.width
              local top_y = draw_y - (height - 1) * 16
              local use_1 = ((height - (height % 2)) / 2) % 2 == 0
              local filler_w, filler_h = imgs.filler1:getDimensions()
              for i = 0, height - 1 do
                for j = 1, width - 1 do
                  draw((use_1 or height < 3) and imgs.filler1 or imgs.filler2, draw_x + 16 * j - 8, top_y + 16 * i, 0, 16 / filler_w, 16 / filler_h)
                  use_1 = not use_1
                end
              end
              if height % 2 == 1 then
                local face_w, face_h = imgs.face:getDimensions()
                draw(imgs.face, draw_x + 8 * (width - 1), top_y + 16 * ((height - 1) / 2), 0, 16 / face_w, 16 / face_h)
              else
                local face_w, face_h = imgs.doubleface:getDimensions()
                draw(imgs.doubleface, draw_x + 8 * (width - 1), top_y + 16 * ((height - 2) / 2), 0, 16 / face_w, 32 / face_h)
              end
              local corner_w, corner_h = imgs.topleft:getDimensions()
              local lr_w, lr_h = imgs.left:getDimensions()
              local topbottom_w, topbottom_h = imgs.top:getDimensions()
              draw(imgs.left, draw_x, top_y, 0, 8 / lr_w, (1 / lr_h) * height * 16)
              draw(imgs.right, draw_x + 16 * (width - 1) + 8, top_y, 0, 8 / lr_w, (1 / lr_h) * height * 16)
              draw(imgs.top, draw_x, top_y, 0, (1 / topbottom_w) * width * 16, 2 / topbottom_h)
              draw(imgs.bot, draw_x, draw_y + 14, 0, (1 / topbottom_w) * width * 16, 2 / topbottom_h)
              draw(imgs.topleft, draw_x, top_y, 0, 8 / corner_w, 3 / corner_h)
              draw(imgs.topright, draw_x + 16 * width - 8, top_y, 0, 8 / corner_w, 3 / corner_h)
              draw(imgs.botleft, draw_x, draw_y + 13, 0, 8 / corner_w, 3 / corner_h)
              draw(imgs.botright, draw_x + 16 * width - 8, draw_y + 13, 0, 8 / corner_w, 3 / corner_h)
            end
          end
          if panel.state == "matched" then
            local flash_time = panel.initial_time - panel.timer
            if flash_time >= self.FRAMECOUNT_FLASH then
              if panel.timer > panel.pop_time then
                if panel.metal then
                  draw(metals.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h)
                  draw(metals.right, draw_x + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h)
                else
                  local popped_w, popped_h = imgs.pop:getDimensions()
                  draw(imgs.pop, draw_x, draw_y, 0, 16 / popped_w, 16 / popped_h)
                end
              elseif panel.y_offset == -1 then
                local p_w, p_h = panels[self.panels_dir].images.classic[panel.color][1]:getDimensions()
                draw(panels[self.panels_dir].images.classic[panel.color][1], draw_x, draw_y, 0, 16 / p_w, 16 / p_h)
              end
            elseif flash_time % 2 == 1 then
              if panel.metal then
                draw(metals.left, draw_x, draw_y, 0, 8 / metall_w, 16 / metall_h)
                draw(metals.right, draw_x + 8, draw_y, 0, 8 / metalr_w, 16 / metalr_h)
              else
                local popped_w, popped_h = imgs.pop:getDimensions()
                draw(imgs.pop, draw_x, draw_y, 0, 16 / popped_w, 16 / popped_h)
              end
            else
              local flashed_w, flashed_h = imgs.flash:getDimensions()
              draw(imgs.flash, draw_x, draw_y, 0, 16 / flashed_w, 16 / flashed_h)
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
          draw(panels[self.panels_dir].images.classic[panel.color][draw_frame], draw_x, draw_y, 0, 16 / panel_w, 16 / panel_h)
        end
      end
    end
  end

  -- Draw the frames and wall at the bottom
  if self.which == 1 then
    draw(themes[config.theme].images.IMG_frame1P, 0, 0)
    draw(themes[config.theme].images.IMG_wall1P, 4, 4 - shake + self.height * 16)
  else
    draw(themes[config.theme].images.IMG_frame2P, 0, 0)
    draw(themes[config.theme].images.IMG_wall2P, 4, 4 - shake + self.height * 16)
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

  gfx_q:push({love.graphics.setStencilTest, {}})
  gfx_q:push({love.graphics.setCanvas, {global_canvas}})
  gfx_q:push({love.graphics.draw, {self.canvas, (self.pos_x - 4) * GFX_SCALE, (self.pos_y - 4) * GFX_SCALE}})

  self:draw_popfxs()
  self:draw_cards()

  -- Draw debug graphics if set
  if config.debug_mode then
    local mx, my = love.mouse.getPosition()
    for row = 0, self.height do
      for col = 1, self.width do
        local panel = self.panels[row][col]
        local draw_x = (self.pos_x + (col - 1) * 16) * GFX_SCALE
        local draw_y = (self.pos_y + (11 - (row)) * 16 + self.displacement - shake) * GFX_SCALE
        if panel.color ~= 0 and panel.state ~= "popped" then
          gprint(panel.state, draw_x, draw_y)
          if panel.match_anyway ~= nil then
            gprint(tostring(panel.match_anyway), draw_x, draw_y + 10)
            if panel.debug_tag then
              gprint(tostring(panel.debug_tag), draw_x, draw_y + 20)
            end
          end
          gprint(panel.chaining and "chaining" or "nah", draw_x, draw_y + 30)
        end
        if mx >= draw_x and mx < draw_x + 16 * GFX_SCALE and my >= draw_y and my < draw_y + 16 * GFX_SCALE then
          GAME.debug_mouse_panel = {row, col, panel}
          draw(panels[self.panels_dir].images.classic[9][1], draw_x + 16, draw_y + 16)
        end
      end
    end
  end

  -- draw outside of stack's frame canvas
  if self.match.mode == "puzzle" then
    --gprint(loc("pl_moves", self.puzzle_moves), self.score_x, self.score_y)
    if self.puzzle_moves then
      draw_label(themes[config.theme].images.IMG_moves, (self.origin_x + themes[config.theme].moveLabel_Pos[1]) / GFX_SCALE, (self.pos_y + themes[config.theme].moveLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].moveLabel_Scale)
      draw_number(self.puzzle_moves, themes[config.theme].images.IMG_number_atlas_1P, 10, move_quads, self.score_x + themes[config.theme].move_Pos[1], self.score_y + themes[config.theme].move_Pos[2], themes[config.theme].move_Scale, (30 / themes[config.theme].images.numberWidth_1P * themes[config.theme].move_Scale), (38 / themes[config.theme].images.numberHeight_1P * themes[config.theme].move_Scale), "center", self.multiplication)  
    end
    if config.show_ingame_infos then
    --gprint(loc("pl_frame", self.CLOCK), self.score_x, self.score_y+30)
    end
  else
    -- Draw the "extra" game info
    if config.show_ingame_infos then
      --gprint(loc("pl_score", self.score), self.score_x, self.score_y-40)
      draw_label(themes[config.theme].images["IMG_score" .. self.id], self.origin_x + (themes[config.theme].scoreLabel_Pos[1] * self.mirror_x), self.pos_y + themes[config.theme].scoreLabel_Pos[2], 0, themes[config.theme].scoreLabel_Scale, self.multiplication)
      draw_number(self.score, themes[config.theme].images["IMG_number_atlas" .. self.id], 10, score_quads, (self.origin_x + (themes[config.theme].score_Pos[1] * self.mirror_x)) * GFX_SCALE, (self.pos_y + themes[config.theme].score_Pos[2]) * GFX_SCALE, themes[config.theme].score_Scale, (15 / themes[config.theme].images["numberWidth" .. self.id] * themes[config.theme].score_Scale), (19.5 / themes[config.theme].images["numberHeight" .. self.id] * themes[config.theme].score_Scale), "center", self.multiplication)
      --gprint(loc("pl_speed", self.speed), self.score_x, self.score_y+45)
      draw_label(themes[config.theme].images["IMG_speed" .. self.id], self.origin_x + themes[config.theme].speedLabel_Pos[1] * self.mirror_x, (self.pos_y + themes[config.theme].speedLabel_Pos[2]), 0, themes[config.theme].speedLabel_Scale, self.multiplication)
      draw_number(self.speed, themes[config.theme].images["IMG_number_atlas" .. self.id], 10, speed_quads, (self.origin_x + (themes[config.theme].speed_Pos[1] * self.mirror_x)) * GFX_SCALE, (self.pos_y + themes[config.theme].speed_Pos[2]) * GFX_SCALE, themes[config.theme].speed_Scale, (15 / themes[config.theme].images["numberWidth" .. self.id] * themes[config.theme].speed_Scale), (19 / themes[config.theme].images["numberHeight" .. self.id] * themes[config.theme].speed_Scale), "center", self.multiplication)
    --gprint(loc("pl_frame", self.CLOCK), self.score_x, self.score_y+100)
    end
    local main_infos_screen_pos = {x = 375 + (canvas_width - legacy_canvas_width) / 2, y = 10 + (canvas_height - legacy_canvas_height)}

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
      draw_label(themes[config.theme].images.IMG_time, (main_infos_screen_pos.x + themes[config.theme].timeLabel_Pos[1]) / GFX_SCALE, (main_infos_screen_pos.y + themes[config.theme].timeLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].timeLabel_Scale)
      draw_time(string.format("%01d:%02d", mins, secs), time_quads, main_infos_screen_pos.x + themes[config.theme].time_Pos[1], main_infos_screen_pos.y + themes[config.theme].time_Pos[2], 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale)
    -- Draw the current difficulty level
    elseif self.level then
      --gprint(loc("pl_level", self.level), self.score_x, self.score_y+70)
      draw_label(themes[config.theme].images["IMG_level" .. self.id], self.origin_x + themes[config.theme].levelLabel_Pos[1] * self.mirror_x, self.pos_y + themes[config.theme].levelLabel_Pos[2], 0, themes[config.theme].levelLabel_Scale, self.multiplication)

      level_atlas = themes[config.theme].images["IMG_levelNumber_atlas" .. self.id]
      level_quad:setViewport(tonumber(self.level - 1) * (level_atlas:getWidth() / 11), 0, level_atlas:getWidth() / 11, level_atlas:getHeight(), level_atlas:getDimensions())
      qdraw(level_atlas, level_quad, (self.origin_x + themes[config.theme].level_Pos[1] * self.mirror_x), (self.pos_y + themes[config.theme].level_Pos[2]), 0, (28 / themes[config.theme].images["levelNumberWidth" .. self.id] * themes[config.theme].level_Scale) / GFX_SCALE, (26 / themes[config.theme].images["levelNumberHeight" .. self.id] * themes[config.theme].level_Scale / GFX_SCALE), 0, 0, self.multiplication)
    end
    -- Draw the stop time and healthbars
    if config.show_ingame_infos then
      --gprint(loc("pl_health", self.health), self.score_x, self.score_y-40)
      --(self.pos_x-4)*GFX_SCALE, (self.pos_y-4)*GFX_SCALE
      --if healthQuad == nil then local healthQuad = love.graphics.newQuad(0, 0, themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight(),
      --  themes[config.theme].images.IMG_healthbar:getWidth(), themes[config.theme].images.IMG_healthbar:getHeight()) end

      if not themes[config.theme].multibar_is_absolute then
        -- Healthbar frame
        draw_label(themes[config.theme].images["IMG_healthbar_frame" .. self.id], self.origin_x + themes[config.theme].healthbar_frame_Pos[1] * self.mirror_x, self.pos_y + themes[config.theme].healthbar_frame_Pos[2], 0, themes[config.theme].healthbar_frame_Scale, self.multiplication)
        -- Healthbar
        local healthbar = self.health * (themes[config.theme].images.IMG_healthbar:getHeight() / self.max_health)
        healthQuad:setViewport(0, themes[config.theme].images.IMG_healthbar:getHeight() - healthbar, themes[config.theme].images.IMG_healthbar:getWidth(), healthbar)
        qdraw(themes[config.theme].images.IMG_healthbar, healthQuad, self.origin_x + themes[config.theme].healthbar_Pos[1] * self.mirror_x, (self.pos_y + themes[config.theme].healthbar_Pos[2]) + (themes[config.theme].images.IMG_healthbar:getHeight() - healthbar), themes[config.theme].healthbar_Rotate, themes[config.theme].healthbar_Scale, themes[config.theme].healthbar_Scale, 0, 0, self.multiplication)
      end

      --gprint(loc("pl_stop", self.stop_time), self.score_x, self.score_y+300)
      --gprint(loc("pl_shake", self.shake_time), self.score_x, self.score_y+320)
      --gprint(loc("pl_pre_stop", self.pre_stop_time), self.score_x, self.score_y+340)
      -- Prestop frame
      draw_label(themes[config.theme].images.IMG_prestop_frame, self.origin_x + themes[config.theme].prestop_frame_Pos[1] * self.mirror_x, self.pos_y + themes[config.theme].prestop_frame_Pos[2], 0, themes[config.theme].prestop_frame_Scale, self.multiplication)
      -- Prestop bar
      if self.pre_stop_time == 0 or self.maxPrestop == nil then
        self.maxPrestop = 0
      end
      if self.pre_stop_time > self.maxPrestop then
        self.maxPrestop = self.pre_stop_time
      end

      prestop_frame_Pos = {(self.origin_x + themes[config.theme].prestop_frame_Pos[1] * self.mirror_x) + ((themes[config.theme].images.IMG_prestop_frame:getWidth() - 10) / GFX_SCALE * self.multiplication * self.mirror_x), self.pos_y + themes[config.theme].prestop_frame_Pos[2]}
      if self.maxPrestop > 0 then
        prestop_bar = self.pre_stop_time * (themes[config.theme].images.IMG_prestop_bar:getHeight() / self.maxPrestop)
      else
        prestop_bar = 0
      end
      prestopQuad:setViewport(0, themes[config.theme].images.IMG_prestop_bar:getHeight() - prestop_bar, themes[config.theme].images.IMG_prestop_bar:getWidth(), prestop_bar)
      qdraw(themes[config.theme].images.IMG_prestop_bar, prestopQuad, self.origin_x + (themes[config.theme].prestop_bar_Pos[1] * self.mirror_x), ((self.pos_y + themes[config.theme].prestop_bar_Pos[2]) + ((themes[config.theme].images.IMG_prestop_bar:getHeight() - prestop_bar) / GFX_SCALE)), themes[config.theme].prestop_bar_Rotate, themes[config.theme].prestop_bar_Scale / GFX_SCALE, themes[config.theme].prestop_bar_Scale / GFX_SCALE, 0, 0, self.multiplication)
      -- Prestop number
      draw_number(self.pre_stop_time, themes[config.theme].images.IMG_timeNumber_atlas, 12, prestop_quads, (self.origin_x + (themes[config.theme].prestop_Pos[1] * self.mirror_x)) * GFX_SCALE, (self.pos_y + themes[config.theme].prestop_Pos[2]) * GFX_SCALE, themes[config.theme].prestop_Scale, (15 / themes[config.theme].images.timeNumberWidth * themes[config.theme].prestop_Scale), (19 / themes[config.theme].images.timeNumberHeight * themes[config.theme].prestop_Scale), "center", self.multiplication)

      -- Stop frame
      draw_label(themes[config.theme].images.IMG_stop_frame, self.origin_x + themes[config.theme].stop_frame_Pos[1] * self.mirror_x, self.pos_y + themes[config.theme].stop_frame_Pos[2], 0, themes[config.theme].stop_frame_Scale, self.multiplication)
      -- Stop bar
      if self.stop_time == 0 or self.maxStop == nil then
        self.maxStop = 0
      end
      if self.stop_time > self.maxStop then
        self.maxStop = self.stop_time
      end
      if self.maxStop > 0 then
        stop_bar = self.stop_time * (themes[config.theme].images.IMG_stop_bar:getHeight() / self.maxStop)
      else
        stop_bar = 0
      end
      stopQuad:setViewport(0, themes[config.theme].images.IMG_stop_bar:getHeight() - stop_bar, themes[config.theme].images.IMG_stop_bar:getWidth(), stop_bar)
      qdraw(themes[config.theme].images.IMG_stop_bar, stopQuad, self.origin_x + themes[config.theme].stop_bar_Pos[1] * self.mirror_x, ((self.pos_y + themes[config.theme].stop_bar_Pos[2]) + ((themes[config.theme].images.IMG_stop_bar:getHeight() - stop_bar) / GFX_SCALE)), themes[config.theme].stop_bar_Rotate, themes[config.theme].stop_bar_Scale / GFX_SCALE, themes[config.theme].stop_bar_Scale / GFX_SCALE, 0, 0, self.multiplication)
      -- Stop number
      draw_number(self.stop_time, themes[config.theme].images.IMG_timeNumber_atlas, 12, stop_quads, (self.origin_x + (themes[config.theme].stop_Pos[1] * self.mirror_x)) * GFX_SCALE, (self.pos_y + themes[config.theme].stop_Pos[2]) * GFX_SCALE, themes[config.theme].stop_Scale, (15 / themes[config.theme].images.timeNumberWidth * themes[config.theme].stop_Scale), (19 / themes[config.theme].images.timeNumberHeight * themes[config.theme].stop_Scale), "center", self.multiplication)

      -- Shake frame
      draw_label(themes[config.theme].images.IMG_shake_frame, self.origin_x + themes[config.theme].shake_frame_Pos[1] * self.mirror_x, self.pos_y + themes[config.theme].shake_frame_Pos[2], 0, themes[config.theme].shake_frame_Scale, self.multiplication)
      -- Shake bar
      if self.shake_time == 0 or self.maxShake == nil then
        self.maxShake = 0
      end
      if self.shake_time > self.maxShake then
        self.maxShake = self.shake_time
      end
      if self.maxShake > 0 then
        shake_bar = self.shake_time * (themes[config.theme].images.IMG_shake_bar:getHeight() / self.maxShake)
      else
        shake_bar = 0
      end

      if not themes[config.theme].multibar_is_absolute then
        shakeQuad:setViewport(0, themes[config.theme].images.IMG_shake_bar:getHeight() - shake_bar, themes[config.theme].images.IMG_shake_bar:getWidth(), shake_bar)
        qdraw(themes[config.theme].images.IMG_shake_bar, shakeQuad, self.origin_x + themes[config.theme].shake_bar_Pos[1] * self.mirror_x, ((self.pos_y + themes[config.theme].shake_bar_Pos[2]) + ((themes[config.theme].images.IMG_shake_bar:getHeight() - shake_bar) / GFX_SCALE)), themes[config.theme].shake_bar_Rotate, themes[config.theme].shake_bar_Scale / GFX_SCALE, themes[config.theme].shake_bar_Scale / GFX_SCALE, 0, 0, self.multiplication)
      end
      -- Shake number
      draw_number(self.shake_time, themes[config.theme].images.IMG_timeNumber_atlas, 12, shake_quads, (self.origin_x + (themes[config.theme].shake_Pos[1] * self.mirror_x)) * GFX_SCALE, (self.pos_y + themes[config.theme].shake_Pos[2]) * GFX_SCALE, themes[config.theme].shake_Scale, (15 / themes[config.theme].images.timeNumberWidth * themes[config.theme].shake_Scale), (19 / themes[config.theme].images.timeNumberHeight * themes[config.theme].shake_Scale), "center", self.multiplication)

      -- Multibar

      if not themes[config.theme].multibar_is_absolute then
        local multi_shake_bar, multi_stop_bar, multi_prestop_bar = 0, 0, 0
        if self.maxShake > 0 and self.shake_time >= self.pre_stop_time + self.stop_time then
          multi_shake_bar = self.shake_time * (themes[config.theme].images.IMG_multibar_shake_bar:getHeight() / self.maxShake) * 3
        end
        if self.maxStop > 0 and self.shake_time < self.pre_stop_time + self.stop_time then
          multi_stop_bar = self.stop_time * (themes[config.theme].images.IMG_multibar_stop_bar:getHeight() / self.maxStop) * 1.5
        end
        if self.maxPrestop > 0 and self.shake_time < self.pre_stop_time + self.stop_time then
          multi_prestop_bar = self.pre_stop_time * (themes[config.theme].images.IMG_multibar_prestop_bar:getHeight() / self.maxPrestop) * 1.5
        end
        multi_shakeQuad:setViewport(0, themes[config.theme].images.IMG_multibar_shake_bar:getHeight() - multi_shake_bar, themes[config.theme].images.IMG_multibar_shake_bar:getWidth(), multi_shake_bar)
        multi_stopQuad:setViewport(0, themes[config.theme].images.IMG_multibar_stop_bar:getHeight() - multi_stop_bar, themes[config.theme].images.IMG_multibar_stop_bar:getWidth(), multi_stop_bar)
        multi_prestopQuad:setViewport(0, themes[config.theme].images.IMG_multibar_prestop_bar:getHeight() - multi_prestop_bar, themes[config.theme].images.IMG_multibar_prestop_bar:getWidth(), multi_prestop_bar)

        draw_label(themes[config.theme].images.IMG_multibar_frame, self.origin_x + themes[config.theme].multibar_frame_Pos[1] * self.mirror_x, self.pos_y + themes[config.theme].multibar_frame_Pos[2], 0, themes[config.theme].multibar_frame_Scale, self.multiplication)
        --Shake
        qdraw(themes[config.theme].images.IMG_multibar_shake_bar, multi_shakeQuad, self.origin_x + themes[config.theme].multibar_Pos[1] * self.mirror_x, ((self.pos_y + themes[config.theme].multibar_Pos[2]) + ((themes[config.theme].images.IMG_multibar_shake_bar:getHeight() - multi_shake_bar) / GFX_SCALE)), 0, themes[config.theme].multibar_Scale / GFX_SCALE, themes[config.theme].multibar_Scale / GFX_SCALE, 0, 0, self.multiplication)
        --Stop
        qdraw(themes[config.theme].images.IMG_multibar_stop_bar, multi_stopQuad, self.origin_x + themes[config.theme].multibar_Pos[1] * self.mirror_x, (((self.pos_y - (multi_shake_bar / GFX_SCALE)) + themes[config.theme].multibar_Pos[2]) + ((themes[config.theme].images.IMG_multibar_stop_bar:getHeight() - multi_stop_bar) / GFX_SCALE)), 0, themes[config.theme].multibar_Scale / GFX_SCALE, themes[config.theme].multibar_Scale / GFX_SCALE, 0, 0, self.multiplication)
        -- Prestop
        qdraw(themes[config.theme].images.IMG_multibar_prestop_bar, multi_prestopQuad, self.origin_x + (themes[config.theme].multibar_Pos[1] * self.mirror_x), (((self.pos_y - (multi_shake_bar / GFX_SCALE + multi_stop_bar / GFX_SCALE)) + themes[config.theme].multibar_Pos[2]) + ((themes[config.theme].images.IMG_multibar_prestop_bar:getHeight() - multi_prestop_bar) / GFX_SCALE)), 0, themes[config.theme].multibar_Scale / GFX_SCALE, themes[config.theme].multibar_Scale / GFX_SCALE, 0, 0, self.multiplication)
      else
        -- Healthbar
        local iconX = (self.origin_x + themes[config.theme].multibar_Pos[1] * self.mirror_x) * GFX_SCALE
        local iconY = 700
        local multiBarMaxHeight = 590
        local multiBarFrameScale = 3

        local healthBar = self.health * multiBarFrameScale
        local shakeTimeBar, stopTimeBar, preStopBar = 0, 0, 0
        if self.maxShake > 0 and self.shake_time >= self.pre_stop_time + self.stop_time then
          stopTimeBar = math.min(self.shake_time * multiBarFrameScale, multiBarMaxHeight - healthBar)
        end
        if self.maxStop > 0 and self.shake_time < self.pre_stop_time + self.stop_time then
          stopTimeBar = math.min(self.stop_time * multiBarFrameScale, multiBarMaxHeight - shakeTimeBar - healthBar)
        end
        if self.maxPrestop > 0 and self.shake_time < self.pre_stop_time + self.stop_time then
          preStopBar = math.min(self.pre_stop_time * multiBarFrameScale, multiBarMaxHeight - stopTimeBar - shakeTimeBar - healthBar)
        end

        local desiredWidth, _ = themes[config.theme].images.IMG_multibar_shake_bar:getDimensions()
        local iconXScale, iconYScale, icon_width, icon_height
        icon_width, icon_height = themes[config.theme].images.IMG_healthbar:getDimensions()
        iconXScale = (desiredWidth / GFX_SCALE) / icon_width * self.mirror_x
        iconYScale = -(healthBar / icon_height) / GFX_SCALE
        draw(themes[config.theme].images.IMG_healthbar, iconX / GFX_SCALE, iconY / GFX_SCALE, 0, iconXScale, iconYScale)

        iconY = iconY - healthBar

        --Shake
        icon_width, icon_height = themes[config.theme].images.IMG_multibar_shake_bar:getDimensions()
        iconXScale = (desiredWidth / GFX_SCALE) / icon_width * self.mirror_x
        iconYScale = -(shakeTimeBar / icon_height) / GFX_SCALE
        draw(themes[config.theme].images.IMG_multibar_shake_bar, iconX / GFX_SCALE, iconY / GFX_SCALE, 0, iconXScale, iconYScale)

        --Stop
        icon_width, icon_height = themes[config.theme].images.IMG_multibar_stop_bar:getDimensions()
        iconXScale = (desiredWidth / GFX_SCALE) / icon_width * self.mirror_x
        iconYScale = -(stopTimeBar / icon_height) / GFX_SCALE
        draw(themes[config.theme].images.IMG_multibar_stop_bar, iconX / GFX_SCALE, iconY / GFX_SCALE, 0, iconXScale, iconYScale)

        -- Prestop
        icon_width, icon_height = themes[config.theme].images.IMG_multibar_prestop_bar:getDimensions()
        iconXScale = (desiredWidth / GFX_SCALE) / icon_width * self.mirror_x
        iconYScale = -(preStopBar / icon_height) / GFX_SCALE
        iconY = iconY - math.max(shakeTimeBar, stopTimeBar)
        draw(themes[config.theme].images.IMG_multibar_prestop_bar, iconX / GFX_SCALE, iconY / GFX_SCALE, 0, iconXScale, iconYScale)
      end

      if config.debug_mode and self.danger then
        gprint("danger", self.score_x, self.score_y + 135)
      end
      if config.debug_mode and self.danger_music then
        gprint("danger music", self.score_x, self.score_y + 150)
      end
      if config.debug_mode then
        gprint(loc("pl_cleared", (self.panels_cleared or 0)), self.score_x, self.score_y + 165)
      end
      if config.debug_mode then
        gprint(loc("pl_metal", (self.metal_panels_queued or 0)), self.score_x, self.score_y + 180)
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
        gprint(inputs_to_print, self.score_x, self.score_y + 195)
      end
    end
    --local main_infos_screen_pos = { x=375 + (canvas_width-legacy_canvas_width)/2, y=10 + (canvas_height-legacy_canvas_height) }
    if match_type ~= "" then
      --gprint(match_type, main_infos_screen_pos.x, main_infos_screen_pos.y-50)
      if match_type == "Ranked" then
        IMG_match = themes[config.theme].images.IMG_ranked
      end
      if match_type == "Casual" then
        IMG_match = themes[config.theme].images.IMG_casual
      end
      draw_label(IMG_match, (main_infos_screen_pos.x + themes[config.theme].matchtypeLabel_Pos[1]) / GFX_SCALE, (main_infos_screen_pos.y + themes[config.theme].matchtypeLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].matchtypeLabel_Scale)
    --[[
      if self.win_counts == nil then win = 0 else win = self.win_counts end
      draw(themes[config.theme].images.IMG_wins, (self.score_x+themes[config.theme].winLabel_Pos[1])/GFX_SCALE, (self.score_y+themes[config.theme].winLabel_Pos[2])/GFX_SCALE, 0,
        (60/themes[config.theme].images.IMG_wins:getWidth()*themes[config.theme].winLabel_Scale)/GFX_SCALE, (28/themes[config.theme].images.IMG_wins:getHeight()*themes[config.theme].winLabel_Scale)/GFX_SCALE)
      draw_number(win, themes[config.theme].images.IMG_timeNumber_atlas, 12, win_quads, self.score_x+themes[config.theme].win_Pos[1], self.score_y+themes[config.theme].win_Pos[2], themes[config.theme].win_Scale,
        20/themes[config.theme].images.timeNumberWidth*themes[config.theme].time_Scale, 26/themes[config.theme].images.timeNumberHeight*themes[config.theme].time_Scale, "center")
      ]]
    end

    -- Draw the time for non time attack modes
    if self and self.game_stopwatch and tonumber(self.game_stopwatch) and self.match.mode ~= "time" then
      --gprint(frames_to_time_string(self.game_stopwatch, self.match.mode == "endless"), main_infos_screen_pos.x+10, main_infos_screen_pos.y+6)
      draw_label(themes[config.theme].images.IMG_time, (main_infos_screen_pos.x + themes[config.theme].timeLabel_Pos[1]) / GFX_SCALE, (main_infos_screen_pos.y + themes[config.theme].timeLabel_Pos[2]) / GFX_SCALE, 0, themes[config.theme].timeLabel_Scale)
      draw_time(frames_to_time_string(self.game_stopwatch, self.match.mode == "endless"), time_quads, main_infos_screen_pos.x + themes[config.theme].time_Pos[1], main_infos_screen_pos.y + themes[config.theme].time_Pos[2], 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale)
    end

    -- Draw the community message
    if not config.debug_mode then
      gprint(join_community_msg or "", main_infos_screen_pos.x - 45, main_infos_screen_pos.y + 550)
    end
  end

  -- Draw the analytics data
  if config.enable_analytics and self.drawsAnalytics == true then
    local xPosition = self.score_x - 512
    if self.which == 2 then
      xPosition = xPosition + 990
    end
    self:drawAnalyticData(self.analytic, xPosition, self.score_y - 81)
  end
  -- ends here
end


function Stack.drawAnalyticData(self, analytic, x, y)

  local backgroundPadding = 6
  local textYPadding = 18
  local iconToTextSpacing = 30
  local nextIconIncrement = 30
  local column2Distance = 70

  local fontIncrement = 8
  local iconSize = 8
  local icon_width
  local icon_height

  -- Background
  grectangle_color("fill", x / GFX_SCALE - backgroundPadding, y / GFX_SCALE - backgroundPadding, 160/GFX_SCALE, 600/GFX_SCALE, 0, 0, 0, 0.5)

  -- Panels cleared
  icon_width, icon_height = panels[self.panels_dir].images.classic[1][6]:getDimensions()
  draw(panels[self.panels_dir].images.classic[1][6], x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
  gprintf(analytic.data.destroyed_panels, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  -- Garbage sent
  icon_width, icon_height = characters[self.character].images.face:getDimensions()
  draw(characters[self.character].images.face, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
  gprintf(analytic.data.sent_garbage_lines, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  -- GPM
  if math.fmod(self.CLOCK, 60) == 0 then
    if self.CLOCK > 0 and (analytic.data.sent_garbage_lines > 0) then
      local garbagePerMinute = analytic.data.sent_garbage_lines / (self.CLOCK / 60 / 60)
      analytic.lastGPM = string.format("%0.1f", round(garbagePerMinute, 1))
    end
  end
  icon_width, icon_height = themes[config.theme].images.IMG_gpm:getDimensions()
  draw(themes[config.theme].images.IMG_gpm, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
  gprintf(analytic.lastGPM .. "/m", x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement)  

  y = y + nextIconIncrement

  -- Moves
  icon_width, icon_height = themes[config.theme].images.IMG_cursorCount:getDimensions()
  draw(themes[config.theme].images.IMG_cursorCount, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
  gprintf(analytic.data.move_count, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  -- Swaps
  if themes[config.theme].images.IMG_swap then
    icon_width, icon_height = themes[config.theme].images.IMG_swap:getDimensions()
    draw(themes[config.theme].images.IMG_swap, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
  end
  gprintf(analytic.data.swap_count, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  -- APM
  if math.fmod(self.CLOCK, 60) == 0 then
    if self.CLOCK > 0 and (analytic.data.swap_count + analytic.data.move_count > 0) then
      local actionsPerMinute = (analytic.data.swap_count + analytic.data.move_count) / (self.CLOCK / 60 / 60)
      analytic.lastAPM = string.format("%0.0f", round(actionsPerMinute, 0))
    end
  end
  if themes[config.theme].images.IMG_apm then
    icon_width, icon_height = themes[config.theme].images.IMG_apm:getDimensions()
    draw(themes[config.theme].images.IMG_apm, x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
  end
  gprintf(analytic.lastAPM .. "/m", x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement)

  y = y + nextIconIncrement

  local yCombo = y

  -- Clean up the chain data so we only show chains up to the highest chain the user has done
  local chainData = shallowcpy(analytic.data.reached_chains)
  local chain_above_13 = analytic:compute_above_13()

  for i = 2, 13, 1 do
    if not chainData[i] then
      chainData[i] = 0
    end
  end
  table.insert(chainData, chain_above_13)
  for i = #chainData, 0, -1 do
    if chainData[i] and chainData[i] == 0 then
      chainData[i] = nil
    else
      break
    end
  end

  -- Draw the chain images
  for i = 2, 14 do
    local chain_amount = chainData[i]
    if chain_amount and chain_amount > 0 then
      icon_width, icon_height = themes[config.theme].images.IMG_cards[true][i]:getDimensions()
      draw(themes[config.theme].images.IMG_cards[true][i], x / GFX_SCALE, y / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
      gprintf(chain_amount, x + iconToTextSpacing, y + 0, canvas_width, "left", nil, 1, fontIncrement)
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
  for i = #comboData, 0, -1 do
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
      draw(themes[config.theme].images.IMG_cards[false][i], xCombo / GFX_SCALE, yCombo / GFX_SCALE, 0, iconSize / icon_width, iconSize / icon_height)
      gprintf(combo_amount, xCombo + iconToTextSpacing, yCombo + 0, canvas_width, "left", nil, 1, fontIncrement)
      yCombo = yCombo + nextIconIncrement
    end
  end
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
  local shake_idx = #shake_arr - self.shake_time
  local shake = ceil((shake_arr[shake_idx] or 0) * 13)
  if self.countdown_timer then
    if self.CLOCK % 2 == 0 then
      draw(themes[config.theme].images.IMG_cursor[1], (self.cur_col - 1) * 16, (11 - (self.cur_row)) * 16 + self.displacement - shake)
    end
  else
    draw(themes[config.theme].images.IMG_cursor[(floor(self.CLOCK / 16) % 2) + 1], (self.cur_col - 1) * 16, (11 - (self.cur_row)) * 16 + self.displacement - shake)
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
      draw(themes[config.theme].images.IMG_ready, ready_x, ready_y)
      if self.countdown_CLOCK == 8 then
        self.ready_y = ready_y
      end
    elseif self.countdown_CLOCK >= 9 and self.countdown_timer and self.countdown_timer > 0 then
      if self.countdown_timer >= 100 then
        draw(themes[config.theme].images.IMG_ready, ready_x, self.ready_y or initial_ready_y + 8 * 6)
      end
      local IMG_number_to_draw = themes[config.theme].images.IMG_numbers[math.ceil(self.countdown_timer / 60)]
      if IMG_number_to_draw then
        draw(IMG_number_to_draw, countdown_x, countdown_y)
      end
    end
  end
end

-- Draw the pause menu
function draw_pause()
  draw(themes[config.theme].images.pause, 0, 0)
  gprintf(loc("pause"), 0, 330, canvas_width, "center", nil, 1, large_font)
  gprintf(loc("pl_pause_help"), 0, 360, canvas_width, "center", nil, 1)
end

require("input")
require("util")
local analytics = require("analytics")

local floor = math.floor
local ceil = math.ceil

local shake_arr = {}

local shake_idx = -6
for i=14,6,-1 do
  local x = -math.pi
  local step = math.pi * 2 / i
  for j=1,i do
    shake_arr[shake_idx] = (1 + math.cos(x))/2
    x = x + step
    shake_idx = shake_idx + 1
  end
end

-- 1 -> 1
-- #shake -> 0
local shake_step = 1/(#shake_arr - 1)
local shake_mult = 1
for i=1,#shake_arr do
  shake_arr[i] = shake_arr[i] * shake_mult
  -- print(shake_arr[i])
  shake_mult = shake_mult - shake_step
end

function Stack.update_cards(self)
  for i=self.card_q.first,self.card_q.last do
    local card = self.card_q[i]
    if card_animation[card.frame] then
      card.frame = card.frame + 1
      if(card_animation[card.frame]==nil) then
        self.card_q:pop()
      end
    else
      card.frame = card.frame + 1
    end
  end
end

function Stack.draw_cards(self)
  for i=self.card_q.first,self.card_q.last do
    local card = self.card_q[i]
    if card_animation[card.frame] then
      local draw_x = 4 + (card.x-1) * 16
      local draw_y = 4 + (11-card.y) * 16 + self.displacement
          - card_animation[card.frame]
      draw(themes[config.theme].images.IMG_cards[card.chain][card.n], draw_x, draw_y)
    end
  end
end

function move_stack(stack, player_num)
  local stack_padding_x_for_legacy_pos = ((canvas_width-legacy_canvas_width)/2)
  if player_num == 1 then
    stack.pos_x = 4 + stack_padding_x_for_legacy_pos/GFX_SCALE 
    stack.score_x = 315 + stack_padding_x_for_legacy_pos
  elseif player_num == 2 then
    stack.pos_x = 172 + stack_padding_x_for_legacy_pos/GFX_SCALE 
    stack.score_x = 410 + stack_padding_x_for_legacy_pos
  end
  stack.pos_y = 4 + (canvas_height-legacy_canvas_height)/GFX_SCALE
  stack.score_y = 100 + (canvas_height-legacy_canvas_height)
end
 
local mask_shader = love.graphics.newShader[[
   vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
      if (Texel(texture, texture_coords).rgb == vec3(0.0)) {
         // a discarded pixel wont be applied as the stencil.
         discard;
      }
      return vec4(1.0);
   }
]]

function Stack.render(self)
  local function frame_mask(x_pos, y_pos)
    love.graphics.setShader(mask_shader)
    love.graphics.setBackgroundColor(1,1,1)
    local canvas_w, canvas_h = self.canvas:getDimensions()
    love.graphics.rectangle( "fill", 0,0,canvas_w,canvas_h)
    love.graphics.setBackgroundColor(unpack(global_background_color))
    love.graphics.setShader()
  end  

  gfx_q:push({love.graphics.setCanvas, {{self.canvas, stencil=true}}})
  gfx_q:push({love.graphics.clear, {}})
  gfx_q:push({love.graphics.stencil, {frame_mask, "replace", 1}})
  gfx_q:push({love.graphics.setStencilTest, {"greater", 0}})

  -- draw inside stack's frame canvas
  local portrait_w, portrait_h = characters[self.character].images["portrait"]:getDimensions()
  if P1 == self then
    draw(characters[self.character].images["portrait"], 4, 4, 0, 96/portrait_w, 192/portrait_h)
  else
    draw(characters[self.character].images["portrait"], 100, 4, 0, (96/portrait_w)*-1, 192/portrait_h)
  end

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

  for row=0,self.height do
    for col=1,self.width do
      local panel = self.panels[row][col]
      local draw_x = 4 + (col-1) * 16
      local draw_y = 4 + (11-(row)) * 16 + self.displacement - shake
      if panel.color ~= 0 and panel.state ~= "popped" then
        local draw_frame = 1
        if panel.garbage then
          local imgs = {flash=metals.flash}
          if not panel.metal then
            imgs = characters[self.garbage_target.character].images
          end
          if panel.x_offset == 0 and panel.y_offset == 0 then
            -- draw the entire block!
            if panel.metal then
              draw(metals.left, draw_x, draw_y, 0, 8/metall_w, 16/metall_h)
              draw(metals.right, draw_x+16*(panel.width-1)+8,draw_y, 0, 8/metalr_w, 16/metalr_h)
              for i=1,2*(panel.width-1) do
                draw(metals.mid, draw_x+8*i, draw_y, 0, 8/metal_w, 16/metal_h)
              end
            else
              local height, width = panel.height, panel.width
              local top_y = draw_y - (height-1) * 16
              local use_1 = ((height-(height%2))/2)%2==0
              local filler_w, filler_h = imgs.filler1:getDimensions()
              for i=0,height-1 do
                for j=1,width-1 do
                  draw((use_1 or height<3) and imgs.filler1 or
                    imgs.filler2, draw_x+16*j-8, top_y+16*i, 0, 16/filler_w, 16/filler_h)
                  use_1 = not use_1
                end
              end
              if height%2==1 then
                local face_w, face_h = imgs.face:getDimensions()
                draw(imgs.face, draw_x+8*(width-1), top_y+16*((height-1)/2), 0, 16/face_w, 16/face_h)
              else
                local face_w, face_h = imgs.doubleface:getDimensions()
                draw(imgs.doubleface, draw_x+8*(width-1), top_y+16*((height-2)/2), 0, 16/face_w, 32/face_h)
              end
              local corner_w, corner_h = imgs.topleft:getDimensions()
              local lr_w, lr_h = imgs.left:getDimensions()
              local topbottom_w, topbottom_h = imgs.top:getDimensions()
              draw(imgs.left, draw_x, top_y, 0, 8/lr_w, (1/lr_h)*height*16)
              draw(imgs.right, draw_x+16*(width-1)+8, top_y, 0, 8/lr_w, (1/lr_h)*height*16)
              draw(imgs.top, draw_x, top_y, 0, (1/topbottom_w)*width*16, 2/topbottom_h)
              draw(imgs.bot, draw_x, draw_y+14, 0, (1/topbottom_w)*width*16, 2/topbottom_h)
              draw(imgs.topleft, draw_x, top_y, 0, 8/corner_w, 3/corner_h)
              draw(imgs.topright, draw_x+16*width-8, top_y, 0, 8/corner_w, 3/corner_h)
              draw(imgs.botleft, draw_x, draw_y+13, 0, 8/corner_w, 3/corner_h)
              draw(imgs.botright, draw_x+16*width-8, draw_y+13, 0, 8/corner_w, 3/corner_h)
            end
          end
          if panel.state == "matched" then
            local flash_time = panel.initial_time - panel.timer
            if flash_time >= self.FRAMECOUNT_FLASH then
              if panel.timer > panel.pop_time then
                if panel.metal then
                  draw(metals.left, draw_x, draw_y, 0, 8/metall_w, 16/metall_h)
                  draw(metals.right, draw_x+8, draw_y, 0, 8/metalr_w, 16/metalr_h)
                else
                  local popped_w, popped_h = imgs.pop:getDimensions()
                  draw(imgs.pop, draw_x, draw_y, 0, 16/popped_w, 16/popped_h)
                end
              elseif panel.y_offset == -1 then
                local p_w, p_h = panels[self.panels_dir].images.classic[panel.color][1]:getDimensions()
                draw(panels[self.panels_dir].images.classic[panel.color][1], draw_x, draw_y, 0, 16/p_w, 16/p_h)
              end
            elseif flash_time % 2 == 1 then
              if panel.metal then
                draw(metals.left, draw_x, draw_y, 0, 8/metall_w, 16/metall_h)
                draw(metals.right, draw_x+8, draw_y, 0, 8/metalr_w, 16/metalr_h)
              else
                local popped_w, popped_h = imgs.pop:getDimensions()
                draw(imgs.pop, draw_x, draw_y, 0, 16/popped_w, 16/popped_h)
              end
            else
              local flashed_w, flashed_h = imgs.flash:getDimensions()
              draw(imgs.flash, draw_x, draw_y, 0, 16/flashed_w, 16/flashed_h)
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
          elseif panel.state == "dimmed" then
            draw_frame = 7
          elseif panel.fell_from_garbage then
            draw_frame = garbage_bounce_table[panel.fell_from_garbage] or 1
          elseif self.danger_col[col] then
            draw_frame = danger_bounce_table[
              wrap(1,self.danger_timer+1+floor((col-1)/2),#danger_bounce_table)]
          else
            draw_frame = 1
          end
          local panel_w, panel_h = panels[self.panels_dir].images.classic[panel.color][draw_frame]:getDimensions()
          draw(panels[self.panels_dir].images.classic[panel.color][draw_frame], draw_x, draw_y, 0, 16/panel_w, 16/panel_h)
        end
      end
    end
  end
  if P1 == self then
	draw(themes[config.theme].images.IMG_frame1P,0,0)
	draw(themes[config.theme].images.IMG_wall1P, 4, 4 - shake + self.height*16)
  else
	draw(themes[config.theme].images.IMG_frame2P,0,0)
	draw(themes[config.theme].images.IMG_wall2P, 4, 4 - shake + self.height*16)
  end

  self:draw_cards()
  self:render_cursor()
  if self.do_countdown then
    self:render_countdown()
  end
  -- ends here

  gfx_q:push({love.graphics.setStencilTest, {}})
  gfx_q:push({love.graphics.setCanvas, {global_canvas}})
  gfx_q:push({love.graphics.draw, {self.canvas, (self.pos_x-4)*GFX_SCALE, (self.pos_y-4)*GFX_SCALE }})

  if config.debug_mode then
    local mx, my = love.mouse.getPosition()
    for row=0,self.height do
      for col=1,self.width do
        local panel = self.panels[row][col]
        local draw_x = (self.pos_x + (col-1) * 16)*GFX_SCALE
        local draw_y = (self.pos_y + (11-(row)) * 16 + self.displacement - shake)*GFX_SCALE
        if panel.color ~= 0 and panel.state ~= "popped" then
          gprint(panel.state, draw_x, draw_y)
          if panel.match_anyway ~= nil then
            gprint(tostring(panel.match_anyway), draw_x, draw_y+10)
            if panel.debug_tag then
              gprint(tostring(panel.debug_tag), draw_x, draw_y+20)
            end
          end
          gprint(panel.chaining and "chaining" or "nah", draw_x, draw_y+30)
        end
        if mx >= draw_x and mx < draw_x + 16*GFX_SCALE and my >= draw_y and my < draw_y + 16*GFX_SCALE then
          debug_mouse_panel = {row, col, panel}
          draw(panels[self.panels_dir].images.classic[9][1], draw_x+16, draw_y+16)
        end
      end
    end
  end

  -- draw outside of stack's frame canvas
  if self.mode == "puzzle" then
    gprint(loc("pl_moves", self.puzzle_moves), self.score_x, self.score_y)
    if config.show_ingame_infos then
      gprint(loc("pl_frame", self.CLOCK), self.score_x, self.score_y+30)
    end
  else
    if config.show_ingame_infos then
      gprint(loc("pl_score", self.score), self.score_x, self.score_y)
      gprint(loc("pl_speed", self.speed), self.score_x, self.score_y+30)
      gprint(loc("pl_frame", self.CLOCK), self.score_x, self.score_y+45)
    end
    if self.mode == "time" then
      local time_left = 120 - (self.game_stopwatch or 120)/60
      local mins = math.floor(time_left/60)
      local secs = math.ceil(time_left% 60)
      if secs == 60 then
        secs = 0
        mins = mins+1
      end
      gprint(loc("pl_time", string.format("%01d:%02d",mins,secs)), self.score_x, self.score_y+60)
    elseif self.level then
      gprint(loc("pl_level", self.level), self.score_x, self.score_y+60)
    end
    if config.show_ingame_infos then
      gprint(loc("pl_health", self.health), self.score_x, self.score_y+75)
      gprint(loc("pl_shake", self.shake_time), self.score_x, self.score_y+90)
      gprint(loc("pl_stop", self.stop_time), self.score_x, self.score_y+105)
      gprint(loc("pl_pre_stop", self.pre_stop_time), self.score_x, self.score_y+120)
      if config.debug_mode and self.danger then gprint("danger", self.score_x,self.score_y+135) end
      if config.debug_mode and self.danger_music then gprint("danger music", self.score_x, self.score_y+150) end
      if config.debug_mode then
        gprint(loc("pl_cleared", (self.panels_cleared or 0)), self.score_x, self.score_y+165)
      end
      if config.debug_mode then
        gprint(loc("pl_metal", (self.metal_panels_queued or 0)), self.score_x, self.score_y+180)
      end
      if config.debug_mode and (self.input_state or self.taunt_up or self.taunt_down) then
        -- print(self.input_state)
        -- print(base64decode[self.input_state])
        local iraise, iswap, iup, idown, ileft, iright = unpack(base64decode[self.input_state])
        -- print(tostring(raise))
        local inputs_to_print = "inputs:"
        if iraise then inputs_to_print = inputs_to_print.."\nraise" end --◄▲▼►
        if iswap then inputs_to_print = inputs_to_print.."\nswap" end
        if iup then inputs_to_print = inputs_to_print.."\nup" end
        if idown then inputs_to_print = inputs_to_print.."\ndown" end
        if ileft then inputs_to_print = inputs_to_print.."\nleft" end
        if iright then inputs_to_print = inputs_to_print.."\nright" end
        if self.taunt_down then inputs_to_print = inputs_to_print.."\ntaunt_down" end
        if self.taunt_up then inputs_to_print = inputs_to_print.."\ntaunt_up" end
        gprint(inputs_to_print, self.score_x, self.score_y+195)
      end
    end
    local main_infos_screen_pos = { x=375 + (canvas_width-legacy_canvas_width)/2, y=10 + (canvas_height-legacy_canvas_height) }
    if match_type then gprint(match_type, main_infos_screen_pos.x, main_infos_screen_pos.y) end
    if P1 and P1.game_stopwatch and tonumber(P1.game_stopwatch) then
      gprint(frames_to_time_string(P1.game_stopwatch, P1.mode == "endless"), main_infos_screen_pos.x+10, main_infos_screen_pos.y+16)
    end
    if not config.debug_mode then
      gprint(join_community_msg or "", main_infos_screen_pos.x-45, main_infos_screen_pos.y+550)
    end
  end
  if self.enable_analytics then
    analytics.draw(self.score_x-460,self.score_y)
  end
  -- ends here
end

function scale_letterbox(width, height, w_ratio, h_ratio)
  if height / h_ratio > width / w_ratio then
    local scaled_height = h_ratio * width / w_ratio
    return 0, (height - scaled_height) / 2, width, scaled_height
  end
  local scaled_width = w_ratio * height / h_ratio
  return (width - scaled_width) / 2, 0, scaled_width, height
end

function Stack.render_cursor(self)
  local shake_idx = #shake_arr - self.shake_time
  local shake = ceil((shake_arr[shake_idx] or 0) * 13)
  if self.countdown_timer then
    if self.CLOCK % 2 == 0 then
      draw(themes[config.theme].images.IMG_cursor[1],
        (self.cur_col-1)*16,
        (11-(self.cur_row))*16+self.displacement-shake)
    end
  else
    draw(themes[config.theme].images.IMG_cursor[(floor(self.CLOCK/16)%2)+1],
      (self.cur_col-1)*16,
      (11-(self.cur_row))*16+self.displacement-shake)
  end
end

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
function draw_pause()
  draw(themes[config.theme].images.pause,0,0)
  gprintf(loc("pause"), 0, 330, canvas_width, "center",nil,1,large_font)
  gprintf(loc("pl_pause_help"), 0, 360, canvas_width, "center",nil,1)
end


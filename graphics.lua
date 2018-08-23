--int Font_NumRed;
--int Font_NumBlue;

--int P1ScoreDisplay;
--int P1ScoreRender;
--int P1ScoreDigits[5];

--int GameTimeDisplay;
--int GameTimeDisplayPosX;
--int GameTimeDisplayPosY;
--int GameTimeRender;
--int GameTimeDigits[7];

--int Graphics_Ready321;

--int P1SpeedLVDisplay;
--int P1SpeedLVRender;
--int P1SpeedLVDigits[3];
--int MrStopState;
--int MrStopTimer;
--int MrStopAni[25];

--int Graphics_level;
--int Graphics_MrStop[2];
--int Graphics_Difficulty[5];

--int NumConfettis;
--#define MAXCONFETTIS     8

--int Confettis[8][5];
--#define CONFETTI_TIMER   0
--#define CONFETTI_RADIUS  1
--#define CONFETTI_ANGLE   2
--#define CONFETTI_X       3
--#define CONFETTI_Y       4
--int ConfettiAni[48];
--int ConfettiBuf[6][2];
--#define CONFETTI_STARTTIMER   40
--#define CONFETTI_STARTRADIUS 150
require("input")
require("util")

local floor = math.floor
local ceil = math.ceil
local garbage_match_time = #garbage_bounce_table

function load_img(path_and_name)
  local img
  if pcall(function () 
    img = love.image.newImageData("assets/"..(config.assets_dir or default_assets_dir).."/"..path_and_name)
  end) then 
    if config.assets_dir and config.assets_dir ~= default_assets_dir then
      print("loaded custom asset: "..config.assets_dir.."/"..path_and_name)
    end
  else
    img = love.image.newImageData("assets/"..default_assets_dir.."/"..path_and_name)
  end
  -- local w, h = img:getWidth(), img:getHeight()
  -- local wp = math.pow(2, math.ceil(math.log(w)/math.log(2)))
  -- local hp = math.pow(2, math.ceil(math.log(h)/math.log(2)))
  -- if wp ~= w or hp ~= h then
    -- local padded = love.image.newImageData(wp, hp)
    -- padded:paste(img, 0, 0)
    -- img = padded
  -- end
  local ret = love.graphics.newImage(img)
  ret:setFilter("nearest","nearest")
  return ret
end

function draw(img, x, y, rot, x_scale,y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  gfx_q:push({love.graphics.draw, {img, x*GFX_SCALE, y*GFX_SCALE,
    rot, x_scale*GFX_SCALE, y_scale*GFX_SCALE}})
end

function menu_draw(img, x, y, rot, x_scale,y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  gfx_q:push({love.graphics.draw, {img, x, y,
    rot, x_scale, y_scale}})
end

function menu_drawq(img, quad, x, y, rot, x_scale,y_scale)
  rot = rot or 0
  x_scale = x_scale or 1
  y_scale = y_scale or 1
  gfx_q:push({love.graphics.draw, {img, quad, x, y,
    rot, x_scale, y_scale}})
end

function grectangle(mode, x, y, w, h)
  gfx_q:push({love.graphics.rectangle, {mode, x, y, w, h}})
end

function gprint(str, x, y)
  gfx_q:push({love.graphics.print, {str, x, y}})
end

local _r, _g, _b, _a
function set_color(r, g, b, a)
  a = a or 255
  -- only do it if this color isn't the same as the previous one...
  if _r~=r or _g~=g or _b~=b or _a~=a then
      _r,_g,_b,_a = r,g,b,a
      gfx_q:push({love.graphics.setColor, {r, g, b, a}})
  end
end

function graphics_init()
  --Font_NumRed=LoadImage("graphics\Font_NumRed.bmp");
  --Font_NumBlue=LoadImage("graphics\Font_NumBlue.bmp");

  --GameTimeDisplay=NewImage(64,16);
  --P1ScoreDisplay=NewImage(40,16);
  --P1SpeedLVDisplay=NewImage(48,48);

  --Graphics_Ready321=LoadImage("graphics\Ready321.bmp");
  --Graphics_TIME=LoadImage("graphics\time.bmp");
  --Graphics_level=LoadImage("graphics\level.bmp");
  --for(a=0;a<2;a++) Graphics_MrStop[a]=LoadImage("graphics\MrStop"+str(a)+".bmp");
  --for(a=0;a<5;a++) Graphics_Difficulty[a]=LoadImage("graphics\diffic"+str(a)+".bmp");

  IMG_panels = {}
  for i=1,8 do
    IMG_panels[i]={}
    for j=1,7 do
      IMG_panels[i][j]=load_img("panel"..
        tostring(i)..tostring(j)..".png")
    end
  end
  IMG_panels[9]={}
  for j=1,7 do
    IMG_panels[9][j]=load_img("panel00.png")
  end

  local g_parts = {"topleft", "botleft", "topright", "botright",
                    "top", "bot", "left", "right", "face", "pop",
                    "doubleface", "filler1", "filler2", "flash",
                    "portrait"}
  IMG_garbage = {}
  for _,key in ipairs(characters) do
    local imgs = {}
    IMG_garbage[key] = imgs
    for _,part in ipairs(g_parts) do
      imgs[part] = load_img(""..key.."/"..part..".png")
    end
  end

  IMG_metal_flash = load_img("garbageflash.png")
  IMG_metal = load_img("metalmid.png")
  IMG_metal_l = load_img("metalend0.png")
  IMG_metal_r = load_img("metalend1.png")

  IMG_ready = load_img("ready.png")
  IMG_numbers = {}
  for i=1,3 do
    IMG_numbers[i] = load_img(i..".png")
  end
  IMG_cursor = {  load_img("cur0.png"),
          load_img("cur1.png")}

  IMG_frame = load_img("frame.png")
  IMG_wall = load_img("wall.png")

  IMG_cards = {}
  IMG_cards[true] = {}
  IMG_cards[false] = {}
  for i=4,66 do
    IMG_cards[false][i] = load_img("combo"
      ..tostring(floor(i/10))..tostring(i%10)..".png")
  end
  for i=2,13 do
    IMG_cards[true][i] = load_img("chain"
      ..tostring(floor(i/10))..tostring(i%10)..".png")
  end
  for i=14,99 do
    IMG_cards[true][i] = load_img("chain00.png")
  end
  IMG_character_icons = {}
  for k,name in ipairs(characters) do
    IMG_character_icons[name] = load_img(""..name.."/icon.png")
  end
  local MAX_SUPPORTED_PLAYERS = 2
  IMG_char_sel_cursors = {}
  for player_num=1,MAX_SUPPORTED_PLAYERS do
    IMG_char_sel_cursors[player_num] = {}
    for position_num=1,2 do
      IMG_char_sel_cursors[player_num][position_num] = load_img("char_sel_cur_"..player_num.."P_pos"..position_num..".png")
    end
  end
  IMG_char_sel_cursor_halves = {left={}, right={}}
  for player_num=1,MAX_SUPPORTED_PLAYERS do
    IMG_char_sel_cursor_halves.left[player_num] = {}
    for position_num=1,2 do
      local cur_width, cur_height = IMG_char_sel_cursors[player_num][position_num]:getDimensions()
      local half_width, half_height = cur_width/2, cur_height/2
      IMG_char_sel_cursor_halves["left"][player_num][position_num] = love.graphics.newQuad(0,0,half_width,cur_height,cur_width, cur_height)
    end
    IMG_char_sel_cursor_halves.right[player_num] = {}
    for position_num=1,2 do
      local cur_width, cur_height = IMG_char_sel_cursors[player_num][position_num]:getDimensions()
      local half_width, half_height = cur_width/2, cur_height/2
      IMG_char_sel_cursor_halves.right[player_num][position_num] = love.graphics.newQuad(half_width,0,half_width,cur_height,cur_width, cur_height)
    end
  end
  character_display_names = {}
  for k, original_name in ipairs(characters) do
    name_txt_file = love.filesystem.newFile("assets/"..config.assets_dir.."/"..original_name.."/name.txt")
    --print(original_name)
    open_success, err = name_txt_file:open("r")
    --if err then print(err) end
    local display_name = name_txt_file:read(name_txt_file:getSize())
    if display_name then
      character_display_names[original_name] = display_name
    else
      character_display_names[original_name] = original_name
    end
  end
  print("character_display_names: ")
  for k,v in pairs(character_display_names) do
    print(k.." = "..v)
  end
  character_display_names_to_original_names = {}
  for k,v in pairs(character_display_names) do
    character_display_names_to_original_names[v] = k
  end
  --for(a=0;a<2;a++) MrStopAni[a]=5;
  --for(a=2;a<5;a++) MrStopAni[a]=8;
  --for(a=5;a<25;a++) MrStopAni[a]=16;

  --[[file=FileOpen("graphics\timeslide.ani",FILE_READ);
  for(a=1;a<65;a++)
  {
    TimeSlideAni[a] = FileReadByte(file);
  }
  FileClose(file);
  file=FileOpen("graphics\confetti.ani",FILE_READ);
  for(a=0;a<40;a++)
  {
    ConfettiAni[a] = FileReadByte(file);
  }
  FileClose(file);--]]
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
      local draw_x = (card.x-1) * 16 + self.pos_x
      local draw_y = (11-card.y) * 16 + self.pos_y + self.displacement
          - card_animation[card.frame]
      draw(IMG_cards[card.chain][card.n], draw_x, draw_y)
  --    card.frame = card.frame + 1
  --    if(card_animation[card.frame]==nil) then
  --      self.card_q:pop()
  --    end
    else
  --    card.frame = card.frame + 1
    end
  end
end

function Stack.render(self)
  local mx,my
  if config.debug_mode then
    mx,my = love.mouse.getPosition()
    mx = mx / GFX_SCALE
    my = my / GFX_SCALE
  end
  if P1 == self then
    draw(IMG_garbage[self.character].portrait, self.pos_x, self.pos_y)
  else
    draw(IMG_garbage[self.character].portrait, self.pos_x+96, self.pos_y, 0, -1)
  end
  local shake_idx = #shake_arr - self.shake_time
  local shake = ceil((shake_arr[shake_idx] or 0) * 13)
  for row=0,self.height do
    for col=1,self.width do
      local panel = self.panels[row][col]
      local draw_x = (col-1) * 16 + self.pos_x
      local draw_y = (11-(row)) * 16 + self.pos_y + self.displacement - shake
      if panel.color ~= 0 and panel.state ~= "popped" then
        local draw_frame = 1
        if panel.garbage then
          local imgs = {flash=IMG_metal_flash}
          if not panel.metal then
            imgs = IMG_garbage[self.garbage_target.character]
          end
          if panel.x_offset == 0 and panel.y_offset == 0 then
            -- draw the entire block!
            if panel.metal then
              draw(IMG_metal_l, draw_x, draw_y)
              draw(IMG_metal_r, draw_x+16*(panel.width-1)+8,draw_y)
              for i=1,2*(panel.width-1) do
                draw(IMG_metal, draw_x+8*i, draw_y)
              end
            else
              local height, width = panel.height, panel.width
              local top_y = draw_y - (height-1) * 16
              local use_1 = ((height-(height%2))/2)%2==0
              for i=0,height-1 do
                for j=1,width-1 do
                  draw((use_1 or height<3) and imgs.filler1 or
                    imgs.filler2, draw_x+16*j-8, top_y+16*i)
                  use_1 = not use_1
                end
              end
              if height%2==1 then
                draw(imgs.face, draw_x+8*(width-1), top_y+16*((height-1)/2))
              else
                draw(imgs.doubleface, draw_x+8*(width-1), top_y+16*((height-2)/2))
              end
              draw(imgs.left, draw_x, top_y, 0, 1, height*16)
              draw(imgs.right, draw_x+16*(width-1)+8, top_y, 0, 1, height*16)
              draw(imgs.top, draw_x, top_y, 0, width*16)
              draw(imgs.bot, draw_x, draw_y+14, 0, width*16)
              draw(imgs.topleft, draw_x, top_y)
              draw(imgs.topright, draw_x+16*width-8, top_y)
              draw(imgs.botleft, draw_x, draw_y+13)
              draw(imgs.botright, draw_x+16*width-8, draw_y+13)
            end
          end
          if panel.state == "matched" then
            local flash_time = panel.initial_time - panel.timer
            if flash_time >= self.FRAMECOUNT_FLASH then
              if panel.timer > panel.pop_time then
                if panel.metal then
                  draw(IMG_metal_l, draw_x, draw_y)
                  draw(IMG_metal_r, draw_x+8, draw_y)
                else
                  draw(imgs.pop, draw_x, draw_y)
                end
              elseif panel.y_offset == -1 then
                draw(IMG_panels[panel.color][
                    garbage_bounce_table[panel.timer] or 1], draw_x, draw_y)
              end
            elseif flash_time % 2 == 1 then
              if panel.metal then
                draw(IMG_metal_l, draw_x, draw_y)
                draw(IMG_metal_r, draw_x+8, draw_y)
              else
                draw(imgs.pop, draw_x, draw_y)
              end
            else
              draw(imgs.flash, draw_x, draw_y)
            end
          end
          --this adds the drawing of state flags to garbage panels
          if config.debug_mode then
            gprint(panel.state, draw_x*3, draw_y*3)
            if panel.match_anyway ~= nil then
              gprint(tostring(panel.match_anyway), draw_x*3, draw_y*3+10)
              if panel.debug_tag then
                gprint(tostring(panel.debug_tag), draw_x*3, draw_y*3+20)
              end
            end
            gprint(panel.chaining and "chaining" or "nah", draw_x*3, draw_y*3+30)
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
          elseif self.danger_col[col] then
            draw_frame = danger_bounce_table[
              wrap(1,self.danger_timer+1+floor((col-1)/2),#danger_bounce_table)]
          else
            draw_frame = 1
          end
          draw(IMG_panels[panel.color][draw_frame], draw_x, draw_y)
          if config.debug_mode then
            gprint(panel.state, draw_x*3, draw_y*3)
            if panel.match_anyway ~= nil then
              gprint(tostring(panel.match_anyway), draw_x*3, draw_y*3+10)
              if panel.debug_tag then
                gprint(tostring(panel.debug_tag), draw_x*3, draw_y*3+20)
              end
            end
            gprint(panel.chaining and "chaining" or "nah", draw_x*3, draw_y*3+30)
          end
        end
      end
      if config.debug_mode and mx >= draw_x and mx < draw_x + 16 and
          my >= draw_y and my < draw_y + 16 then
        mouse_panel = {row, col, panel}
        draw(IMG_panels[4][1], draw_x+16/3, draw_y+16/3, 0, 0.33333333, 0.3333333)
      end
    end
  end
  draw(IMG_frame, self.pos_x-4, self.pos_y-4)
  draw(IMG_wall, self.pos_x, self.pos_y - shake + self.height*16)
  if self.mode == "puzzle" then
    gprint("Moves: "..self.puzzle_moves, self.score_x, 100)
    gprint("Frame: "..self.CLOCK, self.score_x, 130)
  else
    gprint("Score: "..self.score, self.score_x, 100)
    gprint("Speed: "..self.speed, self.score_x, 130)
    gprint("Frame: "..self.CLOCK, self.score_x, 145)
    if self.mode == "time" then
      local time_left = 120 - (self.game_stopwatch or 120)/60
      local mins = math.floor(time_left/60)
      local secs = math.ceil(time_left% 60)
      if secs == 60 then 
        secs = 0 
        mins = mins+1
      end
      gprint("Time: "..string.format("%01d:%02d",mins,secs), self.score_x, 160)
    elseif self.level then
      gprint("Level: "..self.level, self.score_x, 160)
    end
    gprint("Health: "..self.health, self.score_x, 175)
    gprint("Shake: "..self.shake_time, self.score_x, 190)
    gprint("Stop: "..self.stop_time, self.score_x, 205)
    gprint("Pre stop: "..self.pre_stop_time, self.score_x, 220)
    if config.debug_mode and self.danger then gprint("danger", self.score_x,235) end
    if config.debug_mode and self.danger_music then gprint("danger music", self.score_x, 250) end
    if config.debug_mode then
      gprint("cleared: "..(self.panels_cleared or 0), self.score_x, 265)
    end
    if config.debug_mode then
      gprint("metal q: "..(self.metal_panels_queued or 0), self.score_x, 280)
    end
    if config.debug_mode and self.input_state then
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
      gprint(inputs_to_print, self.score_x, 295)
    end
    if match_type then gprint(match_type, 375, 10) end
    if P1 and P1.game_stopwatch and tonumber(P1.game_stopwatch) then 
      gprint(frames_to_time_string(P1.game_stopwatch, P1.mode == "endless"), 385, 25)
    end
    --gprint("Player"..self.player_number, self.score_x,265)
    --gprint("Panel buffer: "..#self.panel_buffer, self.score_x, 190)
    --[[local danger = {}
    for i=1,6 do
      danger[i] = self.panels[12][i]:dangerous()
    end
    gprint("Danger: "..table.concat(map(function(x) if x then return "1" else return "0" end end, danger)), self.score_x, 205)--]]
  end
  self:draw_cards()
  self:render_cursor()
  if self.do_countdown then
    self:render_countdown()
  end
end

function scale_letterbox(width, height, w_ratio, h_ratio)
  if height / h_ratio > width / w_ratio then
    local scaled_height = h_ratio * width / w_ratio
    return 0, (height - scaled_height) / 2, width, scaled_height
  end
  local scaled_width = w_ratio * height / h_ratio
  return (width - scaled_width) / 2, 0, scaled_width, height
end

--[[
void EnqueueConfetti(int x, int y)
{
  int b, c;
  if(NumConfettis==MAXCONFETTIS)
  {
    for(c=0;c<NumConfettis;c++)
    {
      for(b=0;b<5;b++) Confettis[c][b]=Confettis[c+1][b];
    }
    NumConfettis--;
  }
  Confettis[NumConfettis][CONFETTI_TIMER]=CONFETTI_STARTTIMER;
  Confettis[NumConfettis][CONFETTI_RADIUS]=CONFETTI_STARTRADIUS;
  Confettis[NumConfettis][CONFETTI_ANGLE]=0;
  Confettis[NumConfettis][CONFETTI_X]=x;
  Confettis[NumConfettis][CONFETTI_Y]=y;
  NumConfettis++;
}

void Render_Confetti()
{
  int a, b, c;
  int r, an, t;

  for(a=0;a<NumConfettis;a++)
  {
    t=Confettis[a][CONFETTI_TIMER]-1;
    r=Confettis[a][CONFETTI_RADIUS]-ConfettiAni[t];
    an=Confettis[a][CONFETTI_ANGLE]-6;

    ConfettiBuf[0][0]=(r*cos(an))>>16;
    ConfettiBuf[0][1]=(r*sin(an))>>16;
    ConfettiBuf[1][0]=(r*cos(an+60))>>16;
    ConfettiBuf[1][1]=(r*sin(an+60))>>16;
    ConfettiBuf[2][0]=(r*cos(an+120))>>16;
    ConfettiBuf[2][1]=(r*sin(an+120))>>16;
    for(c=0;c<3;c++)
    {
      ConfettiBuf[c+3][0]=0-ConfettiBuf[c][0];
      ConfettiBuf[c+3][1]=0-ConfettiBuf[c][1];
    }
    for(c=0;c<6;c++)
    {
      ConfettiBuf[c][0]+=Confettis[a][CONFETTI_X];
      ConfettiBuf[c][1]+=Confettis[a][CONFETTI_Y];

      TBlit(ConfettiBuf[c][0],ConfettiBuf[c][1],Graphics_Confetti,screen);
    }

    if(!t)
    {
      for(c=a;c<NumConfettis;c++)
      {
        for(b=0;b<5;b++) Confettis[c][b]=Confettis[c+1][b];
      }
      NumConfettis--;
      if(a~=(NumConfettis-1)) a--;
    }
    else
    {
      Confettis[a][CONFETTI_TIMER]=t;
      Confettis[a][CONFETTI_RADIUS]=r;
      Confettis[a][CONFETTI_ANGLE]=an;
    }
  }
}--]]

function Stack.render_cursor(self)
  if self.countdown_timer then
    if self.CLOCK % 2 == 0 then
      draw(IMG_cursor[1],
        (self.cur_col-1)*16+self.pos_x-4,
        (11-(self.cur_row))*16+self.pos_y-4+self.displacement)
    end
  else
    draw(IMG_cursor[(floor(self.CLOCK/16)%2)+1],
      (self.cur_col-1)*16+self.pos_x-4,
      (11-(self.cur_row))*16+self.pos_y-4+self.displacement)
  end
end

function Stack.render_countdown(self)
  if self.do_countdown and self.countdown_CLOCK then
    local ready_x = self.pos_x + 12
    local initial_ready_y = self.pos_y 
    local ready_y_drop_speed = 6
    local countdown_x = self.pos_x + 40
    local countdown_y = self.pos_y + 64
    if self.countdown_CLOCK <= 8 then
      local ready_y = initial_ready_y + (self.CLOCK - 1) * ready_y_drop_speed
      draw(IMG_ready, ready_x, ready_y)
      if self.countdown_CLOCK == 8 then
        self.ready_y = ready_y
      end
    elseif self.countdown_CLOCK >= 9 and self.countdown_timer and self.countdown_timer > 0 then
      if self.countdown_timer >= 100 then
        draw(IMG_ready, ready_x, self.ready_y or initial_ready_y + 8 * 6)
      end
      local IMG_number_to_draw = IMG_numbers[math.ceil(self.countdown_timer / 60)]
      if IMG_number_to_draw then
        draw(IMG_number_to_draw, countdown_x, countdown_y)
      end
    end
  end
end

--[[void FadingPanels_1P(int draw_frame, int lightness)
  int col, row, panel;
  int drawpanel, draw_x, draw_y;

  for(row=0;row<12;row++)
  {
    panel=row<<3;
    for(col=0;col<6;col++)
    {
      drawpanel=P1StackPanels[panel];
      if(drawpanel)
      {
        draw_x=self.pos_x+(col<<4);
        draw_y=self.pos_y+self.displacement+(row<<4);
        GrabRegion(draw_frame<<4,0,draw_frame<<4+15,15,draw_x,draw_y,
          Graphics_Panels[drawpanel],screen);
        if(lightness~=100)
        {
          SetLucent(lightness);
          RectFill(draw_x,draw_y,draw_x+15,draw_y+15,0,screen);
          SetLucent(0);
        }
      }
      panel++;
    }
  }
}--]]


--[[
void Render_Info_1P()
{
  int col, something, draw_x;
  if(GameTimeRender)
  {
    GameTimeRender=0;
    something=GameTime;
    GameTimeDigits[0]=something/36000;
    something=something%36000;
    GameTimeDigits[1]=something/3600;
    something=something%3600;

    GameTimeDigits[2]=something/600;
    something=something%600;
    GameTimeDigits[3]=something/60;
    something=something%60;

    GameTimeDigits[4]=10;
    GameTimeDigits[5]=something/10;
    GameTimeDigits[6]=something%10;

    RectFill(0,0,64,16,rgb(255,0,255),GameTimeDisplay);

    if(GameTimeDigits[0]) draw_x=0;
    else draw_x=0-8;
    something=0;
    for(col=0;col<2;col++)
    {  if(GameTimeDigits[col])
      {  GrabRegion(GameTimeDigits[col]<<3,0,(GameTimeDigits[col]<<3)+7,15,draw_x,0,Font_NumRed,GameTimeDisplay);
        something=1;
      }
      else
      {  if(something) GrabRegion(GameTimeDigits[col]<<3,0,(GameTimeDigits[col]<<3)+7,15,draw_x,0,Font_NumRed,GameTimeDisplay);
      }
      draw_x+=8;
    }
    if(something) GrabRegion(80,0,87,15,draw_x,0,Font_NumRed,GameTimeDisplay);
    draw_x+=8;
    if(something || GameTimeDigits[2])
      GrabRegion(GameTimeDigits[2]<<3,0,(GameTimeDigits[2]<<3)+7,15,draw_x,0,Font_NumRed,GameTimeDisplay);
    draw_x+=8;
    for(col=3;col<7;col++)
    {  GrabRegion(GameTimeDigits[col]<<3,0,(GameTimeDigits[col]<<3)+7,15,draw_x,0,Font_NumRed,GameTimeDisplay);
      draw_x+=8;
    }
  }

  TBlit(48,39,GameTimeDisplay,screen);



  if(P1ScoreRender)
  {
    P1ScoreRender=0;
    something=P1Score;
    P1ScoreDigits[0]=something/10000;
    something=something%10000;
    P1ScoreDigits[1]=something/1000;
    something=something%1000;
    P1ScoreDigits[2]=something/100;
    something=something%100;
    P1ScoreDigits[3]=something/10;
    P1ScoreDigits[4]=something%10;

    RectFill(0,0,40,16,rgb(255,0,255),P1ScoreDisplay);
    draw_x=0;
    something=0;
    for(col=0;col<4;col++)
    {
      if(P1ScoreDigits[col])
      {
        GrabRegion(P1ScoreDigits[col]<<3,0,(P1ScoreDigits[col]<<3)+7,15,draw_x,0,Font_NumBlue,P1ScoreDisplay);
        something=1;
      }
      else
      {
        if(something) GrabRegion(P1ScoreDigits[col]<<3,0,(P1ScoreDigits[col]<<3)+7,15,draw_x,0,Font_NumBlue,P1ScoreDisplay);
      }
      draw_x+=8;
    }
    col=4;
    GrabRegion(P1ScoreDigits[col]<<3,0,(P1ScoreDigits[col]<<3)+7,15,draw_x,0,Font_NumBlue,P1ScoreDisplay);
  }

  TBlit(232,63,P1ScoreDisplay,screen);


  if(P1StopTime)
  {
    MrStopTimer--;
    if(MrStopTimer<=0)
    {
      MrStopTimer=MrStopAni[P1StopTime];
      if(MrStopState) MrStopState=0;
      else MrStopState=1;
      P1SpeedLVRender=1;
    }
  }
  if(P1SpeedLVRender)
  {
    RectFill(0,0,48,48,rgb(255,0,255),P1SpeedLVDisplay);
    if(P1StopTime)
    {
      Blit(0,0,Graphics_MrStop[MrStopState],P1SpeedLVDisplay);
      if(MrStopState)
      {
        P1SpeedLVDigits[0]=P1StopTime/10;
        P1SpeedLVDigits[1]=P1StopTime%10;
        GrabRegion(P1SpeedLVDigits[0]<<3,0,(P1SpeedLVDigits[0]<<3)+7,15, 0,0,Font_NumRed,P1SpeedLVDisplay);
        GrabRegion(P1SpeedLVDigits[1]<<3,0,(P1SpeedLVDigits[1]<<3)+7,15, 8,0,Font_NumRed,P1SpeedLVDisplay);
      }
    }
    else
    {
      P1SpeedLVDigits[0]=P1SpeedLV/10;
      P1SpeedLVDigits[1]=P1SpeedLV%10;
      if(P1SpeedLVDigits[0]) GrabRegion(P1SpeedLVDigits[0]<<3,0,(P1SpeedLVDigits[0]<<3)+7,15, 32,2,Font_NumBlue,P1SpeedLVDisplay);
      GrabRegion(P1SpeedLVDigits[1]<<3,0,(P1SpeedLVDigits[1]<<3)+7,15, 40,2,Font_NumBlue,P1SpeedLVDisplay);
      Blit(1,25,Graphics_level,P1SpeedLVDisplay);
      Blit(1,35,Graphics_Difficulty[P1DifficultyLV],P1SpeedLVDisplay);
    }
  }

  TBlit(224,95,P1SpeedLVDisplay,screen);
}--]]

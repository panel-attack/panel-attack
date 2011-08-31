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

local floor = math.floor

function load_img(s)
  s = love.image.newImageData(s)
  local w, h = s:getWidth(), s:getHeight()
  local wp = math.pow(2, math.ceil(math.log(w)/math.log(2)))
  local hp = math.pow(2, math.ceil(math.log(h)/math.log(2)))
  if wp ~= w or hp ~= h then
    local padded = love.image.newImageData(wp, hp)
    padded:paste(s, 0, 0)
    s = padded
  end
  local ret = love.graphics.newImage(s)
  ret:setFilter("nearest","nearest")
  return ret
end

function draw(img, x, y)
  gfx_q:push({love.graphics.draw, {img, x*GFX_SCALE, y*GFX_SCALE,
    0, GFX_SCALE, GFX_SCALE}})
end

function gprint(str, x, y)
  gfx_q:push({love.graphics.print, {str, x, y}})
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
      IMG_panels[i][j]=load_img("assets/panel"..
        tostring(i)..tostring(j)..".png")
    end
  end
  IMG_panels[9]={}
  for j=1,7 do
    IMG_panels[9][j]=load_img("assets/panel00.png")
  end

  IMG_cursor = {  load_img("assets/cur0.png"),
          load_img("assets/cur1.png")}

  IMG_frame = load_img("assets/frame.png")

  IMG_cards = {}
  IMG_cards[true] = {}
  IMG_cards[false] = {}
  for i=4,66 do
    IMG_cards[false][i] = load_img("assets/combo"
      ..tostring(floor(i/10))..tostring(i%10)..".png")
  end
  for i=2,13 do
    IMG_cards[true][i] = load_img("assets/chain"
      ..tostring(floor(i/10))..tostring(i%10)..".png")
  end
  for i=14,99 do
    IMG_cards[true][i] = load_img("assets/chain00.png")
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

function Stack.draw_cards(self)
  for i=self.card_q.first,self.card_q.last do
    local card = self.card_q[i]
    local draw_x = (card.x-1) * 16 + self.pos_x
    local draw_y = (card.y-1) * 16 + self.pos_y - card_animation[card.frame]
    draw(IMG_cards[card.chain][card.n], draw_x, draw_y)
    card.frame = card.frame + 1
    if(card.frame==card_animation.max) then
      self.card_q:pop()
    end
  end
end

function Stack.render(self)
  for row=1,self.height do
    for col=1,self.width do
      local panel = self.panels[row][col]
      if panel.color ~= 0 and panel.state ~= "popped" then
        local draw_frame = 1
        local draw_x = (col-1) * 16 + self.pos_x
        local draw_y = (row-1) * 16 + self.pos_y + self.displacement
        if panel.state == "matched" then
          if panel.timer < self.FRAMECOUNT_FLASH then
            draw_frame = 6
          else
            if panel.timer % 2 == 1 then
              draw_frame = 5
            else
              draw_frame = 1
            end
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
        elseif self.danger_col[col] and row <= self.bottom_row then
          draw_frame = danger_bounce_table[
            wrap(1,self.danger_timer+1+floor((col-1)/2),#danger_bounce_table)]
        elseif panel.state == "dimmed" then
          draw_frame = 7
        else
          draw_frame = 1
        end
        draw(IMG_panels[panel.color][draw_frame], draw_x, draw_y)
      end
    end
  end
  draw(IMG_frame, self.pos_x-4, self.pos_y-4)
  if self.mode == "puzzle" then
    gprint("Moves: "..self.puzzle_moves, self.score_x, 100)
  else
    gprint("Score: "..self.score, self.score_x, 100)
    gprint("Speed: "..self.speed, self.score_x, 130)
    if self.mode == "time" then
      local time_left = 120 - self.CLOCK/60
      local mins = floor(time_left/60)
      local secs = floor(time_left%60)
      gprint("Time: "..string.format("%01d:%02d",mins,secs), self.score_x, 145)
    end
  end
  self:draw_cards()
  self:render_cursor()
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
  draw(IMG_cursor[(floor(self.CLOCK/16)%2)+1],
    (self.cur_col-1)*16+self.pos_x-4,
    (self.cur_row-1)*16+self.pos_y-4+self.displacement)
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

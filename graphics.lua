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

--[[int TimeSlideAni[65];

int CardAni[50];
int Graphics_ComboCards;
int Graphics_ChainCards;
int ComboCardsQueue[50];
int ComboCardsQueueLength;
int ChainCards16Queue[50];
int ChainCards16QueueLength;
int ChainCards21Queue[50];
int ChainCards21QueueLength;
--]]


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


--int Graphics_Controller;
--int Graphics_Controller_Up;
--int Graphics_Controller_Down;
--int Graphics_Controller_Left;
--int Graphics_Controller_Right;
--int Graphics_Controller_ABXY;
--int Graphics_Controller_L;
--int Graphics_Controller_R;

function load_img(s)
    local ret = love.graphics.newImage(s)
    ret:setFilter("nearest","nearest")
    return ret
end

function draw(img,x,y)
    love.graphics.draw(img, x*GFX_SCALE, y*GFX_SCALE, 0, GFX_SCALE, GFX_SCALE)
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

    IMG_cursor = {  load_img("assets/cur0.png"),
                    load_img("assets/cur1.png")}

    IMG_frame = load_img("assets/frame.png")

    IMG_cards = {}
    IMG_cards[true] = {}
    IMG_cards[false] = {}
    for i=4,66 do
        IMG_cards[false][i] = load_img("assets/panel75.png")
        --IMG_cards[false][i] = load_img("assets/combo"
        --    ..tostring(math.floor(i/10))..tostring(i%10)..".png")
    end
    for i=2,13 do
        IMG_cards[true][i] = load_img("assets/panel76.png")
        --IMG_cards[true][i] = load_img("assets/chain"
        --    ..tostring(math.floor(i/10))..tostring(i%10)..".png")
    end

    --Graphics_ComboCards=LoadImage("graphics\combocards.bmp");
    --Graphics_ChainCards=LoadImage("graphics\ChainCards.bmp");


    --for(a=0;a<2;a++) MrStopAni[a]=5;
    --for(a=2;a<5;a++) MrStopAni[a]=8;
    --for(a=5;a<25;a++) MrStopAni[a]=16;

    --[[file=FileOpen("graphics\Card.ani",FILE_READ);
    for(a=0;a<TMOL;a++)
    {
        CardAni[a] = FileReadByte(file);
    }
    FileClose(file);
    file=FileOpen("graphics\timeslide.ani",FILE_READ);
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
    FileClose(file);

    Graphics_Controller=LoadImage("graphics\controller.bmp");
    Graphics_Controller_Up=LoadImage("graphics\controller_Up.bmp");
    Graphics_Controller_Down=LoadImage("graphics\controller_Down.bmp");
    Graphics_Controller_Left=LoadImage("graphics\controller_Left.bmp");
    Graphics_Controller_Right=LoadImage("graphics\controller_Right.bmp");
    Graphics_Controller_ABXY=LoadImage("graphics\controller_ABXY.bmp");
    Graphics_Controller_L=LoadImage("graphics\controller_L.bmp");
    Graphics_Controller_R=LoadImage("graphics\controller_R.bmp");--]]
end

--[[void EnqueueComboCard(int xpos, int ypos, int iofs)
{
   -- (animation frame) <<19
   -- xpos              4 bits
   -- ypos              4 bits
   -- iofs              11 bits
   ComboCardsQueue[ComboCardsQueueLength]=(xpos<<15) | (ypos<<11) | iofs;
   ComboCardsQueueLength++;
}--]]

function Stack.draw_cards(self)
    for i=self.card_q.first,self.card_q.last do
        local card = self.card_q[i]
        local draw_x = card.x * 4 + self.pos_x
        local draw_y = card.y * 4 + self.pos_y - card_animation[card.frame]
        draw(IMG_cards[card.chain][card.n], draw_x, draw_y)
        card.frame = card.frame + 1
        if(card.frame==card_animation.max) then
            self.card_q:pop()
        end
    end
end
--[[
void EnqueueChainCard(int xpos, int ypos, int hitno)
{
   -- (animation frame) <<19
   -- xpos              4 bits
   -- ypos              4 bits
   -- iofs              11 bits
   int tens, ones;
   int something;
   something=hitno;

   if(something>13)
      if(ScoreMode==SCOREMODE_TA) something=0;

   if(something<20)
   {
      ChainCards16Queue[ChainCards16QueueLength]
         =(xpos<<15) | (ypos<<11) | something;
      ChainCards16QueueLength++;
   }
   else
   {
      tens=something/10;
      ones=something-(tens*10);
      ChainCards21Queue[ChainCards21QueueLength]
         =(xpos<<15) | (ypos<<11) | (tens<<4) | ones;
      ChainCards21QueueLength++;
   }
}--]]
--[[
void DrawChainCards16()
{
   int i;
   int card, aniframe, draw_x, draw_y, hitno;
   int slide;
   for(i=0;i<ChainCards16QueueLength;i++)
   {
      card=ChainCards16Queue[i];

      aniframe=card>>19;

      draw_x=card>>15;
      draw_x=draw_x&15;
      draw_x=draw_x<<4;
      draw_x+=self.pos_x;

      draw_y=card>>11;
      draw_y=draw_y&15;
      draw_y=draw_y<<4;
      draw_y+=self.pos_y+self.displacement;
      draw_y-=CardAni[aniframe];

      hitno=card&2047;
      hitno=hitno<<4;

      TGrabRegion(hitno,0,hitno+15,15,draw_x,draw_y,Graphics_ChainCards,screen);

      aniframe++;
      if(aniframe==TMOL) slide=1;
      else ChainCards16Queue[i]+=524288;
   }
   if(slide)
   {
      for(i=0;i<ChainCards16QueueLength;i++) ChainCards16Queue[i]=ChainCards16Queue[i+1];
      ChainCards16QueueLength--;
   }
}--]]
--[[
void DrawChainCards21()
{
   int i;
   int card, aniframe, draw_x, draw_y, tens, ones;
   int slide;
   for(i=0;i<ChainCards21QueueLength;i++)
   {
      card=ChainCards21Queue[i];

      aniframe=card>>19;

      draw_x=card>>15;
      draw_x=draw_x&15;
      draw_x=draw_x<<4;
      draw_x+=self.pos_x;

      draw_y=card>>11;
      draw_y=draw_y&15;
      draw_y=draw_y<<4;
      draw_y+=self.pos_y+self.displacement;
      draw_y-=CardAni[aniframe];

      tens=card&240;
      ones=card&15;50
      ones=ones<<4;5-
      TGrabRegion(tens,16,tens+13, 31,draw_x -3,draw_y,Graphics_ChainCards,screen);
      TGrabRegion(ones,32,ones +6, 47,draw_x+11,draw_y,Graphics_ChainCards,screen);

      aniframe++;
      if(aniframe==TMOL) slide=1;
      else ChainCards21Queue[i]+=524288;
   }
   if(slide)
   {
      for(i=0;i<ChainCards21QueueLength;i++) ChainCards21Queue[i]=ChainCards21Queue[i+1];
      ChainCards21QueueLength--;
   }
}--]]

function Stack.render(self)
    self.n_active_panels = 0
    for row=0,11 do
        local idx = row * 8 + 1
        for col=0,5 do
            local panel = self.panels[idx]
            local count_this_panel = false
            if(panel.color ~= 0 and panel:exclude_hover()) or panel.is_swapping then
                self.n_active_panels = self.n_active_panels + 1
            end
            if panel.color ~= 0 and not panel.popped then
                local draw_frame = 1
                local draw_x = col * 16 + self.pos_x
                local draw_y = row * 16 + self.pos_y + self.displacement
                if panel.matched then
                    if panel.timer == nil then
                        error("one")
                    end
                    if panel.timer < self.FRAMECOUNT_FLASH then
                        draw_frame = 6
                    else
                        if panel.timer % 2 == 1 then
                            draw_frame = 5
                        else
                            draw_frame = 1
                        end
                    end
                elseif panel.popping then
                    draw_frame = 6
                elseif panel.landing then
                    draw_frame = bounce_table[panel.timer + 1]
                elseif panel.is_swapping then
                    if panel.is_swapping_from_left then
                        draw_x = draw_x - panel.timer * 4
                    else
                        draw_x = draw_x + panel.timer * 4
                    end
                elseif self.danger_col[col+1] and row <= self.bottom_row then
                    draw_frame = danger_bounce_table[self.danger_timer+1];
                elseif panel.dimmed then
                    draw_frame = 7
                else
                    draw_frame = 1
                end
                love.graphics.draw(IMG_panels[panel.color][draw_frame],
                    draw_x*GFX_SCALE, draw_y*GFX_SCALE, 0, GFX_SCALE,
                    GFX_SCALE)
            end
            idx = idx + 1
        end
    end
    love.graphics.draw(IMG_frame, (self.pos_x-4)*GFX_SCALE, (self.pos_y-4)*GFX_SCALE,
            0, GFX_SCALE, GFX_SCALE)
    love.graphics.print("Score: "..self.score, 400, 400)
    love.graphics.print("cur_timer: "..self.cur_timer, 400, 420)
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
}

void Render_Cards()
{
   DrawComboCards();
   DrawChainCards16();
   DrawChainCards21();
}--]]

function Stack.render_cursor(self)
    love.graphics.draw(IMG_cursor[(math.floor(self.CLOCK/16)%2)+1],
        (self.cur_col*16+self.pos_x-4)*GFX_SCALE,
        (self.cur_row*16+self.pos_y-4+self.displacement)*GFX_SCALE,
        0, GFX_SCALE, GFX_SCALE)
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
}



void Render_Controller()
{
   TBlit(234,165,Graphics_Controller,screen);

   if(key[Keyboard_Up])     TBlit(247,179,Graphics_Controller_Up,screen);
   if(key[Keyboard_Down])   TBlit(247,192,Graphics_Controller_Down,screen);
   if(key[Keyboard_Left])   TBlit(240,186,Graphics_Controller_Left,screen);
   if(key[Keyboard_Right])  TBlit(254,186,Graphics_Controller_Right,screen);

   if(key[Keyboard_Swap1])  TBlit(283,193,Graphics_Controller_ABXY,screen);
   if(key[Keyboard_Swap2])  TBlit(289,187,Graphics_Controller_ABXY,screen);
   if(key[Keyboard_Raise1]) TBlit(240,165,Graphics_Controller_L,screen);
   if(key[Keyboard_Raise2]) TBlit(278,165,Graphics_Controller_R,screen);

}--]]

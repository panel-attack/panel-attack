require("queue")

-- keyboard assignment vars
K = {{up="up", down="down", left="left", right="right",
      swap1="z", swap2="x", raise1="c", raise2="v"},
      {},{},{}}
key_names = {"up", "down", "left", "right", "swap1",
  "swap2", "raise1", "raise2"}
keys = {}
this_frame_keys = {}
this_frame_unicodes = {}
this_frame_messages = {}

bounce_table = {1, 1, 1, 1,
                2, 2, 2,
                3, 3, 3,
                4, 4, 4}

garbage_bounce_table = {
                        2, 2, 2,
                        3, 3, 3,
                        4, 4, 4,
                        1, 1}

danger_bounce_table = {1, 1, 1,
                       2, 2, 2,
                       3, 3, 3,
                       2, 2, 2,
                       1, 1, 1,
                       4, 4, 4}

SCOREMODE_TA    = 1
SCOREMODE_PDP64 = 2
score_mode = SCOREMODE_TA

-- score lookup tables
score_combo_PdP64 = {} --size 40
score_combo_TA = {  0,    0,    0,   20,   30,
                   50,   60,   70,   80,  100,
                  140,  170,  210,  250,  290,
                  340,  390,  440,  490,  550,
                  610,  680,  750,  820,  900,
                  980, 1060, 1150, 1240, 1330, [0]=0}

score_chain_TA = {  0,   50,   80,  150,  300,
                  400,  500,  700,  900, 1100,
                 1300, 1500, 1800, [0]=0}

GFX_SCALE = 3

card_animation = {false,
   -1, 0, 1, 2, 3, 4, 4, 5, 5, 6,
   6, 7, 7, 8, 8, 8, 9, 9, 9, 9,
   9, 10, 10, 10, 10, 10, 10, 10, 10, 10,
   10, 10, 10, 10, 10, 10, 11, 11, 11, 11,
   11}

gfx_q = Queue()

FC_HOVER = {12,  9,  6}
-- TODO: delete FC_MATCH?
--FC_MATCH = {61, 49, 37}
FC_FLASH = {44, 36, 22}
FC_FACE  = {17, 13, 15} -- idk this is just MATCH-FLASH
FC_POP   = { 9,  8,  7}
stop_time_combo =  {120, 120, 120}
stop_time_chain =  {300, 180, 120}
stop_time_danger = {600, 420, 240}

difficulty_to_ncolors_endless = {5,6,6}
difficulty_to_ncolors_1Ptime = {6,6,6}

-- Yes, 2 is slower than 1 and 50..99 are the same.
speed_to_rise_time = map(function(x) return x/16 end,
   {942, 983, 838, 790, 755, 695, 649, 604, 570, 515,
    474, 444, 394, 370, 347, 325, 306, 289, 271, 256,
    240, 227, 213, 201, 189, 178, 169, 158, 148, 138,
    129, 120, 112, 105,  99,  92,  86,  82,  77,  73,
     69,  66,  62,  59,  56,  54,  52,  50,  48,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47})

-- endless and 1P time attack use a speed system in which
-- speed increases based on the number of panels you clear.
-- For example, to get from speed 1 to speed 2, you must
-- clear 9 panels.
--
-- Values past 51 weren't measured because all the speeds
-- after that are the same anyway.
panels_to_next_speed =
  {9, 12, 12, 12, 12, 12, 15, 15, 18, 18,
  24, 24, 24, 24, 24, 24, 21, 18, 18, 18,
  36, 36, 36, 36, 36, 36, 36, 36, 36, 36,
  39, 39, 39, 39, 39, 39, 39, 39, 39, 39,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
  45, 45, 45, 45, 45, 45, 45, 45, math.huge}

-- vs mode and 2P time attack use a speed system in which
-- speed increases every 15 seconds.  However, instead of
-- exposing speed and difficulty directly, they expose levels.
-- A level is a speed, a difficulty, and an amount of time
-- that can be spent at the top of the screen without dying.
-- level also determines the number of colors
level_to_starting_speed    = {  1,  5,  9, 13, 17, 21, 25, 29, 27, 32}
--level_to_difficulty        = {  1,  1,  2,  2,  2,  2,  2,  3,  3,  3}
level_to_hang_time         = {121,100, 80, 65, 50, 40, 30, 20, 10,  1}
level_to_ncolors_vs        = {  5,  5,  5,  5,  5,  5,  5,  5,  6,  6}
level_to_ncolors_time      = {  5,  5,  6,  6,  6,  6,  6,  6,  6,  6}
level_to_hover             = { 12, 12, 11, 10,  9,  6,  5,  4,  3,  6}
level_to_pop               = {  9,  9,  8,  8,  8,  8,  8,  7,  7,  7}
level_to_flash             = { 44, 44, 42, 42, 38, 36, 34, 32, 30, 28}
level_to_face              = { 15, 14, 14, 13, 12, 11, 10, 10,  9,  8}
level_to_combo_constant    = {-20,-16,-12, -8, -3,  2,  7, 12, 17, 22}
level_to_combo_coefficient = { 20, 18, 16, 14, 12, 10,  8,  6,  4,  2}
level_to_chain_constant    = { 80, 77, 74, 71, 68, 65, 62, 60, 58, 56}
level_to_chain_coefficient = { 20, 18, 16, 14, 12, 10,  8,  6,  4,  2}



-- Stage clear seems to use a variant of vs mode's speed system,
-- except that the amount of time between increases is not constant.
-- on stage 1, the increases occur at increments of:
-- 20, 15, 15, 15, 10, 10, 10

-- The following are level settings for vs cpu:
-- vs easy cpu -> vs level 2 for all levels
-- vs normal cpu -> vs level 4 for all levels
-- vs hard cpu -> vs level 6 for all levels
-- vs vhard cpu -> vs level 6 for all levels

combo_garbage = {{}, {}, {}, {3}, {4},
              {5}, {6}, {3,4}, {4,4}, {5,5},
              {5,6}, {6,6}, {6,6,6}, {6,6,6,6},
              [20]={6,6,6,6,6,6},
              [27]={6,6,6,6,6,6,6,6}}
for i=1,72 do
  combo_garbage[i] = combo_garbage[i] or combo_garbage[i-1]
end

characters = {"lip", "windy", "sherbet", "thiana", "ruby",
              "elias", "flare", "neris", "seren", "phoenix", "dragon", "thanatos", "cordelia", 
              "lakitu", "bumpty", "poochy", "wiggler", "froggy", "blargg",
              "lungefish", "raphael", "yoshi", "hookbill",
              "navalpiranha", "kamek", "bowser"}
stages = {}
stages["lip"] = "flower"
stages["windy"] = "wind"
stages["sherbet"] = "ice"
stages["thiana"] = "forest"
stages["ruby"] = "jewel"
stages["elias"] = "water"
stages["flare"] = "fire"
stages["neris"] = "sea"
stages["seren"] = "moon"
stages["phoenix"] = "cave"
stages["dragon"] = "cave"
stages["thanatos"] = "king"
stages["cordelia"] = "cordelia"
stages["lakitu"] = "wind"
stages["bumpty"] = "ice"
stages["poochy"] = "forest"
stages["wiggler"] = "jewel"
stages["froggy"] = "water"
stages["blargg"] = "fire"
stages["lungefish"] = "sea"
stages["raphael"] = "moon"
stages["yoshi"] = "yoshi"
stages["hookbill"] = "cave"
stages["navalpiranha"] = "cave"
stages["kamek"] = "cave"
stages["bowser"] = "king"

shake_arr = {}

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

print("#shake arr "..#shake_arr)

-- 1 -> 1
-- #shake -> 0
local shake_step = 1/(#shake_arr - 1)
local shake_mult = 1
for i=1,#shake_arr do
  shake_arr[i] = shake_arr[i] * shake_mult
  print(shake_arr[i])
  shake_mult = shake_mult - shake_step
end

garbage_to_shake_time = {
  [0] = 0,
  18, 18, 18, 18, 24, 42, 42, 42, 42, 42,
  42, 66, 66, 66, 66, 66, 66, 66, 66, 66,
  66, 66, 66, 76
}

for i=25,1000 do
  garbage_to_shake_time[i] = garbage_to_shake_time[i-1]
end

colors = {  red     = {220, 50,  47 },
            orange  = {255, 140, 0  },
            green   = {80,  169, 0  },
            purple  = {168, 128, 192},
            blue    = {38,  139, 210},
            pink    = {211, 68,  134},
            white   = {234, 234, 234},
            black   = {20,  20,  20 },
            dgray   = {28,  28,  28 }}
            
panel_color_number_to_upper = {"A", "B", "C", "D", "E", "F", "G", "H",[0]="0"}
panel_color_number_to_lower = {"a", "b", "c", "d", "e", "f", "g", "h",[0]="0"}
panel_color_to_number = { ["A"]=1, ["B"]=2, ["C"]=3, ["D"]=4, ["E"]=5, ["F"]=6, ["G"]=7, ["H"]=8,
                          ["a"]=1, ["b"]=2, ["c"]=3, ["d"]=4, ["e"]=5, ["f"]=6, ["g"]=7, ["h"]=8,
                          ["1"]=1, ["2"]=2, ["3"]=3, ["4"]=4, ["5"]=5, ["6"]=6, ["7"]=7, ["8"]=8,
                          ["0"]=0}
                                
--how many panels you have to pop to earn a metal panel in your next row.
level_to_metal_panel_frequency = {12, 14, 16, 19, 23, 26, 29, 33, 37, 41}
            
-- win counters
my_win_count = 0
op_win_count = 0

--sounds: SFX, music
SFX_Fanfare_Play = 0
SFX_GameOver_Play = 0
SFX_GarbageThud_Play = 0
sounds = {
  SFX = {
    cur_move = love.audio.newSource("sounds/SFX/06move.ogg", "static"),
    swap = love.audio.newSource("sounds/SFX/08swap.ogg", "static"),
    land = love.audio.newSource("sounds/SFX/12cLand.ogg", "static"),
    fanfare1 = love.audio.newSource("sounds/SFX/F6Fanfare1.ogg", "static"),
    fanfare2 = love.audio.newSource("sounds/SFX/F7Fanfare2.ogg", "static"),
    fanfare3 = love.audio.newSource("sounds/SFX/F8Fanfare3.ogg", "static"),
    game_over = love.audio.newSource("sounds/SFX/0DGameOver.ogg", "static"),
    garbage_thud = {
      love.audio.newSource("sounds/SFX/Thud_1.ogg"),
      love.audio.newSource("sounds/SFX/Thud_2.ogg"),
      love.audio.newSource("sounds/SFX/Thud_3.ogg")
    },
    character = {},
    pops = {}
  },
  music = {
    character_normal = {},
    character_danger = {}
  }
}
for i,name in ipairs(characters) do
    sounds.SFX.character[name] = love.audio.newSource("sounds/character_SFX/"..name..".ogg", "static")
end
for i,name in ipairs(characters) do
    sounds.music.character_normal[name] = love.audio.newSource("sounds/Music/"..stages[name].."_normal.it")
end
for i,name in ipairs(characters) do
    sounds.music.character_danger[name] = love.audio.newSource("sounds/Music/"..stages[name].."_danger.it")
end
for popLevel=1,4 do
    sounds.SFX.pops[popLevel] = {}
    for popIndex=1,10 do
        sounds.SFX.pops[popLevel][popIndex] = love.audio.newSource("sounds/SFX/pop"..popLevel.."-"..popIndex..".ogg", "static")
    end
end
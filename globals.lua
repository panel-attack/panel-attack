-- keyboard assignment vars
k_up = "up"
k_down = "down"
k_left = "left"
k_right = "right"
k_swap1 = "z"
k_swap2 = "x"
k_raise1 = "c"
k_raise2 = "v"
key_names = {"k_up", "k_down", "k_left", "k_right", "k_swap1",
  "k_swap2", "k_raise1", "k_raise2"}
keys = {}
this_frame_keys = {}

bounce_table = {1, 1, 1, 1,
                2, 2, 2,
                3, 3, 3,
                4, 4, 4}

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

card_animation = {0, 1, 2, 3, 4, 5, 6, 6, 7, 7,
  8, 8, 9, 9, 10, 10, 10, 11, 11, 11,
  11, 11, 13, 13, 13, 13, 13, 13, 13, 13,
  13, 13, 13, 13, 13, 13, 13, 15, 15, 15,
  15, 15}
card_animation.max = 43

gfx_q = Queue()

FC_HOVER = {12,  9,  6}
FC_MATCH = {61, 50, 37}
FC_FLASH = {16, 13,  8}
FC_POP   = { 9,  8,  7}
stop_time_combo =  { 2, 2, 2}
stop_time_chain =  { 5, 3, 2}
stop_time_danger = {10, 7, 4}

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
level_to_starting_speed = {  1,  5,  9, 13, 17, 21, 25, 29, 27, 32}
level_to_difficulty     = {  1,  1,  2,  2,  2,  2,  2,  3,  3,  3}
level_to_hang_time      = {121,100, 80, 65, 50, 40, 30, 20, 10,  1}
level_to_ncolors_vs     = {  5,  5,  5,  5,  5,  5,  5,  5,  6,  6}
level_to_ncolors_time   = {  5,  5,  6,  6,  6,  6,  6,  6,  6,  6}


-- Stage clear seems to use a variant of vs mode's speed system,
-- except that the amount of time between increases is not constant.
-- on stage 1, the increases occur at increments of:
-- 20, 15, 15, 15, 10, 10, 10

-- The following are level settings for vs cpu:
-- vs easy cpu -> vs level 2 for all levels
-- vs normal cpu -> vs level 4 for all levels
-- vs hard cpu -> vs level 6 for all levels
-- vs vhard cpu -> vs level 6 for all levels

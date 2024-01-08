require("util")
local tableUtils = require("tableUtils")

--- @module consts
local consts = {
  VERSION = "047",
  CANVAS_WIDTH = 1280,
  CANVAS_HEIGHT = 720,
  DEFAULT_THEME_DIR = "Panel Attack",
  RANDOM_CHARACTER_SPECIAL_VALUE = "__RandomCharacter",
  RANDOM_STAGE_SPECIAL_VALUE = "__RandomStage",
  DEFAULT_INPUT_REPEAT_DELAY = 20,
  MOUSE_POINTER_TIMEOUT = 1.5, --seconds
  KEY_NAMES = {"Up", "Down", "Left", "Right", "Swap1", "Swap2", "TauntUp", "TauntDown", "Raise1", "Raise2", "Start"},
  FRAME_RATE = 1 / 60,
  KEY_DELAY = .25,
  KEY_REPEAT_PERIOD = .05,
  MENU_PADDING = 10
}

-- TODO: Move all values below to the above table or to other files if they are only used in 1

-- The values in this file are constants (except in this file perhaps) and are expected never to change during the game, not to be confused with globals!

consts.ENGINE_VERSIONS = {}
consts.ENGINE_VERSIONS.PRE_TELEGRAPH = "045"
consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE = "046"
consts.ENGINE_VERSIONS.TOUCH_COMPATIBLE = "047"
consts.ENGINE_VERSIONS.LEVELDATA = "048"

VERSION = consts.ENGINE_VERSIONS.TOUCH_COMPATIBLE -- The current engine version
VERSION_MIN_VIEW = consts.ENGINE_VERSIONS.TELEGRAPH_COMPATIBLE -- The lowest version number that can be watched

consts.COUNTDOWN_CURSOR_SPEED = 4 --one move every this many frames
consts.COUNTDOWN_START = 8
consts.COUNTDOWN_LENGTH = 180 --3 seconds at 60 fps

consts.SERVER_SAVE_DIRECTORY = "servers/"
consts.LEGACY_SERVER_LOCATION = "18.188.43.50"
consts.SERVER_LOCATION = "panelattack.com"

canvas_width = 1280
canvas_height = 720

global_background_color = { 0.0, 0.0, 0.0 }

mouse_pointer_timeout = 1.5 --seconds
RATING_SPREAD_MODIFIER = 400 -- rating players must be within to play ranked

super_selection_duration = 30 -- frames (reminder: 60 frames per sec)
super_selection_enable_ratio = 0.3 -- ratio at which super enable is considered started (cancelling it won't validate a character)
assert(super_selection_enable_ratio<1.0,"")

prefix_of_ignored_dirs = "__"

consts.DEFAULT_THEME_DIRECTORY = "Panel Attack Modern"

default_characters_folders = {"lip", "windy", "sherbet", "thiana", "ruby",
              "elias", "flare", "neris", "seren", "phoenix", 
              "dragon", "thanatos", "cordelia",  "lakitu", 
              "bumpty", "poochy", "wiggler", "froggy", "blargg",
              "lungefish", "raphael", "yoshi", "hookbill",
              "navalpiranha", "kamek", "bowser"}

default_stages_folders = {"cave", "fire", "flower", "forest", "ice",
              "jewel", "king", "moon", "sea", "water", "wind" }

random_stage_special_value = "__RandomStage"
random_character_special_value = "__RandomCharacter"

default_input_repeat_delay = 20

large_font = 10 -- large font base+10
small_font = -3 -- small font base-3

-- frames to use for bounce animation
bounce_table = {1, 1, 1, 1,
                2, 2, 2,
                3, 3, 3,
                4, 4, 4}

-- frames to use for garbage bounce animation
garbage_bounce_table = {2, 2, 2,
                        3, 3, 3,
                        4, 4, 4,
                        1, 1}

-- frames to use for in danger animation
danger_bounce_table = {1, 1, 1,
                       2, 2, 2,
                       3, 3, 3,
                       2, 2, 2,
                       1, 1, 1,
                       4, 4, 4}

SCOREMODE_TA    = 1
SCOREMODE_PDP64 = 2 -- currently not used

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

-- frames to use for the card animation
card_animation = {false,
   -1, 0, 1, 2, 3, 4, 4, 5, 5, 6,
   6, 7, 7, 8, 8, 8, 9, 9, 9, 9,
   9, 10, 10, 10, 10, 10, 10, 10, 10, 10,
   10, 10, 10, 10, 10, 10, 11, 11, 11, 11,
   11}

-- The popping particle animation. First number is how far the particles go, second is which frame to show from the spritesheet
 popfx_burst_animation = {{1, 1}, {4, 1}, {7, 1}, {8, 1},
    {9, 1}, {9, 1}, {10, 1}, {10, 2}, {10, 2}, {10, 3},
    {10, 3}, {10, 4}, {10, 4}, {10, 5}, {10, 5}, {10, 6}, {10, 6}, {10, 7}, {10, 7}, {10, 8}, {10, 8}, {10, 8}}

  popfx_fade_animation = {1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8}

TIME_ATTACK_TIME = 120
-- Yes, 2 is slower than 1 and 50..99 are the same.
speed_to_rise_time = tableUtils.map(
   {942, 983, 838, 790, 755, 695, 649, 604, 570, 515,
    474, 444, 394, 370, 347, 325, 306, 289, 271, 256,
    240, 227, 213, 201, 189, 178, 169, 158, 148, 138,
    129, 120, 112, 105,  99,  92,  86,  82,  77,  73,
     69,  66,  62,  59,  56,  54,  52,  50,  48,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47,  47,
     47,  47,  47,  47,  47,  47,  47,  47,  47},
     function(x) return x/16 end)

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

-- Stage clear seems to use a variant of vs mode's speed system,
-- except that the amount of time between increases is not constant.
-- on stage 1, the increases occur at increments of:
-- 20, 15, 15, 15, 10, 10, 10

-- The following are level settings for vs cpu in:
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

colors = {  red     = {220/255, 50/255,  47/255 },
            orange  = {255/255, 140/255, 0/255  },
            green   = {80/255,  169/255, 0/255  },
            purple  = {168/255, 128/255, 192/255},
            blue    = {38/255,  139/255, 210/255},
            pink    = {211/255, 68/255,  134/255},
            white   = {234/255, 234/255, 234/255},
            black   = {20/255,  20/255,  20/255 },
            dgray   = {28/255,  28/255,  28/255 }}

e_chain_or_combo = { combo=0, chain=1, shock=2 }

garbage_to_shake_time = {
  [0] = 0,
  18, 18, 18, 18, 24, 42, 42, 42, 42, 42,
  42, 66, 66, 66, 66, 66, 66, 66, 66, 66,
  66, 66, 66, 76
}

for i=25,1000 do
  garbage_to_shake_time[i] = garbage_to_shake_time[i-1]
end

return consts
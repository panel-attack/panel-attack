--int Input_DirPressed =   -- last dir pressed

-- keyboard assignment vars
k_up = "up"
k_down = "down"
k_left = "left"
k_right = "right"
k_swap1 = "z"
k_swap2 = "z"
k_raise1 = "x"
k_raise2 = "x"
keys = {k_up=false, k_down=false, k_left=false, k_right=false, k_swap1=false,
    k_swap2=false, k_raise1=false, k_raise2=false}
keys.protect_raise = false

bounce_table = {1, 1, 1, 1,
                2, 2, 2,
                3, 3, 3,
                4, 4, 4}

danger_bounce_table = { 1, 1, 1,
                        2, 2, 2,
                        3, 3, 3,
                        2, 2, 2,
                        1, 1, 1,
                        4, 4, 4}

IMG_panels = nil
IMG_cursor = nil
IMG_frame = nil

VEASY  = 1
EASY   = 2
NORMAL = 3
HARD   = 4
VHARD  = 5

TIME_ELAPSED = 1
TIME_REMAINING = 2
-- TODO: what the fuck are these for ^

score_mode = 1
SCOREMODE_TA    = 1
SCOREMODE_PDP64 = 2

DIR_UP    = 1
DIR_DOWN  = 2
DIR_LEFT  = 3
DIR_RIGHT = 4

 -- score lookup tables
score_combo_PdP64 = {} --size 40
score_combo_TA = {} --size 31
score_chain_TA = {} --size 14
 -- TODO: figure out how to initialize these.

for i=0,39 do
    score_combo_PdP64[i] = 0
end
for i=0,30 do
    score_combo_TA[i] = 0
end
for i=0,13 do
    score_chain_TA[i] = 0
end

GFX_SCALE = 3

crash_now = false
crash_error = nil

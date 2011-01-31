swap_1_pressed = false
swap_2_pressed = false
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

P1_spos_x = 4   -- Position of the play area on the screen
P1_spos_y = 4

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


-- The stack of panels.
P1_panels = {}
    --int P1_panels[96];
    -- Twelve rows of 8 ints each, the first 6 representing
    -- the panels on that row.
    -- A panel's color can be retrieved using P1Stack[row<<3+col]

    -- Stack displacement.
P1_displacement = 0
    -- This variable indicates how far below the top of the play
    -- area the top row of panels actually is.
    -- This variable being decremented causes the stack to rise.
    -- During the automatic rising routine, if this variable is 0,
    -- it's reset to 15, all the panels are moved up one row,
    -- and a new row is generated at the bottom.
    -- Only when the displacement is 0 are all 12 rows "in play."

do_matches_check = false
    -- if this is true a matches-check will occur for this frame.

P1_danger_col = {false,false,false,false,false,false}
    -- set true if this column is near the top
P1_danger_timer = 0   -- decides bounce frame when in danger

P1_difficulty = 3
VEASY  = 1
EASY   = 2
NORMAL = 3
HARD   = 4
VHARD  = 5

P1_speed = 100   -- The player's speed level decides the amount of time
                 -- the stack takes to rise automatically
P1_rise_timer = 1   -- When this value reaches 0, the stack will rise a pixel
P1_rise_lock = false   -- If the stack is rise locked, it won't rise until it is
                  -- unlocked.
P1_has_risen = false   -- set once the stack rises once during the game

P1_stop_time = 0
P1_stop_time_timer = 0
stop_time_combo = {{0,0,0,0,0},{0,0,0,0,0}}
stop_time_chain = {{0,0,0,0,0},{0,0,0,0,0}}

game_time = 0
game_time_mode = 1
game_time_timer = 0
TIME_ELAPSED = 1
TIME_REMAINING = 2
-- TODO: what the fuck are these for ^

score_mode = 1
SCOREMODE_TA    = 1
SCOREMODE_PDP64 = 2

P1_NCOLORS = 5
P1_score = 0         -- der skore
P1_chain_counter = 0   -- how high is the current chain?
                        -- Hah! I knew there could only be one chain.

   -- The following variables keep track of stuff:
bottom_row = 0   -- row number of the bottom row that's "in play"
panels_in_top_row = false  -- boolean, panels in the top row (danger)
panels_in_second_row = false -- changes music state

n_active_panels = 0
n_chain_panels= 0

   -- These change depending on the difficulty and speed levels:
FRAMECOUNT_HOVER = 9
FRAMECOUNT_MATCH = 50
FRAMECOUNT_FLASH = 13
FRAMECOUNT_POP = 8
FRAMECOUNT_RISE = 80

P1_rise_timer = FRAMECOUNT_RISE





   -- Player input stuff:
P1_manual_raise = false   -- set until raising is completed
P1_manual_raise_yet = false  -- if not set, no actual raising's been done yet
                       -- since manual raise button was pressed
P1_prevent_manual_raise = false
P1_swap_1 = false   -- attempt to initiate a swap on this frame
P1_swap_2 = false

P1_cur_wait_time = 90   -- number of ticks to wait before the cursor begins
                     -- to move quickly... it's based on P1CurSensitivity
P1_cur_timer = 0   -- number of ticks for which a new direction's been pressed
P1_cur_dir = 0     -- the direction pressed
P1_cur_row = 0  -- the row the cursor's on
P1_cur_col = 0  -- the column the left half of the cursor's on

DIR_UP    = 1
DIR_DOWN  = 2
DIR_LEFT  = 3
DIR_RIGHT = 4

P1_move_sound = false  -- this is set if the cursor movement sound should be played

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

P1_game_over = false


GFX_SCALE = 3

crash_now = false
crash_error = nil
CLOCK = 0

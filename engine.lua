   -- Stuff defined in this file:
   --  . the data structures that store the configuration of
   --    the stack of panels
   --  . the main game routine
   --    (rising, timers, falling, cursor movement, swapping, landing)
   --  . the matches-checking routine

Panel = class(function(p)
        -- color 0 is an empty panel.
        -- colors 1-6 are normal colors (6 is dark blue)
        p.color = 0
        -- A panel's timer indicates for how many more frames it will:
        --  . be swapping
        --  . sit in the MATCHED state before being set POPPING
        --  . sit in the POPPING state before actually being POPPED
        --  . sit and be POPPED before disappearing for good
        --  . hover before FALLING
        -- depending on which one of these flags is set on the panel.
        p.timer = 0
        -- is_swapping is set if the panel is swapping.
        -- The panel's timer then counts down from 3 to 0,
        -- causing the swap to end 3 frames later.
        -- The timer is also used to offset the panel's
        -- position on the screen.
        --  is_swapping_from_left indicates from which direction the panel
        --  is swapping:
        --   f - from right
        --   t - from left
        p.is_swapping = false
        p.is_swapping_from_left = false
        -- In some cases a swapping panel shouldn't be allowed to swap
        -- again until it's done with the swapping it's doing already.
        -- In these cases dont_swap should be set.
        p.dont_swap = false
        -- This flag is set when a panel's matched, then its timer counts
        -- down until it reaches 0, at which time it will become popping
        p.matched = false
        -- Popping.  All the panels in a match become popping at once,
        -- but their timers for remaining in this state will be higher
        -- depending on their place in the match (FLAG_MATCHINDEX).
        p.popping = false
        -- This flag indicates that panel has popped, but it's still
        -- there until the last panel in the match pops.  When
        -- its timer reaches 0 the panel is GONE!
        p.popped = false
        -- This panel is floating and cannot be touched until
        -- its timer reaches 0 and it begins to fall.
        p.hovering = false
        p.falling = false
        -- A match made with a chain panel is a chain match...
        -- Chain panels are de-flagged during the match-checking
        -- routine, if they are eligible for a match but didn't make
        -- one, and also are not sitting on top of a hovering or
        -- swapping panel.  The chain flag must remain set on the panel
        -- until it pops.
        p.chaining = false
        -- This panel is on the bottom row and isn't in play.
        p.dimmed = false
        -- A panel that landed just recently.  This flag is set
        -- so that the timer can be used to index the correct
        -- frame to be drawn for the panel (the 'bounce' effect).
        -- These next definitions exclude panels in certain states
        -- from being acted upon in certain ways.
        p.landing = false

        -- And finally, each panel has a couple tags.
        -- Unlike the timers and flags, they don't need to be cleared
        -- when their data is no longer valid, because they should
        -- only be checked when the data is surely valid.
        p.combo_index = 0
        p.combo_size = 0
        p.chain_index = 0

        -- matching is for use in the match detection function and gets
        -- reset every frame.
        -- this should not be confused with matched, which is a flag
        -- that persists between frames.
        p.matching = false
    end)

function Panel.exclude_hover(self)
    return self.matched or self.popping or self.popped or self.hovering
            or self.falling
end

function Panel.exclude_match(self)
    return self.swapping or self.matched or self.popping or self.popped
            or self.hovering or self.dimmed or self.falling
end

function Panel.exclude_swap(self)
    return self.matched or self.popping or self.popped or self.hovering
            or self.dimmed or self.dont_swap
end

function Panel.has_flags(self)
    return self.is_swapping or self.is_swapping_from_left or self.dont_swap or
            self.matched or self.popping or self.popped or self.hovering or
            self.falling or self.chaining or self.dimmed or self.landing
end

function Panel.clear_flags(self)
    self.is_swapping = false
    self.is_swapping_from_left = false
    self.dont_swap = false
    self.matched = false
    self.popping = false
    self.popped = false
    self.hovering = false
    self.falling = false
    self.chaining = false
    self.dimmed = false
    self.landing = false
end

-- The stack of panels.

P1_panels = {}
for i=1,96 do
    P1_panels[i] = Panel()
end
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

P1_difficulty = 0
VEASY  = 1
EASY   = 2
NORMAL = 3
HARD   = 4
VHARD  = 5

P1_speed = 0   -- The player's speed level decides the amount of time
                 -- the stack takes to rise automatically
P1_rise_timer = 0   -- When this value reaches 0, the stack will rise a pixel
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
FRAMECOUNT_HOVER = 0
FRAMECOUNT_MATCH = 0
FRAMECOUNT_FLASH = 0
FRAMECOUNT_POP = 0
FRAMECOUNT_RISE = 0





   -- Player input stuff:
P1_manual_raise = false   -- set until raising is completed
P1_manual_raise_yet = false  -- if not set, no actual raising's been done yet
                       -- since manual raise button was pressed
P1_prevent_manual_raise = false
P1_swap_1 = false   -- attempt to initiate a swap on this frame
P1_swap_2 = false

P1_cur_wait_time = 0   -- number of ticks to wait before the cursor begins
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



   -- The engine routine.
function PdP()
      -- The main game routine has five phases:
      --  1. Decrement timers, act on expired ones
      --  2. Move falling panels down a row
      --  3. Do things according to player input
      --  4. Make falling panels land
      --  5. Possibly do a matches-check

      -- During these phases the entire StackPanels will be examined
      -- several times, from first to last (or last to first).
      -- Here are defined the necessary counters for iterating through
      -- the StackPanels and StackTimers:
    local row = 0
    local col = 0       -- used for iterating through the StackPanels
    local panel = 0      -- used when row and col are avoidable
    local counter = 0    -- an extra general-purpose counter

      -- other general-purpose things:
    local whatever = 0
    local something = 0
    local something_else = 0

    if(P1_stop_time ~= 0) then
        P1_stop_time_timer = P1_stop_time_timer - 1
        if(P1_stop_time_timer == 0) then
            P1_stop_time = P1_stop_time - 1
            if(P1_stop_time ~= 0) then P1_stop_time_timer=60 end
        end
    end


    if(P1_displacement ~= 0) then
        bottom_row=10
    else
        bottom_row=11   -- the 12th row (row 11) is only "in play"
    end                  -- when the stack displacement is 0
                        -- and there are panels in the top row

      -- count the number of panels in the top row (danger)
    panels_in_top_row = false
    for panel=1,6 do
        if(P1_panels[panel]) then
            panels_in_top_row = true
            P1_danger_col[panel] = 1
        else
            P1_danger_col[panel] = 0
        end
    end
    if(panels_in_top_row) then
        if(P1_stop_time == 0) then
            P1_danger_timer = P1_danger_timer - 1
            if(P1_danger_timer<0) then P1_danger_timer=17 end
        end
    end

    panels_in_second_row = false
    for panel=9,14 do
        if(P1_panels[panel] ~= 0) then
            panels_in_second_row = true
        end
    end
    --[[
    if(panels_in_second_row) then
        if(GameMusicState=MUSIC_NORMAL) then
         GameMusicState=MUSIC_DANGER
         GameMusicStateChange=1
        end
    else
        if(GameMusicState=MUSIC_DANGER) then
            GameMusicState=MUSIC_NORMAL
            GameMusicStateChange=1
        end
    end]]--
    --TODO: what the fuck are you talking about, "Game music?"

    if((P1_displacement == 0) and P1_has_risen) then
        if(not panels_in_top_row) then
            new_row()
        end
    end

    if( n_active_panels ~= 0 ) then P1_rise_lock = true
    else P1_rise_lock = false end

    if((P1_displacement == 0) and panels_in_top_row and (not P1_rise_lock) and
            (P1_stop_time == 0)) then
        P1_game_over = true
    end

    -- Phase 0 //////////////////////////////////////////////////////////////
    -- Stack automatic rising


    if((P1_speed ~= 0) and (not P1_manual_raise)) then --only rise if speed nonzero
        if((P1_stop_time == 0) and (not P1_rise_lock)) then
            P1_rise_timer = P1_rise_timer - 1
            if(P1_rise_timer == 0) then  -- try to rise
                if(P1_displacement == 0) then
                    if(P1_has_risen or panels_in_top_row) then
                        --P1_game_over=1;
                        P1_has_risen = P1_has_risen -- do nothing
                    else
                        new_row()
                        P1_displacement = 15
                        P1_has_risen = true
                    end
                else
                    P1_displacement = P1_displacement - 1
                    if(P1_displacement == 0) then
                        P1_prevent_manual_raise = false
                        if(panels_in_top_row) then
                            for panel=89,94 do
                                P1_panels[panel].dimmed = false
                            bottom_row=11;
                            end
                        else
                            new_row();
                        end
                    end
                end
                P1_rise_timer=FRAMECOUNT_RISE;
            end
        end
    end

      -- Phase 1 . ///////////////////////////////////////////////////////
      --  Falling

    for row=bottom_row,0,-1 do
        panel=row*8+1
        for col=1,6 do
            if(P1_panels[panel].falling) then
               -- if there's no panel below a falling panel,
               -- it must fall one row.
               -- I'm gonna assume there's no panel below,
               -- because the falling panel should've landed on
               -- it during the last frame if there was.
                P1_panels[panel+8] = P1_panels[panel]
                P1_panels[panel+8].timer = 0
                P1_panels[panel] = Panel()
               -- the timer can be left behind because it should be 0.
               -- the tags can be left behind because they're not important
               -- until a panel is stuck in position.
            end
            panel = panel + 1
        end
    end



      -- Phase 2. /////////////////////////////////////////////////////////////
      --  Timer-expiring actions


    for row=bottom_row,0,-1 do
        panel=row/8+1
        for col=1,6 do
            -- first of all, we do Nothin' if we're not even looking
            -- at a space with any flags.
            if(P1_panels[panel].has_flags()) then
                if(P1_panels[panel].timer ~= 0) then
                    P1_panels[panel].timer = P1_panels[panel].timer - 1;
                    if(P1_panels[panel].timer == 0) then
                        if(P1_panels[panel].swapping) then
                            -- a swap has completed here.
                            P1_panels[panel].swapping = false
                            P1_panels[panel].dontswap = false
                            if(P1_panels[panel].is_swapping_from_left) then
                                P1_panels[panel].is_swapping_from_left = false
                                something = 1
                            else something = 0 end
                            -- Now there are a few cases where some hovering must
                            -- be done.
                            if(P1_panels[panel].color ~= 0) then
                                --TODO: both of these are 0-indexed, right?
                                if(row~=bottom_row) then
                                    if(P1_panels[panel+8].color == 0) then
                                        set_hoverers_2(panel,FRAMECOUNT_HOVER,false)
                                        -- if there is no panel beneath this panel
                                        -- it will begin to hover.
                            -- CRAZY BUG EMULATION:
                            -- the space it was swapping from hovers too
                                        if(something ~= 0) then
                                            if(P1_panels[panel-1].falling) then
                                                set_hoverers_2(panel-1,FRAMECOUNT_HOVER,false)
                                            end
                                        else
                                            if(P1_panels[panel+1].falling) then
                                                set_hoverers(panel+1,FRAMECOUNT_HOVER+1,false)
                                            end
                                        end
                                    else
                                        -- swap may have landed on a hover
                                        if(P1_panels[panel+8].hovering) then
                                            set_hoverers_2(panel,FRAMECOUNT_HOVER,false)
                                        end
                                    end
                                end
                            else
                            -- an empty space finished swapping...
                            -- panels above it hover
                                set_hoverers(panel-8,FRAMECOUNT_HOVER+1,false)
                            end
                            -- swap completed, a matches-check will occur this frame.
                            do_matches_check=true
                        else
                            if(P1_panels[panel].hovering) then
                                -- This panel is no longer hovering.
                                -- it will now fall without sitting around
                                -- for any longer!
                                P1_panels[panel].hovering = false
                                if(P1_panels[panel+8].color ~= 0) then
                                    P1_panels[panel].landing = true
                                    P1_panels[panel].timer = 12
                                    do_matches_check = true
                                else
                                    P1_panels[panel].falling = true
                                    P1_panels[panel+8] = P1_panels[panel]
                                    P1_panels[panel+8].timer = 0
                                    P1_panels[panel] = Panel()
                                end
                            else
                                if(P1_panels[panel].landing) then
                                    P1_panels[panel].landing = false
                                else
                                    if(P1_panels[panel].matched) then
                                        P1_panels[panel].matched = false
                                        -- This panel's match just finished the whole
                                        -- flashing and looking distressed thing.
                                        -- It is given a pop time based on its place
                                        -- in the match.
                                        P1_panels[panel].popping = true
                                        something = P1_panels[panel].combo_index
                                        P1_panels[panel].timer = something*FRAMECOUNT_POP
                                    else
                                        if(P1_panels[panel].popping) then
                                            P1_score = P1_score + 10;
                                            -- P1_score_render=1;
                                            -- TODO: What is P1_score_render?
                                        -- this panel just popped
                                        -- Now it's invisible, but sits and waits
                                        -- for the last panel in the combo to pop
                                        -- before actually being removed.
                                            something=P1_panels[panel].combo_size
                                            whatever=P1_panels[panel].combo_index
                                        -- If it is the last panel to pop,
                                        -- it should be removed immediately!
                                            if(something==whatever) then--size==index
                                                P1_panels[panel].color=0;
                                                if(P1_panels[panel].chaining) then
                                                    n_chain_panels = n_chain_panels - 1
                                                end
                                                P1_panels[panel].clear_flags()
                                                set_hoverers(panel-8,FRAMECOUNT_HOVER+1,true)
                                                --TODO: obv cant pass bitmask here
                                            else
                                                P1_panels[panel].popping = false
                                                P1_panels[panel].popped = false
                                                P1_panels[panel].timer = (something-whatever)*FRAMECOUNT_POP;
                                            end
                                            something = P1_panels[panel].chain_index
                                            if(something == 0) then something=1 end
                                            -- SFX_Pop_Play[0] = something;
                                            -- SFX_Pop_Play[1] = whatever;
                                            -- TODO: wtf are these
                                        else
                                            if(P1_panels[panel].popped) then
                                            -- It's time for this panel
                                            -- to be gone forever.
                                                if(P1_panels[panel].chaining) then
                                                    n_chain_panels = n_chain_panels - 1
                                                end
                                                P1_panels[panel].color = 0
                                                P1_panels[panel].clear_flags()
                                            -- Any panels sitting on top of it
                                            -- hover and are flagged as CHAINING
                                                set_hoverers(panel-8,FRAMECOUNT_HOVER+1,true);
                                            else
                                            -- what the heck.
                                            -- if a timer runs out and the routine can't
                                            -- figure out what flag it is, tell brandon.
                                                --[[ShutDown(str(P1StackFlags[panel])+". What the heck"
                                                +" flag is "+str(P1StackFlags[panel])+"."
                                                +" This timer for a panel on row "+str(row)
                                                +" column "+str(col)+" expired and I haven't"
                                                +" the foggiest what to do with it...");--]]
                                                --TODO: replace this with debugging output lewl
                                            end
                                        end
                                    end
                                end
                            end
                        end
                  -- the timer-expiring action has completed
                    end
                end
            end
            panel = panel + 1
        end
    end

      -- Phase 3. /////////////////////////////////////////////////////////////
      --  Actions performed according to player input

                                                     -- CURSOR MOVEMENT
    P1_move_sound = false
    something = false
    whatever = false
    if(P1_cur_timer == 0) then something = true end
    if(P1_cur_timer == P1_cur_wait_time) then whatever = true end
    if(something or whatever) then
        if(P1_cur_dir==DIR_UP) then
            if(P1_cur_row>0) then
                P1_cur_row = P1_cur_row - 1
                P1_move_sound = true
            end
        else
            if(P1_cur_dir==DIR_DOWN) then
                if(P1_cur_row<bottom_row) then
                    P1_cur_row = P1_cur_row + 1
                    P1_move_sound = true
                end
                --TODO: make sure cur_col and cur_row are always 0-indexed
            else
                if(P1_cur_dir==DIR_LEFT) then
                    if(P1_cur_col>0) then
                        P1_cur_col = P1_cur_col - 1
                        P1_move_sound = true
                    end
                else
                    if(P1_cur_dir==DIR_RIGHT) then
                        if(P1_cur_col<4) then
                            P1_cur_col = P1_cur_col + 1
                            P1_move_sound = true
                        end
                    end
                end
            end
        end
    end
    if(not whatever) then
        P1_cur_timer = P1_cur_timer + 1
        --if(P1_move_sound and something) then SFX_P1Cursor_Play=1 end
        --TODO:SFX
    end

                                                     -- SWAPPING
    if(P1_swap_1 or P1_swap_2) then
        panel=(P1_cur_row*8)+P1_cur_col + 1 --Since both of these are 0-indexed.
         -- in order for a swap to occur, one of the two panels in
         -- the cursor must not be a non-panel.
        if((P1_panels[panel].color ~= 0) or (P1_panels[panel+1].color ~= 0)) then
            -- also, both spaces must be swappable.
            something=P1_panels[panel].exclude_swap()
            whatever=P1_panels[panel+1].exclude_swap()
            if((not something) and (not whatever)) then
                if(P1_cur_row>0) then
                    something=P1_panels[panel-8].hovering
                    whatever=P1_panels[panel-7].hovering
                end
                if((not something) and (not whatever)) then
                    something=P1_panels[panel].color;
                    P1_panels[panel].color=P1_panels[panel+1].color;
                    P1_panels[panel+1].color=something;

                    something=P1_panels[panel].chaining
                    whatever=P1_panels[panel+1].chaining
                    P1_panels[panel].clear_flags()
                    P1_panels[panel+1].clear_flags()
                    P1_panels[panel].swapping = true
                    P1_panels[panel].chaining = whatever
                    P1_panels[panel+1].swapping = true
                    P1_panels[panel+1].swapping_from_left = true
                    P1_panels[panel+1].chaining = something

                    P1_panels[panel].timer = 3
                    P1_panels[panel+1].timer = 3

                    --SFX_Swap_Play=1;
                    --lol SFX

                    if(P1_cur_row~=bottom_row) then
                        something = false
                        if(P1_panels[panel+8].color == 0) then something=true
                        else
                            if(P1_panels[panel+8].falling) then something=true end
                        end
                        if((P1_panels[panel].color ~= 0) and something) then
                            P1_panels[panel].dont_swap = true
                        end
                        something = false
                        if(P1_panels[panel+9].color == 0) then
                            something = true
                        else
                            if(P1_panels[panel+9].falling) then something = true end
                        end
                        if((P1_panels[panel+1].color ~= 0) and something) then
                            P1_panels[panel+1].dont_swap = true;
                        end
                    end

                    if(P1_cur_row>0) then
                        if(P1_panels[panel].color == 0) then
                            if(P1_panels[panel-8].color ~= 0) then
                                P1_panels[panel].dont_swap = true
                            end
                        end
                        if(P1_panels[panel+1].color == 0) then
                            if(P1_panels[panel-7].color ~= 0) then
                                P1_panels[panel+1].dont_swap = true
                            end
                        end
                    end
                end
            end
        end
        P1_swap_1 = false
        P1_swap_2 = false
    end


                 -- MANUAL STACK RAISING
    if(P1_manual_raise) then
        if(not P1_rise_lock) then
            if(P1_displacement == 0) then
                if(P1_has_risen) then
                    if(panels_in_top_row) then
                        P1_game_over = true
                    end
                else
                    new_row()
                    P1_displacement = 15
                    P1_has_risen = true
                end
            else
                P1_has_risen = true
                P1_displacement = P1_displacement - 1
                if(P1_displacement==1) then
                    P1_manual_raise = false
                    P1_rise_timer = 1
                    if(not P1_prevent_manual_raise) then
                        P1_score = P1_score + 1
                        --P1_score_render = 1
                        --TODO: what? ^
                    end
                    P1_prevent_manual_raise = true
                end
            end
            P1_manual_raise_yet = true  --ehhhh
            P1_stop_time = 0
            P1_stop_time_timer = 0
        else
            if(not P1_manual_raise_yet) then
                P1_manual_raise = false
            end
        end
        -- if the stack is rise locked when you press the raise button,
        -- the raising is cancelled
    end



      -- Phase 4. /////////////////////////////////////////////////////////////
      --  Now falling panels will land if they have something to land on that
      --  isn't falling as well.

    for row=bottom_row,0,-1 do
        panel = row*8 + 1
        for col=1,6 do
            if(P1_panels[panel].falling) then
                -- if it's on the bottom row, it should surely land
                if(row==bottom_row) then
                    P1_panels[panel].falling = false
                    P1_panels[panel].landing = true
                    P1_panels[panel].timer = 12
                    do_matches_check = true
                    --SFX_Land_Play=1;
                    --SFX LAWL
                else
                    if(P1_panels[panel+8].color ~= 0) then
                        -- if there's a panel below, this panel's gonna land
                        -- unless the panel below is falling.
                        something=P1_panels[panel+8].falling
                        if(not something) then
                            P1_panels[panel].falling = false
                            -- if it lands on a hovering panel, it inherits
                            -- that panel's hover time.
                            something=P1_panels[panel+8].hovering
                            if(something) then
                                set_hoverers(panel,P1_panels[panel+8].timer,false);
                            else
                                P1_panels[panel].landing = true
                                P1_panels[panel].timer = 12
                            end
                            do_matches_check = true
                            --SFX_Land_Play=1;
                            --SFX LEWL
                        end
                    end
                end
            end
            panel = panel + 1
        end
    end

      -- Phase 5. /////////////////////////////////////////////////////////////
      -- If a swap completed, one or more panels landed, or a new row was
      -- generated during this tick, a matches-check is done.
    if(do_matches_check) then
        check_matches()
    end


    -- if at the end of the routine there are no chain panels, the chain ends.
    if(P1_chain_counter ~= 0) then
        if(n_chain_panels == 0) then
            P1_chain_counter=0
        end
    end

    if(P1_score>99999) then
        P1_score=99999
        -- lol owned
    end

    --TODO: WTF IS GameTimeTimer
    --[[
   GameTimeTimer--;
   if(!GameTimeTimer)
   {
      GameTimeTimer=60;
      Switch(GameTimeMode)
      {
         Case TIME_REMAINING:
            GameTime--;
            if(GameTime<0) GameTime=0;

            if(!GameTime) SFX_Bell_Play=25;
            else if(GameTime<15) SFX_Bell_Play=24;

         Case TIME_ELAPSED:
            GameTime++;
            if(GameTime>359999) GameTime=359999;
      }
      GameTimeRender=1;
   }
   --]]
end


   --//////////////////////////////////////////////////////////////////////////
   -- The matches-checking routine.

function check_matches()
    local row = 0
    local col = 0
    local panel = 0
    local count = 0
    local old_panel = 0
    local is_chain = false
    local first_panel_row = 0
    local first_panel_col = 0
    local combo_index = 0
    local combo_size = 0
    local something = 0
    local whatever = 0

    for panel=1,96 do
        P1_panels[panel].matching = false
    end
    -- check vertical matches
    count = 0
    for col=1,6 do
        panel = col
        old_panel = 0
        for row=0,bottom_row+1 do
            something=P1_panels[panel].exclude_match()
            if((P1_panels[panel] ~= 0) and (not something)) then
                if(count == 0) then
                    count=1
                else
                    if((P1_panels[panel].color)==(old_panel)) then
                        count = count + 1
                        if(count>2) then
                            if(not P1_panels[panel].matching) then
                                P1_panels[panel].matching = true
                                if(P1_panels[panel].chaining) then
                                    is_chain = true
                                end
                                combo_size = combo_size + 1
                            end
                            if(count==3) then
                                if(not P1_panels[panel-8].matching) then
                                    P1_panels[panel-8].matching = true
                                    if(P1_panels[panel-8].chaining) then
                                        is_chain = true
                                    end
                                    combo_size = combo_size + 1
                                end
                                if(not P1_panels[panel-16].matching) then
                                    P1_panels[panel-16].matching = true
                                    if(P1_panels[panel-16].chaining) then
                                        is_chain = true
                                    end
                                    combo_size = combo_size + 1
                                end
                            end
                        end
                    else -- not the same, but matchable
                        count = 1
                    end
                end
            else
                count=0
            end
            old_panel = P1_panels[panel].color
            panel = panel + 8
        end
    end

         -- check horizontal matches
    count = 0
    panel = 0
    for row=0,bottom_row do
        old_panel = 0
        panel = row * 8 + 1
        for col=1,6 do
            something=P1_panels[panel].exclude_match()
            if((P1_panels[panel].color ~= 0) and (not something)) then
                if(count == 0) then
                    count = 1
                else
                    if(P1_panels[panel].color==old_panel) then
                        count = count + 1
                        if(count>2) then
                            if(not P1_panels[panel].matching) then
                                P1_panels[panel].matching = true
                                if(P1_panels[panel].chaining) then
                                    is_chain = true
                                end
                                combo_size = combo_size + 1
                            end
                            if(count==3) then
                                if(not P1_panels[panel-1].matching) then
                                    P1_panels[panel-1].matching = true
                                    if(P1_panels[panel-1].chaining) then
                                        is_chain = true
                                    end
                                    combo_size = combo_size + 1
                                end
                                if(not P1_panels[panel-2].matching) then
                                    P1_panels[panel-2].matching = true
                                    if(P1_panels[panel-2].chaining) then
                                        is_chain = true
                                    end
                                    combo_size = combo_size + 1
                                end
                            end
                        end
                    else -- not the same, but matchable
                        count = 1
                    end
                end
            else
                count=0
            end
            old_panel = P1_panels[panel].color
            panel = panel + 1
        end
    end

    if(is_chain) then
        if(P1_chain_counter ~= 0) then
            P1_chain_counter = P1_chain_counter + 1
        else
            P1_chain_counter = 2
        end
    end

    combo_index=combo_size;
    for row=bottom_row,0,-1 do
        panel = row*8 + 6
        for col=5,0,-1 do
            if(P1_panels[panel].matching) then
                P1_panels[panel].landing = false
                P1_panels[panel].matched = true
                P1_panels[panel].timer = FRAMECOUNT_MATCH
                if(is_chain) then
                    if(not P1_panels[panel].chaining) then
                        P1_panels[panel].chaining = true
                        n_chain_panels = n_chain_panels + 1
                    end
                end
                P1_panels[panel].combo_index = combo_index
                P1_panels[panel].combo_size = combo_size
                P1_panels[panel].chain_index = P1_chain_counter
                combo_index = combo_index - 1
                if(combo_index == 0) then
                    first_panel_col = col
                    first_panel_row = row
                end
            else
                if(P1_panels[panel].color ~= 0) then
                    -- if a panel wasn't matched but was eligible,
                    -- we might have to remove its chain flag...!
                    something=P1_panels[panel].exclude_match()
                    if(not something) then
                        if(row~=bottom_row) then
                            something=P1_panels[panel+8].swapping
                            if(not something) then
                                -- no swapping panel below
                                -- so this panel loses its chain flag
                                if(P1_panels[panel].chaining) then
                                    P1_panels[panel].chaining = false
                                    n_chain_panels = n_chain_panels - 1
                                end
                            end
                        else    -- a panel landed on the bottom row, so it surely
                                -- loses its chain flag.
                            if(P1_panels[panel].chaining) then
                                P1_panels[panel].chaining = false
                                n_chain_panels = n_chain_panels - 1
                            end
                        end
                    end
                end
            end
            panel = panel - 1
        end
    end

    if(combo_size~=0) then
        if(combo_size>3) then
            if(score_mode == SCOREMODE_TA) then
                if(combo_size > 30) then
                    combo_size = 30
                end
                P1_score = P1_score + score_combo_TA[combo_size]
            else
                if(score_mode == SCOREMODE_PDP64) then
                    if(combo_size<41) then
                        P1_score = P1_score + score_combo_PdP64[combo_size]
                    else
                        P1_score = P1_score + 20400+((combo_size-40)*800)
                    end
                end
            end

            --EnqueueComboCard(first_panel_col,first_panel_row,combo_size<<4);
            --EnqueueConfetti(first_panel_col<<4+P1StackPosX+4,
            --          first_panel_row<<4+P1StackPosY+P1_displacement-9);
            --TODO: this stuff ^
            first_panel_row = first_panel_row - 1 -- offset chain cards
        end
        if(is_chain) then
            something = P1_chain_counter;
            if((score_mode==SCOREMODE_TA) and (P1_chain_counter > 13)) then
                something = 0
            end

            --EnqueueChainCard(first_panel_col,first_panel_row,something);
            --EnqueueConfetti(first_panel_col<<4+P1StackPosX+4,
            --          first_panel_row<<4+P1StackPosY+P1_displacement-9);
        end
        something = P1_chain_counter
        if(score_mode == SCOREMODE_TA) then
            if(P1_chain_counter>13) then
                something=0
            end
            P1_score = P1_score + score_chain_TA[something]
        end
        if((combo_size>3) or is_chain) then
            if(P1_stop_time ~= 0) then
                P1_stop_time = P1_stop_time + 1
            else
                if(is_chain) then
                    P1_stop_time = P1_stop_time + stop_time_chain
                        [(panels_in_top_row and 2) or 1][P1_difficulty]
                else
                    P1_stop_time = P1_stop_time + stop_time_combo
                        [(panels_in_top_row and 2) or 1][P1_difficulty]
                end
                --MrStopState=1;
                --MrStopTimer=MrStopAni[P1_stop_time];
                --TODO: Mr Stop ^
                P1_stop_time_timer = 60
            end
            if(P1_stop_time>99) then
                P1_stop_time = 99
            end

            --SFX_Buddy_Play=P1Stage;
            --SFX_Land_Play=0;
            --lol SFX
        end

        P1_manual_raise=false
        --P1_score_render=1;
        --Nope.
    end
end


--addflags has been replaced with a boolean.
--if it is true, we should add the chaining flag.
function set_hoverers(first_hoverer, hover_time, add_chaining)
    local hovers_time = 0
    local panel = 0
    local brk = false
    local something = false
    local nonpanel = false
    panel = first_hoverer
    if(first_hoverer<1) then
        brk = true
    end
    hovers_time=hover_time;
    while(not brk) do
        nonpanel = false
        if(P1_panels[panel].color == 0) then
            nonpanel = true
        end
        something = P1_panels[panel].exclude_hover()
        if(nonpanel or something) then
            brk = true
        else
            if(P1_panels[panel].swapping) then
                hovers_time = hovers_time + P1_panels[panel].timer
            end
            something = P1_panels[panel].chaining
            P1_panels[panel].clear_flags()
            P1_panels[panel].hovering = true
            P1_panels[panel].chaining = something or add_chaining
            P1_panels[panel].timer = hoverstime
            if((not something) and (add_chaining)) then
                n_chain_panels = n_chain_panels + 1
            end
        end
        panel = panel - 8
        if(panel<1) then
            brk = true
        end
    end
end
--see comment for set_hoverers
function set_hoverers_2(first_hoverer, hover_time, add_chaining)
    -- this version of the set_hoverers routine is for use during Phase 1&2,
    -- when panels above the first should be given an extra tick of hover time.
    -- This is because their timers will be decremented once on the same tick
    -- they are set, as Phase 1&2 iterates backward through the stack.
    local not_first = 0   -- if 1, the current panel isn't the first one
    local hovers_time = 0
    local panel = 0
    local brk = false
    local something = false
    local nonpanel = false
    panel = first_hoverer
    if(first_hoverer<1) then
        brk = true
    end
    hovers_time=hover_time
    while(not brk) do
        nonpanel = false
        if(P1_panels[panel].color == 0) then
            nonpanel = true
        end
        something = P1_panels[panel].exclude_hover()
        if(nonpanel or something) then
            brk = true
        else
            if(P1_panels[panel].swapping) then
                hovers_time = hovers_time + P1_panels[panel].timer
            end
            something = P1_panels[panel].chaining
            P1_panels[panel].clear_flags()
            P1_panels[panel].hovering = true
            P1_panels[panel].chaining = add_chaining or something
            P1_panels[panel].timer = hovers_time+not_first
            if((not something) and (add_chaining)) then
                n_chain_panels = n_chain_panels + 1
            end
            not_first = 1
        end
        panel = panel - 8
        if(panel<1) then
            brk = true
        end
    end
end


function new_row()
    local panel = 0
    local something = false
    local something_else = false
    local whatever = false
    local brk = false
                     -- move cursor up
    if(P1_cur_row ~= 0) then
        P1_cur_row = P1_cur_row - 1
    end
                     -- move panels up
    for panel=1,86 do
        P1_panels[panel]=P1_panels[panel+8];
    end
                     -- put bottom row into play
    for panel=81,88 do
        P1_panels[panel].dimmed = false
    end
                     -- generate a new row
    for panel=89,90 do
        brk=0;
        P1_panels[panel] = Panel()
        while(not brk) do
            P1_panels[panel].color = random(1,6)
            --TODO TODO TODO: hook this up to a real random function.
            brk = 1
            if(P1_panels[panel] == P1_panels[panel-8]) then
                brk = 0
            end
        end
        P1_panels[panel].dimmed = true
    end
    for panel=91,94 do
        whatever = false
        if(P1_panels[panel-1].color==P1_panels[panel-2].color) then
            whatever = true
        end
        brk = false
        P1_panels[panel] = Panel()
        while(not brk) do
            P1_panels[panel].color = random(1,6)
            something = false
            if(whatever) then
                if(P1_panels[panel].color == P1_panels[panel-1].color) then
                    something = true
                end
            end
            something_else = false
            if(P1_panels[panel] == P1_panels[panel-8]) then
                something_else=1
            end
            brk = true
            if(something or something_else) then
                brk = false
            end
        end
        P1_panels[panel].dimmed = true
    end
    P1_displacement = 16
    bottom_row = 10
    do_matches_check = true
end



function quiet_cursor_movement()
    local something = false
    local whatever = false

    if(P1_cur_timer ~= 0) then
         -- the cursor will move if a direction's was just pressed or has been
         -- pressed for at least the P1_cur_wait_time
        P1_move_sound = true
        something = false
        whatever = false
        if(P1_cur_timer == 1) then something = true end
        if(P1_cur_timer == P1_cur_wait_time) then whatever = true end
        if(something or whatever) then
            if(P1_cur_dir == DIR_UP) then
                if(P1_cur_row > 0) then
                    P1_cur_row = P1_cur_row - 1
                end
            else
                if(P1_cur_dir == DIR_DOWN) then
                    if(P1_cur_row < bottom_row) then
                        P1_cur_row = P1_cur_row + 1
                    end
                else
                    if(P1_cur_dir == DIR_LEFT) then
                        if(P1_cur_col > 0) then
                            P1_cur_col = P1_cur_col - 1
                        end
                    else
                        if(P1_cur_dir == DIR_RIGHT) then
                            if(P1_cur_col < 4) then
                                P1_cur_col = P1_cur_col + 1
                            end
                        end
                    end
                end
            end
        end
        if(not whatever) then
            P1_cur_timer = P1_cur_timer + 1
        end
    end
end


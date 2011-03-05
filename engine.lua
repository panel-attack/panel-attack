   -- Stuff defined in this file:
   --  . the data structures that store the configuration of
   --    the stack of panels
   --  . the main game routine
   --    (rising, timers, falling, cursor movement, swapping, landing)
   --  . the matches-checking routine

Stack = class(function(s)
        s.pos_x = 4   -- Position of the play area on the screen
        s.pos_y = 4
        s.panel_buffer = ""
        s.input_buffer = ""
        s.panels = {}
        for i=1,96 do
            s.panels[i] = Panel()
        end

        s.CLOCK = 0

        s.displacement = 0
        -- This variable indicates how far below the top of the play
        -- area the top row of panels actually is.
        -- This variable being decremented causes the stack to rise.
        -- During the automatic rising routine, if this variable is 0,
        -- it's reset to 15, all the panels are moved up one row,
        -- and a new row is generated at the bottom.
        -- Only when the displacement is 0 are all 12 rows "in play."


        s.do_matches_check = false
        -- if this is true a matches-check will occur for this frame.

        s.danger_col = {false,false,false,false,false,false}
        -- set true if this column is near the top
        s.danger_timer = 0   -- decides bounce frame when in danger

        s.difficulty = 3

        s.speed = 100   -- The player's speed level decides the amount of time
                         -- the stack takes to rise automatically
        s.rise_timer = 1   -- When this value reaches 0, the stack will rise a pixel
        s.rise_lock = false   -- If the stack is rise locked, it won't rise until it is
                          -- unlocked.
        s.has_risen = false   -- set once the stack rises once during the game

        s.stop_time = 0
        s.stop_time_timer = 0
        s.stop_time_combo = {{0,0,0,0,0},{0,0,0,0,0}}
        s.stop_time_chain = {{0,0,0,0,0},{0,0,0,0,0}}

        s.game_time = 0
        s.game_time_mode = 1
        s.game_time_timer = 0

        s.NCOLORS = 5
        s.score = 0         -- der skore
        s.chain_counter = 0   -- how high is the current chain?

        s.bottom_row = 0   -- row number of the bottom row that's "in play"
        s.panels_in_top_row = false  -- boolean, panels in the top row (danger)
        s.panels_in_second_row = false -- changes music state

        s.n_active_panels = 0
        s.n_chain_panels= 0

           -- These change depending on the difficulty and speed levels:
        s.FRAMECOUNT_HOVER = 9
        s.FRAMECOUNT_MATCH = 50
        s.FRAMECOUNT_FLASH = 13
        s.FRAMECOUNT_POP = 8
        s.FRAMECOUNT_RISE = 60

        s.rise_timer = s.FRAMECOUNT_RISE

           -- Player input stuff:
        s.manual_raise = false   -- set until raising is completed
        s.manual_raise_yet = false  -- if not set, no actual raising's been done yet
                               -- since manual raise button was pressed
        s.prevent_manual_raise = false
        s.swap_1 = false   -- attempt to initiate a swap on this frame
        s.swap_2 = false

        s.cur_wait_time = 25   -- number of ticks to wait before the cursor begins
                             -- to move quickly... it's based on P1CurSensitivity
        s.cur_timer = 0   -- number of ticks for which a new direction's been pressed
        s.cur_dir = 0     -- the direction pressed
        s.cur_row = 0  -- the row the cursor's on
        s.cur_col = 0  -- the column the left half of the cursor's on

        s.move_sound = false  -- this is set if the cursor movement sound should be played
        s.game_over = false

        s.card_q = Queue()
    end)

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
    return self.is_swapping or self.matched or self.popping or self.popped
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

--local_run is for the stack that belongs to this client.
function Stack.local_run(self)
    send_controls()
    controls(self)
    self:PdP()
    self.CLOCK = self.CLOCK + 1
    self:render()
end

--foreign_run is for a stack that belongs to another client.
function Stack.foreign_run(self)
    while string.len(self.input_buffer) ~= 0 do
        fake_controls(self, string.sub(self.input_buffer,7,22))
        self:PdP()
        self.CLOCK = self.CLOCK + 1
        self.input_buffer = string.sub(self.input_buffer,23)
    end
    self:render()
end

function Stack.enqueue_card(self, chain, x, y, n)
    self.card_q:push({frame=1, chain=chain, x=x, y=y, n=n})
end

-- The engine routine.
function Stack.PdP(self)
    -- The main game routine has five phases:
    --  1. Decrement timers, act on expired one
    --  2. Move falling panels down a row
    --  3. Do things according to player input
    --  4. Make falling panels land
    --  5. Possibly do a matches-check

    -- During these phases the entire StackPanels will be examined
    -- several times, from first to last (or last to first).

    if self.stop_time ~= 0 then
        self.stop_time_timer = self.stop_time_timer - 1
        if self.stop_time_timer == 0 then
            self.stop_time = self.stop_time - 1
            if self.stop_time ~= 0 then
                self.stop_time_timer=60
            end
        end
    end

    if self.displacement ~= 0 then
        self.bottom_row=10
    else
        self.bottom_row=11   -- the 12th row (row 11) is only "in play"
    end                  -- when the stack displacement is 0
                        -- and there are panels in the top row

    -- count the number of panels in the top row (danger)
    self.panels_in_top_row = false
    for idx=1,6 do
        if self.panels[idx].color ~= 0 then
            self.panels_in_top_row = true
            self.danger_col[idx] = true
        else
            self.danger_col[idx] = false
        end
    end
    if self.panels_in_top_row and self.stop_time == 0 then
        self.danger_timer = self.danger_timer - 1
        if self.danger_timer<0 then
            self.danger_timer=17
        end
    end

    self.panels_in_second_row = false
    for idx=9,14 do
        if self.panels[idx] ~= 0 then
            self.panels_in_second_row = true
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

    if self.displacement == 0 and self.has_risen and not self.panels_in_top_row then
        self:new_row()
    end

    if self.n_active_panels ~= 0 then
        self.rise_lock = true
    else
        self.rise_lock = false
    end

    if self.displacement == 0 and self.panels_in_top_row and not self.rise_lock and
            self.stop_time == 0 then
        self.game_over = true
    end

    -- Phase 0 //////////////////////////////////////////////////////////////
    -- Stack automatic rising


    if self.speed ~= 0 and not self.manual_raise and self.stop_time == 0
            and not self.rise_lock then
        self.rise_timer = self.rise_timer - 1
        if self.rise_timer == 0 then  -- try to rise
            if self.displacement == 0 then
                if self.has_risen or self.panels_in_top_row then
                    self.game_over = true
                else
                    self:new_row()
                    self.displacement = 15
                    self.has_risen = true
                end
            else
                self.displacement = self.displacement - 1
                if self.displacement == 0 then
                    self.prevent_manual_raise = false
                    if self.panels_in_top_row then
                        for idx=89,94 do
                            self.panels[idx].dimmed = false
                        end
                        self.bottom_row=11
                    else
                        self:new_row()
                    end
                end
            end
            self.rise_timer=self.FRAMECOUNT_RISE
        end
    end

    -- Phase 1 . ///////////////////////////////////////////////////////
    -- Falling

    for row=self.bottom_row,0,-1 do
        local idx = row*8+1
        for col=1,6 do
            if self.panels[idx].falling then
               -- if there's no panel below a falling panel,
               -- it must fall one row.
               -- I'm gonna assume there's no panel below,
               -- because the falling panel should've landed on
               -- it during the last frame if there was.
                self.panels[idx+8] = self.panels[idx]
                self.panels[idx+8].timer = 0
                self.panels[idx] = Panel()
               -- the timer can be left behind because it should be 0.
               -- the tags can be left behind because they're not important
               -- until a panel is stuck in position.
            end
            idx = idx + 1
        end
    end

    -- Phase 2. /////////////////////////////////////////////////////////////
    -- Timer-expiring actions

    for row=self.bottom_row,0,-1 do
        local idx=row*8+1
        for col=1,6 do
            -- first of all, we do Nothin' if we're not even looking
            -- at a space with any flags.
            panel = self.panels[idx]
            if panel:has_flags() and panel.timer~=0 then
                panel.timer = panel.timer - 1
                if panel.timer == 0 then
                    if panel.is_swapping then
                        -- a swap has completed here.
                        panel.is_swapping = false
                        panel.dont_swap = false
                        local from_left = panel.is_swapping_from_left
                        panel.is_swapping_from_left = false
                        -- Now there are a few cases where some hovering must
                        -- be done.
                        if panel.color ~= 0 then
                            if row~=self.bottom_row then
                                if self.panels[idx+8].color == 0 then
                                    self:set_hoverers_2(idx,
                                            self.FRAMECOUNT_HOVER,false)
                                    -- if there is no panel beneath this panel
                                    -- it will begin to hover.
                                    -- CRAZY BUG EMULATION:
                                    -- the space it was swapping from hovers too
                                    if from_left then
                                        if self.panels[idx-1].falling then
                                            self:set_hoverers_2(idx-1,
                                                    self.FRAMECOUNT_HOVER,false)
                                        end
                                    else
                                        if self.panels[idx+1].falling then
                                            self:set_hoverers(idx+1,
                                                    self.FRAMECOUNT_HOVER+1,false)
                                        end
                                    end
                                elseif self.panels[idx+8].hovering then
                                    -- swap may have landed on a hover
                                    self:set_hoverers_2(idx,
                                            self.FRAMECOUNT_HOVER,false)
                                end
                            end
                        else
                            -- an empty space finished swapping...
                            -- panels above it hover
                            self:set_hoverers(idx-8,
                                    self.FRAMECOUNT_HOVER+1,false)
                        end
                        -- swap completed, a matches-check will occur this frame.
                        self.do_matches_check = true
                    elseif panel.hovering then
                        -- This panel is no longer hovering.
                        -- it will now fall without sitting around
                        -- for any longer!
                        panel.hovering = false
                        if self.panels[idx+8].color ~= 0 then
                            panel.landing = true
                            panel.timer = 12
                            self.do_matches_check = true
                        else
                            panel.falling = true
                            self.panels[idx], self.panels[idx+8] =
                                self.panels[idx+8], self.panels[idx]
                            panel.timer = 0
                            -- Not sure if needed:
                            self.panels[idx]:clear_flags()
                        end
                    elseif panel.landing then
                        panel.landing = false
                    elseif panel.matched then
                        panel.matched = false
                        -- This panel's match just finished the whole
                        -- flashing and looking distressed thing.
                        -- It is given a pop time based on its place
                        -- in the match.
                        panel.popping = true
                        panel.timer = panel.combo_index*self.FRAMECOUNT_POP
                    elseif panel.popping then
                        self.score = self.score + 10;
                        -- self.score_render=1;
                        -- TODO: What is self.score_render?
                        -- this panel just popped
                        -- Now it's invisible, but sits and waits
                        -- for the last panel in the combo to pop
                        -- before actually being removed.

                        -- If it is the last panel to pop,
                        -- it should be removed immediately!
                        if panel.combo_size == panel.combo_index then
                            panel.color=0;
                            if(panel.chaining) then
                                self.n_chain_panels = self.n_chain_panels - 1
                            end
                            panel:clear_flags()
                            self:set_hoverers(idx-8,
                                    self.FRAMECOUNT_HOVER+1,true)
                        else
                            panel.popping = false
                            panel.popped = true
                            panel.timer = (panel.combo_size-panel.combo_index)
                                    * self.FRAMECOUNT_POP
                        end
                        --something = panel.chain_index
                        --if(something == 0) then something=1 end
                        -- SFX_Pop_Play[0] = something;
                        -- SFX_Pop_Play[1] = whatever;
                        -- TODO: wtf are these
                    elseif panel.popped then
                        -- It's time for this panel
                        -- to be gone forever :'(
                        if panel.chaining then
                            self.n_chain_panels = self.n_chain_panels - 1
                        end
                        panel.color = 0
                        panel:clear_flags()
                        -- Any panels sitting on top of it
                        -- hover and are flagged as CHAINING
                        self:set_hoverers(idx-8,self.FRAMECOUNT_HOVER+1,true);
                    else
                        -- what the heck.
                        -- if a timer runs out and the routine can't
                        -- figure out what flag it is, tell brandon.
                        -- No seriously, email him or something.
                        error("something terrible happened")
                    end
                -- the timer-expiring action has completed
                end
            end
            idx = idx + 1
        end
    end

    -- Phase 3. /////////////////////////////////////////////////////////////
    -- Actions performed according to player input

    -- CURSOR MOVEMENT
    self.move_sound = false
    if self.cur_timer == 0 or self.cur_timer == self.cur_wait_time then
        if self.cur_dir == DIR_UP then
            if self.cur_row > 0 then
                self.cur_row = self.cur_row - 1
                self.move_sound = true
            end
        elseif self.cur_dir == DIR_DOWN then
            if self.cur_row < self.bottom_row then
                self.cur_row = self.cur_row + 1
                self.move_sound = true
            end
        elseif self.cur_dir == DIR_LEFT then
            if self.cur_col > 0 then
                self.cur_col = self.cur_col - 1
                self.move_sound = true
            end
        elseif self.cur_dir==DIR_RIGHT then
            if self.cur_col < 4 then
                self.cur_col = self.cur_col + 1
                self.move_sound = true
            end
        end
    end
    if self.cur_timer ~= self.cur_wait_time then
        self.cur_timer = self.cur_timer + 1
        --if(self.move_sound and self.cur_timer == 0) then SFX_P1Cursor_Play=1 end
        --TODO:SFX
    end

    -- SWAPPING
    if self.swap_1 or self.swap_2 then
        local idx = (self.cur_row*8) + self.cur_col + 1 --Since both of these are 0-indexed.
         -- in order for a swap to occur, one of the two panels in
         -- the cursor must not be a non-panel.
        if self.panels[idx].color ~= 0 or self.panels[idx+1].color ~= 0 then
            -- also, both spaces must be swappable.
            if not (self.panels[idx]:exclude_swap() or
                    self.panels[idx+1]:exclude_swap()) then
                if self.cur_row == 0 or not (self.panels[idx-8].hovering or
                        self.panels[idx-7].hovering) then
                    self.panels[idx], self.panels[idx+1] =
                        self.panels[idx+1], self.panels[idx]
                    local tmp_chaining = self.panels[idx].chaining
                    self.panels[idx]:clear_flags()
                    self.panels[idx].is_swapping = true
                    self.panels[idx].chaining = tmp_chaining
                    tmp_chaining = self.panels[idx+1].chaining
                    self.panels[idx+1]:clear_flags()
                    self.panels[idx+1].is_swapping = true
                    self.panels[idx+1].is_swapping_from_left = true
                    self.panels[idx+1].chaining = tmp_chaining

                    self.panels[idx].timer = 3
                    self.panels[idx+1].timer = 3

                    --SFX_Swap_Play=1;
                    --lol SFX

                    if self.cur_row ~= self.bottom_row then
                        if (self.panels[idx].color ~= 0) and (self.panels[idx+8].color
                                == 0 or self.panels[idx+8].falling) then
                            self.panels[idx].dont_swap = true
                        end
                        if (self.panels[idx+1].color ~= 0) and (self.panels[idx+9].color
                                == 0 or self.panels[idx+9].falling) then
                            self.panels[idx+1].dont_swap = true
                        end
                    end

                    if self.cur_row > 0 then
                        if self.panels[idx].color == 0 and
                                self.panels[idx-8].color ~= 0 then
                            self.panels[idx].dont_swap = true
                        end
                        if self.panels[idx+1].color == 0 and
                                self.panels[idx-7].color ~= 0 then
                            self.panels[idx+1].dont_swap = true
                        end
                    end
                end
            end
        end
        self.swap_1 = false
        self.swap_2 = false
    end

    -- MANUAL STACK RAISING
    if self.manual_raise then
        if not self.rise_lock then
            if self.displacement == 0 then
                if self.has_risen then
                    if self.panels_in_top_row then
                        self.game_over = true
                    end
                else
                    self:new_row()
                    self.displacement = 15
                    self.has_risen = true
                end
            else
                self.has_risen = true
                self.displacement = self.displacement - 1
                if self.displacement == 1 then
                    self.manual_raise = false
                    self.rise_timer = 1
                    if not self.prevent_manual_raise then
                        self.score = self.score + 1
                        --self.score_render = 1
                        --TODO: what? ^
                    end
                    self.prevent_manual_raise = true
                end
            end
            self.manual_raise_yet = true  --ehhhh
            self.stop_time = 0
            self.stop_time_timer = 0
        elseif not self.manual_raise_yet then
            self.manual_raise = false
        end
        -- if the stack is rise locked when you press the raise button,
        -- the raising is cancelled
    end

    -- Phase 4. /////////////////////////////////////////////////////////////
    --  Now falling panels will land if they have something to land on that
    --  isn't falling as well.

    for row=self.bottom_row,0,-1 do
        local idx = row*8 + 1
        for col=1,6 do
            if self.panels[idx].falling then
                -- if it's on the bottom row, it should surely land
                if row == self.bottom_row then
                    self.panels[idx].falling = false
                    self.panels[idx].landing = true
                    self.panels[idx].timer = 12
                    self.do_matches_check = true
                    --SFX_Land_Play=1;
                    --SFX LAWL
                else
                    if self.panels[idx+8].color ~= 0 then
                        -- if there's a panel below, this panel's gonna land
                        -- unless the panel below is falling.
                        if not self.panels[idx+8].falling then
                            self.panels[idx].falling = false
                            -- if it lands on a hovering panel, it inherits
                            -- that panel's hover time.
                            if self.panels[idx+8].hovering then
                                self:set_hoverers(idx,self.panels[idx+8].timer,false)
                            else
                                self.panels[idx].landing = true
                                self.panels[idx].timer = 12
                            end
                            self.do_matches_check = true
                            --SFX_Land_Play=1;
                            --SFX LEWL
                        end
                    end
                end
            end
            idx = idx + 1
        end
    end

    -- Phase 5. /////////////////////////////////////////////////////////////
    -- If a swap completed, one or more panels landed, or a new row was
    -- generated during this tick, a matches-check is done.
    if self.do_matches_check then
        self:check_matches()
    end


    -- if at the end of the routine there are no chain panels, the chain ends.
    if self.chain_counter ~= 0 and self.n_chain_panels == 0 then
        self.chain_counter=0
    end

    if(self.score>99999) then
        self.score=99999
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

function Stack.check_matches(self)
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
        self.panels[panel].matching = false
    end
    -- check vertical matches
    count = 0
    for col=1,6 do
        panel = col
        old_panel = 0
        for row=0,self.bottom_row do
            something=self.panels[panel]:exclude_match()
            if((self.panels[panel].color ~= 0) and (not something)) then
                if(count == 0) then
                    count=1
                else
                    if((self.panels[panel].color)==(old_panel)) then
                        count = count + 1
                        if(count>2) then
                            if(not self.panels[panel].matching) then
                                self.panels[panel].matching = true
                                if(self.panels[panel].chaining) then
                                    is_chain = true
                                end
                                combo_size = combo_size + 1
                            end
                            if(count==3) then
                                if(not self.panels[panel-8].matching) then
                                    self.panels[panel-8].matching = true
                                    if(self.panels[panel-8].chaining) then
                                        is_chain = true
                                    end
                                    combo_size = combo_size + 1
                                end
                                if(not self.panels[panel-16].matching) then
                                    self.panels[panel-16].matching = true
                                    if(self.panels[panel-16].chaining) then
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
            old_panel = self.panels[panel].color
            panel = panel + 8
        end
    end

         -- check horizontal matches
    count = 0
    panel = 0
    for row=0,self.bottom_row do
        old_panel = 0
        panel = row * 8 + 1
        for col=1,6 do
            something=self.panels[panel]:exclude_match()
            if((self.panels[panel].color ~= 0) and (not something)) then
                if(count == 0) then
                    count = 1
                else
                    if(self.panels[panel].color==old_panel) then
                        count = count + 1
                        if(count>2) then
                            if(not self.panels[panel].matching) then
                                self.panels[panel].matching = true
                                if(self.panels[panel].chaining) then
                                    is_chain = true
                                end
                                combo_size = combo_size + 1
                            end
                            if(count==3) then
                                if(not self.panels[panel-1].matching) then
                                    self.panels[panel-1].matching = true
                                    if(self.panels[panel-1].chaining) then
                                        is_chain = true
                                    end
                                    combo_size = combo_size + 1
                                end
                                if(not self.panels[panel-2].matching) then
                                    self.panels[panel-2].matching = true
                                    if(self.panels[panel-2].chaining) then
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
            old_panel = self.panels[panel].color
            panel = panel + 1
        end
    end

    if(is_chain) then
        if(self.chain_counter ~= 0) then
            self.chain_counter = self.chain_counter + 1
        else
            self.chain_counter = 2
        end
    end

    combo_index=combo_size;
    for row=self.bottom_row,0,-1 do
        panel = row*8 + 6
        for col=5,0,-1 do
            if(self.panels[panel].matching) then
                self.panels[panel].landing = false
                self.panels[panel].matched = true
                self.panels[panel].timer = self.FRAMECOUNT_MATCH
                if(is_chain) then
                    if(not self.panels[panel].chaining) then
                        self.panels[panel].chaining = true
                        self.n_chain_panels = self.n_chain_panels + 1
                    end
                end
                self.panels[panel].combo_index = combo_index
                self.panels[panel].combo_size = combo_size
                self.panels[panel].chain_index = self.chain_counter
                combo_index = combo_index - 1
                if(combo_index == 0) then
                    first_panel_col = col
                    first_panel_row = row
                end
            else
                if(self.panels[panel].color ~= 0) then
                    -- if a panel wasn't matched but was eligible,
                    -- we might have to remove its chain flag...!
                    something=self.panels[panel]:exclude_match()
                    if(not something) then
                        if(row~=self.bottom_row) then
                            something=self.panels[panel+8].is_swapping
                            if(not something) then
                                -- no swapping panel below
                                -- so this panel loses its chain flag
                                if(self.panels[panel].chaining) then
                                    self.panels[panel].chaining = false
                                    self.n_chain_panels = self.n_chain_panels - 1
                                end
                            end
                        else    -- a panel landed on the bottom row, so it surely
                                -- loses its chain flag.
                            if(self.panels[panel].chaining) then
                                self.panels[panel].chaining = false
                                self.n_chain_panels = self.n_chain_panels - 1
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
                self.score = self.score + score_combo_TA[combo_size]
            elseif(score_mode == SCOREMODE_PDP64) then
                if(combo_size<41) then
                    self.score = self.score + score_combo_PdP64[combo_size]
                else
                    self.score = self.score + 20400+((combo_size-40)*800)
                end
            end

            self:enqueue_card(false, first_panel_col, first_panel_row, combo_size)
            --EnqueueConfetti(first_panel_col<<4+P1StackPosX+4,
            --          first_panel_row<<4+P1StackPosY+self.displacement-9);
            --TODO: this stuff ^
            first_panel_row = first_panel_row - 1 -- offset chain cards
        end
        if(is_chain) then
            something = self.chain_counter;
            if((score_mode==SCOREMODE_TA) and (self.chain_counter > 13)) then
                something = 0
            end

            self:enqueue_card(true, first_panel_col, first_panel_row, something)
            --EnqueueConfetti(first_panel_col<<4+P1StackPosX+4,
            --          first_panel_row<<4+P1StackPosY+self.displacement-9);
        end
        something = self.chain_counter
        if(score_mode == SCOREMODE_TA) then
            if(self.chain_counter>13) then
                something=0
            end
            self.score = self.score + score_chain_TA[something]
        end
        if((combo_size>3) or is_chain) then
            if(self.stop_time ~= 0) then
                self.stop_time = self.stop_time + 1
            else
                if(is_chain) then
                    self.stop_time = self.stop_time + self.stop_time_chain
                        [(self.panels_in_top_row and 2) or 1][self.difficulty]
                else
                    self.stop_time = self.stop_time + self.stop_time_combo
                        [(self.panels_in_top_row and 2) or 1][self.difficulty]
                end
                --MrStopState=1;
                --MrStopTimer=MrStopAni[self.stop_time];
                --TODO: Mr Stop ^
                self.stop_time_timer = 60
            end
            if(self.stop_time>99) then
                self.stop_time = 99
            end

            --SFX_Buddy_Play=P1Stage;
            --SFX_Land_Play=0;
            --lol SFX
        end

        self.manual_raise=false
        --self.score_render=1;
        --Nope.
    end
end

function Stack.set_hoverers(self, first_hoverer, hover_time, add_chaining)
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
        if(self.panels[panel].color == 0) then
            nonpanel = true
        end
        something = self.panels[panel]:exclude_hover()
        if(nonpanel or something) then
            brk = true
        else
            if(self.panels[panel].is_swapping) then
                hovers_time = hovers_time + self.panels[panel].timer
            end
            something = self.panels[panel].chaining
            self.panels[panel]:clear_flags()
            self.panels[panel].hovering = true
            self.panels[panel].chaining = something or add_chaining
            self.panels[panel].timer = hovers_time
            if((not something) and (add_chaining)) then
                self.n_chain_panels = self.n_chain_panels + 1
            end
        end
        panel = panel - 8
        if(panel<1) then
            brk = true
        end
    end
end

function Stack.set_hoverers_2(self, first_hoverer, hover_time, add_chaining)
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
        if(self.panels[panel].color == 0) then
            nonpanel = true
        end
        something = self.panels[panel]:exclude_hover()
        if(nonpanel or something) then
            brk = true
        else
            if(self.panels[panel].is_swapping) then
                hovers_time = hovers_time + self.panels[panel].timer
            end
            something = self.panels[panel].chaining
            self.panels[panel]:clear_flags()
            self.panels[panel].hovering = true
            self.panels[panel].chaining = add_chaining or something
            self.panels[panel].timer = hovers_time+not_first
            if((not something) and (add_chaining)) then
                self.n_chain_panels = self.n_chain_panels + 1
            end
            not_first = 1
        end
        panel = panel - 8
        if(panel<1) then
            brk = true
        end
    end
end

function Stack.new_row(self)
                     -- move cursor up
    if(self.cur_row ~= 0) then
        self.cur_row = self.cur_row - 1
    end
                     -- move panels up
    for panel=1,86 do
        self.panels[panel]=self.panels[panel+8];
    end
                     -- put bottom row into play
    for panel=81,88 do
        self.panels[panel].dimmed = false
    end

    if string.len(self.panel_buffer) < 6 then
        error("Ran out of buffered panels.  Is the server down?")
    end
                     -- generate a new row
    for panel=89,94 do
        self.panels[panel] = Panel()
        self.panels[panel].color = string.sub(self.panel_buffer,panel-88,panel-88)+0
        self.panels[panel].dimmed = true
    end
    self.panel_buffer = string.sub(self.panel_buffer,7)
    if string.len(self.panel_buffer) == 60 then
        ask_for_panels(string.sub(self.panel_buffer,55,60))
    end
    self.displacement = 16
    self.bottom_row = 10
    self.do_matches_check = true
end

--[[function Stack.new_row(self)
    local panel = 0
    local something = false
    local something_else = false
    local whatever = false
    local brk = false
                     -- move cursor up
    if(self.cur_row ~= 0) then
        self.cur_row = self.cur_row - 1
    end
                     -- move panels up
    for panel=1,86 do
        self.panels[panel]=self.panels[panel+8];
    end
                     -- put bottom row into play
    for panel=81,88 do
        self.panels[panel].dimmed = false
    end
                     -- generate a new row
    for panel=89,90 do
        brk = false
        self.panels[panel] = Panel()
        while(not brk) do
            self.panels[panel].color = math.random(1,self.NCOLORS)
            brk = true
            if self.panels[panel].color == self.panels[panel-8].color then
                brk = false
            end
        end
        self.panels[panel].dimmed = true
    end
    for panel=91,94 do
        whatever = false
        if(self.panels[panel-1].color==self.panels[panel-2].color) then
            whatever = true
        end
        brk = false
        self.panels[panel] = Panel()
        while(not brk) do
            self.panels[panel].color = math.random(1,self.NCOLORS)
            something = false
            if(whatever) then
                if(self.panels[panel].color == self.panels[panel-1].color) then
                    something = true
                end
            end
            something_else = false
            if self.panels[panel].color == self.panels[panel-8].color then
                something_else=1
            end
            brk = true
            if(something or something_else) then
                brk = false
            end
        end
        self.panels[panel].dimmed = true
    end
    self.displacement = 16
    self.bottom_row = 10
    self.do_matches_check = true
end--]]

function quiet_cursor_movement()
    local something = false
    local whatever = false

    if(self.cur_timer ~= 0) then
         -- the cursor will move if a direction's was just pressed or has been
         -- pressed for at least the self.cur_wait_time
        self.move_sound = true
        something = false
        whatever = false
        if(self.cur_timer == 1) then something = true end
        if(self.cur_timer == self.cur_wait_time) then whatever = true end
        if(something or whatever) then
            if(self.cur_dir == DIR_UP) then
                if(self.cur_row > 0) then
                    self.cur_row = self.cur_row - 1
                end
            else
                if(self.cur_dir == DIR_DOWN) then
                    if(self.cur_row < bottom_row) then
                        self.cur_row = self.cur_row + 1
                    end
                else
                    if(self.cur_dir == DIR_LEFT) then
                        if(self.cur_col > 0) then
                            self.cur_col = self.cur_col - 1
                        end
                    else
                        if(self.cur_dir == DIR_RIGHT) then
                            if(self.cur_col < 4) then
                                self.cur_col = self.cur_col + 1
                            end
                        end
                    end
                end
            end
        end
        if(not whatever) then
            self.cur_timer = self.cur_timer + 1
        end
    end
end

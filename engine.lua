    -- Stuff defined in this file:
    --  . the data structures that store the configuration of
    --    the stack of panels
    --  . the main game routine
    --    (rising, timers, falling, cursor movement, swapping, landing)
    --  . the matches-checking routine

Stack = class(function(s)
        s.pos_x = 4   -- Position of the play area on the screen
        s.pos_y = 4
        s.score_x = 315
        s.panel_buffer = ""
        s.input_buffer = ""
        s.panels = {}
        s.width = 6
        s.height = 12
        s.size = s.width * s.height
        for i=1,s.width*s.height do
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

        s.speed = 20   -- The player's speed level decides the amount of time
                         -- the stack takes to rise automatically
        s.rise_timer = 1   -- When this value reaches 0, the stack will rise a pixel
        s.rise_lock = false   -- If the stack is rise locked, it won't rise until it is
                          -- unlocked.
        s.has_risen = false   -- set once the stack rises once during the game

        s.stop_time = 0
        s.stop_time_timer = 0

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
        s.FRAMECOUNT_HOVER = FC_HOVER[s.difficulty]
        s.FRAMECOUNT_MATCH = FC_MATCH[s.difficulty]
        s.FRAMECOUNT_FLASH = FC_FLASH[s.difficulty]
        s.FRAMECOUNT_POP   = FC_POP[s.difficulty]
        s.FRAMECOUNT_RISE  = speed_to_rise_time[s.speed]

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
        s.cur_dir = nil     -- the direction pressed
        s.cur_row = 0  -- the row the cursor's on
        s.cur_col = 0  -- the column the left half of the cursor's on

        s.move_sound = false  -- this is set if the cursor movement sound should be played
        s.game_over = false

        s.card_q = Queue()
    end)

Panel = class(function(p)
        p:clear()
    end)

function Panel.clear(self)
        -- color 0 is an empty panel.
        -- colors 1-7 are normal colors, 8 is [!].
        self.color = 0
        -- A panel's timer indicates for how many more frames it will:
        --  . be swapping
        --  . sit in the MATCHED state before being set POPPING
        --  . sit in the POPPING state before actually being POPPED
        --  . sit and be POPPED before disappearing for good
        --  . hover before FALLING
        -- depending on which one of these states the panel is in.
        self.timer = 0
        -- is_swapping is set if the panel is swapping.
        -- The panel's timer then counts down from 3 to 0,
        -- causing the swap to end 3 frames later.
        -- The timer is also used to offset the panel's
        -- position on the screen.

        -- And finally, each panel has a couple tags.
        -- Unlike the timers and flags, they don't need to be cleared
        -- when their data is no longer valid, because they should
        -- only be checked when the data is surely valid.
        self.combo_index = 0
        self.combo_size = 0
        self.chain_index = 0

        -- Also flags
        self:clear_flags()
end

-- states:
-- swapping, matched, popping, popped, hovering,
-- falling, dimmed, landing, normal
-- flags:
-- from_left
-- dont_swap
-- chaining

do
    exclude_hover_set = {matched=true, popping=true, popped=true,
            hovering=true, falling=true}
    function Panel.exclude_hover(self)
        return exclude_hover_set[self.state]
    end

    exclude_match_set = {swapping=true, matched=true, popping=true,
            popped=true, hovering=true, dimmed=true, falling=true}
    function Panel.exclude_match(self)
        return exclude_match_set[self.state]
    end

    exclude_swap_set = {matched=true, popping=true, popped=true,
            hovering=true, dimmed=true}
    function Panel.exclude_swap(self)
        return exclude_swap_set[self.state] or self.dont_swap
    end
end

function Panel.has_flags(self)
    return (self.state ~= "normal") or self.is_swapping_from_left
            or self.dont_swap or self.chaining
end

function Panel.clear_flags(self)
    self.is_swapping_from_left = false
    self.dont_swap = false
    self.chaining = false
    self.state = "normal"
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

local d_col = {up=0, down=0, left=-1, right=1}
local d_row = {up=-1, down=1, left=0, right=0}

-- The engine routine.
function Stack.PdP(self)
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
        self.bottom_row=self.height-2
    else
        self.bottom_row=self.height-1   -- the 12th row (row 11) is only "in play"
    end                  -- when the stack displacement is 0
                        -- and there are panels in the top row

    -- count the number of panels in the top row (danger)
    self.panels_in_top_row = false
    for idx=1,self.width do
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
    for idx=1+self.width,2*self.width do
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
        if self.rise_timer <= 0 then  -- try to rise
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
                        for idx=self.size-self.width+1,self.size do
                            self.panels[idx].state = "normal"
                        end
                        self.bottom_row=self.height - 1
                    else
                        self:new_row()
                    end
                end
            end
            self.rise_timer = self.rise_timer + self.FRAMECOUNT_RISE
        end
    end

    -- Phase 1 . ///////////////////////////////////////////////////////
    -- Falling

    for row=self.bottom_row,0,-1 do
        local idx = row*self.width+1
        for col=1,self.width do
            if self.panels[idx].state == "falling" then
                -- if there's no panel below a falling panel,
                -- it must fall one row.
                -- I'm gonna assume there's no panel below,
                -- because the falling panel should've landed on
                -- it during the last frame if there was.
                self.panels[idx+self.width], self.panels[idx] =
                    self.panels[idx], self.panels[idx+self.width]
                self.panels[idx+self.width].timer = 0
                self.panels[idx]:clear()
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
        local idx=row*self.width+1
        for col=1,self.width do
            -- first of all, we do Nothin' if we're not even looking
            -- at a space with any flags.
            panel = self.panels[idx]
            if panel:has_flags() and panel.timer~=0 then
                panel.timer = panel.timer - 1
                if panel.timer == 0 then
                    if panel.state=="swapping" then
                        -- a swap has completed here.
                        panel.state = "normal"
                        panel.dont_swap = false
                        local from_left = panel.is_swapping_from_left
                        panel.is_swapping_from_left = false
                        -- Now there are a few cases where some hovering must
                        -- be done.
                        if panel.color ~= 0 then
                            if row~=self.bottom_row then
                                if self.panels[idx+self.width].color == 0 then
                                    self:set_hoverers_2(idx,
                                            self.FRAMECOUNT_HOVER,false)
                                    -- if there is no panel beneath this panel
                                    -- it will begin to hover.
                                    -- CRAZY BUG EMULATION:
                                    -- the space it was swapping from hovers too
                                    if from_left then
                                        if self.panels[idx-1].state == "falling" then
                                            self:set_hoverers_2(idx-1,
                                                    self.FRAMECOUNT_HOVER,false)
                                        end
                                    else
                                        if self.panels[idx+1].state == "falling" then
                                            self:set_hoverers(idx+1,
                                                    self.FRAMECOUNT_HOVER+1,false)
                                        end
                                    end
                                elseif self.panels[idx+self.width].state
                                        == "hovering" then
                                    -- swap may have landed on a hover
                                    self:set_hoverers_2(idx,
                                            self.FRAMECOUNT_HOVER,false)
                                end
                            end
                        else
                            -- an empty space finished swapping...
                            -- panels above it hover
                            self:set_hoverers(idx-self.width,
                                    self.FRAMECOUNT_HOVER+1,false)
                        end
                        -- swap completed, a matches-check will occur this frame.
                        self.do_matches_check = true
                    elseif panel.state == "hovering" then
                        -- This panel is no longer hovering.
                        -- it will now fall without sitting around
                        -- for any longer!
                        if self.panels[idx+self.width].color ~= 0 then
                            panel.state = "landing"
                            panel.timer = 12
                            self.do_matches_check = true
                        else
                            panel.state = "falling"
                            self.panels[idx], self.panels[idx+self.width] =
                                self.panels[idx+self.width], self.panels[idx]
                            panel.timer = 0
                            -- Not sure if needed:
                            self.panels[idx]:clear_flags()
                        end
                    elseif panel.state == "landing" then
                        panel.state = "normal"
                    elseif panel.state == "matched" then
                        -- This panel's match just finished the whole
                        -- flashing and looking distressed thing.
                        -- It is given a pop time based on its place
                        -- in the match.
                        panel.state = "popping"
                        panel.timer = panel.combo_index*self.FRAMECOUNT_POP
                    elseif panel.state == "popping" then
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
                            self:set_hoverers(idx-self.width,
                                    self.FRAMECOUNT_HOVER+1,true)
                        else
                            panel.state = "popped"
                            panel.timer = (panel.combo_size-panel.combo_index)
                                    * self.FRAMECOUNT_POP
                        end
                        --something = panel.chain_index
                        --if(something == 0) then something=1 end
                        -- SFX_Pop_Play[0] = something;
                        -- SFX_Pop_Play[1] = whatever;
                        -- TODO: wtf are these
                    elseif panel.state == "popped" then
                        -- It's time for this panel
                        -- to be gone forever :'(
                        if panel.chaining then
                            self.n_chain_panels = self.n_chain_panels - 1
                        end
                        panel.color = 0
                        panel:clear_flags()
                        -- Any panels sitting on top of it
                        -- hover and are flagged as CHAINING
                        self:set_hoverers(idx-self.width,self.FRAMECOUNT_HOVER+1,true);
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
    if self.cur_dir and (self.cur_timer == 0 or
        self.cur_timer == self.cur_wait_time) then
        self.cur_row = bound(0, self.cur_row + d_row[self.cur_dir],
                        self.bottom_row)
        self.cur_col = bound(0, self.cur_col + d_col[self.cur_dir],
                        self.width - 2)
    end
    if self.cur_timer ~= self.cur_wait_time then
        self.cur_timer = self.cur_timer + 1
        --if(self.move_sound and self.cur_timer == 0) then SFX_P1Cursor_Play=1 end
        --TODO:SFX
    end

    -- SWAPPING
    if self.swap_1 or self.swap_2 then
        local idx = (self.cur_row*self.width) + self.cur_col + 1 --Since both of these are 0-indexed.
        -- in order for a swap to occur, one of the two panels in
        -- the cursor must not be a non-panel.
        local do_swap = (self.panels[idx].color ~= 0 or
                            self.panels[idx+1].color ~= 0) and
        -- also, both spaces must be swappable.
            (not self.panels[idx]:exclude_swap()) and
            (not self.panels[idx+1]:exclude_swap()) and
        -- also, neither space above us can be hovering.
            (self.cur_row == 0 or (self.panels[idx-self.width].state ~=
                "hovering" and self.panels[idx-self.width+1].state ~=
                "hovering"))
        -- If you have two pieces stacked vertically, you can't move
        -- both of them to the right or left by swapping with empty space.
        if self.panels[idx].color == 0 or self.panels[idx+1].color == 0 then
            do_swap = do_swap and not (self.cur_row > 0 and
                (self.panels[idx-self.width].state == "swapping" and
                    self.panels[idx-self.width+1].state == "swapping") and
                (self.panels[idx-self.width].color == 0 or
                    self.panels[idx-self.width+1].color == 0) and
                (self.panels[idx-self.width].color ~= 0 or
                    self.panels[idx-self.width+1].color ~= 0))
            do_swap = do_swap and not (self.cur_row ~= self.bottom_row and
                (self.panels[idx+self.width].state == "swapping" and
                    self.panels[idx+self.width+1].state == "swapping") and
                (self.panels[idx+self.width].color == 0 or
                    self.panels[idx+self.width+1].color == 0) and
                (self.panels[idx+self.width].color ~= 0 or
                    self.panels[idx+self.width+1].color ~= 0))
        end

        if do_swap then
            self.panels[idx], self.panels[idx+1] =
                self.panels[idx+1], self.panels[idx]
            local tmp_chaining = self.panels[idx].chaining
            self.panels[idx]:clear_flags()
            self.panels[idx].state = "swapping"
            self.panels[idx].chaining = tmp_chaining
            tmp_chaining = self.panels[idx+1].chaining
            self.panels[idx+1]:clear_flags()
            self.panels[idx+1].state = "swapping"
            self.panels[idx+1].is_swapping_from_left = true
            self.panels[idx+1].chaining = tmp_chaining

            self.panels[idx].timer = 3
            self.panels[idx+1].timer = 3

            --SFX_Swap_Play=1;
            --lol SFX

            -- If you're swapping a panel into a position
            -- above an empty space or above a falling piece
            -- then you can't take it back since it will start falling.
            if self.cur_row ~= self.bottom_row then
                if (self.panels[idx].color ~= 0) and (self.panels[idx+self.width].color
                        == 0 or self.panels[idx+self.width].state == "falling") then
                    self.panels[idx].dont_swap = true
                end
                if (self.panels[idx+1].color ~= 0) and (self.panels[idx+self.width+1].color
                        == 0 or self.panels[idx+self.width+1].state == "falling") then
                    self.panels[idx+1].dont_swap = true
                end
            end

            -- If you're swapping a blank space under a panel,
            -- then you can't swap it back since the panel should
            -- start falling.
            if self.cur_row > 0 then
                if self.panels[idx].color == 0 and
                        self.panels[idx-self.width].color ~= 0 then
                    self.panels[idx].dont_swap = true
                end
                if self.panels[idx+1].color == 0 and
                        self.panels[idx-self.width+1].color ~= 0 then
                    self.panels[idx+1].dont_swap = true
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
        local idx = row*self.width + 1
        for col=1,self.width do
            if self.panels[idx].state == "falling" then
                -- if it's on the bottom row, it should surely land
                if row == self.bottom_row then
                    self.panels[idx].state = "landing"
                    self.panels[idx].timer = 12
                    self.do_matches_check = true
                    --SFX_Land_Play=1;
                    --SFX LAWL
                elseif self.panels[idx+self.width].color ~= 0 then
                    -- if there's a panel below, this panel's gonna land
                    -- unless the panel below is falling.
                    if self.panels[idx+self.width].state ~= "falling" then
                        -- if it lands on a hovering panel, it inherits
                        -- that panel's hover time.
                        if self.panels[idx+self.width].state == "hovering" then
                            self.panels[idx].state = "normal"
                            self:set_hoverers(idx,self.panels[idx+self.width].timer,false)
                        else
                            self.panels[idx].state = "landing"
                            self.panels[idx].timer = 12
                        end
                        self.do_matches_check = true
                        --SFX_Land_Play=1;
                        --SFX LEWL
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

    for panel=1,self.size do
        self.panels[panel].matching = false
    end
    -- check vertical matches
    count = 0
    for col=1,self.width do
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
                                if(not self.panels[panel-self.width].matching) then
                                    self.panels[panel-self.width].matching = true
                                    if(self.panels[panel-self.width].chaining) then
                                        is_chain = true
                                    end
                                    combo_size = combo_size + 1
                                end
                                if(not self.panels[panel-2*self.width].matching) then
                                    self.panels[panel-2*self.width].matching = true
                                    if(self.panels[panel-2*self.width].chaining) then
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
            panel = panel + self.width
        end
    end

         -- check horizontal matches
    count = 0
    panel = 0
    for row=0,self.bottom_row do
        old_panel = 0
        panel = row * self.width + 1
        for col=1,self.width do
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
        panel = (row+1)*self.width
        for col=self.width-1,0,-1 do
            if(self.panels[panel].matching) then
                self.panels[panel].state = "matched"
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
                            something=self.panels[panel+self.width].state
                                    == "swapping"
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
                    self.stop_time = self.stop_time + stop_time_chain
                        [(self.panels_in_top_row and 2) or 1][self.difficulty]
                else
                    self.stop_time = self.stop_time + stop_time_combo
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
            if(self.panels[panel].state == "swapping") then
                hovers_time = hovers_time + self.panels[panel].timer
            end
            something = self.panels[panel].chaining
            self.panels[panel]:clear_flags()
            self.panels[panel].state = "hovering"
            self.panels[panel].chaining = something or add_chaining
            self.panels[panel].timer = hovers_time
            if((not something) and (add_chaining)) then
                self.n_chain_panels = self.n_chain_panels + 1
            end
        end
        panel = panel - self.width
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
            if(self.panels[panel].state == "swapping") then
                hovers_time = hovers_time + self.panels[panel].timer
            end
            something = self.panels[panel].chaining
            self.panels[panel]:clear_flags()
            self.panels[panel].state = "hovering"
            self.panels[panel].chaining = add_chaining or something
            self.panels[panel].timer = hovers_time+not_first
            if((not something) and (add_chaining)) then
                self.n_chain_panels = self.n_chain_panels + 1
            end
            not_first = 1
        end
        panel = panel - self.width
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
    local taking_these = {}
    for i=1,self.width do
        self.panels[i]:clear()
        taking_these[i+(self.size-self.width)] = self.panels[i]
    end
    -- move panels up
    for panel=1,self.size-self.width do
        self.panels[panel]=self.panels[panel+self.width];
    end
    -- put bottom row into play
    for panel=self.size-2*self.width+1,self.size-self.width do
        self.panels[panel].state = "normal"
    end

    if string.len(self.panel_buffer) < self.width then
        error("Ran out of buffered panels.  Is the server down?")
    end
    -- generate a new row
    for panel=self.size-self.width+1,self.size do
        self.panels[panel] = taking_these[panel]
        local idx = panel - (self.size-self.width)
        self.panels[panel].color = string.sub(self.panel_buffer,idx,idx)+0
        self.panels[panel].state = "dimmed"
    end
    self.panel_buffer = string.sub(self.panel_buffer,7)
    if string.len(self.panel_buffer) <= 10*self.width then
        ask_for_panels(string.sub(self.panel_buffer,-6))
    end
    self.displacement = 16
    self.bottom_row = self.height - 2
    self.do_matches_check = true
end

function quiet_cursor_movement()
    if self.cur_timer == 0 then
        return
    end
     -- the cursor will move if a direction's was just pressed or has been
     -- pressed for at least the self.cur_wait_time
    self.move_sound = true
    if self.cur_dir and (self.cur_timer == 1 or
        self.cur_timer == self.cur_wait_time) then
        self.cur_row = bound(0, self.cur_row + d_row[self.cur_dir],
                        self.bottom_row)
        self.cur_col = bound(0, self.cur_col + d_col[self.cur_dir],
                        self.width - 2)
    end
    if self.cur_timer ~= self.cur_wait_time then
        self.cur_timer = self.cur_timer + 1
    end
end

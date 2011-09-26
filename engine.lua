  -- Stuff defined in this file:
  --  . the data structures that store the configuration of
  --    the stack of panels
  --  . the main game routine
  --    (rising, timers, falling, cursor movement, swapping, landing)
  --  . the matches-checking routine
local min = math.min
local garbage_bounce_time = #garbage_bounce_table

Stack = class(function(s, mode, speed, difficulty)
    s.mode = mode or "endless"
    if s.mode == "2ptime" or s.mode == "vs" then
      local level = speed
      speed = level_to_starting_speed[level]
      difficulty = level_to_difficulty[level]
      s.max_hang_time = level_to_hang_time[level]
      if s.mode == "2ptime" then
        s.NCOLORS = level_to_ncolors_time[level]
      else
        s.NCOLORS = level_to_ncolors_vs[level]
      end
    end

    s.garbage_cols = {{1,2,3,4,5,6,idx=1},
                      {1,3,5,idx=1},
                      {1,4,idx=1},
                      {1,2,3,idx=1},
                      {1,2,idx=1},
                      {1,idx=1}}
    s.pos_x = 4   -- Position of the play area on the screen
    s.pos_y = 4
    s.score_x = 315
    s.panel_buffer = ""
    s.input_buffer = ""
    s.panels = {}
    s.width = 6
    s.height = 12
    s.size = s.width * s.height
    for i=0,s.height do
      s.panels[i] = {}
      for j=1,s.width do
        s.panels[i][j] = Panel()
      end
    end

    s.CLOCK = 0

    s.max_runs_per_frame = 3

    s.displacement = 16
    -- This variable indicates how far below the top of the play
    -- area the top row of panels actually is.
    -- This variable being decremented causes the stack to rise.
    -- During the automatic rising routine, if this variable is 0,
    -- it's reset to 15, all the panels are moved up one row,
    -- and a new row is generated at the bottom.
    -- Only when the displacement is 0 are all 12 rows "in play."


    s.danger_col = {false,false,false,false,false,false}
    -- set true if this column is near the top
    s.danger_timer = 0   -- decides bounce frame when in danger

    s.difficulty = difficulty or 2

    s.speed = speed or 24   -- The player's speed level decides the amount of time
             -- the stack takes to rise automatically
    s.panels_to_speedup = panels_to_next_speed[s.speed]
    s.rise_timer = 1   -- When this value reaches 0, the stack will rise a pixel
    s.rise_lock = false   -- If the stack is rise locked, it won't rise until it is
              -- unlocked.
    s.has_risen = false   -- set once the stack rises once during the game

    s.stop_time = 0
    s.stop_time_timer = 0

    s.game_time = 0
    s.game_time_mode = 1
    s.game_time_timer = 0

    s.NCOLORS = s.NCOLORS or 5
    s.score = 0         -- der skore
    s.chain_counter = 0   -- how high is the current chain?

    s.panels_in_top_row = false -- boolean, for losing the game
    s.danger = false  -- boolean, panels in the top row (danger)
    s.danger_music = false -- changes music state

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
    s.cur_row = 7  -- the row the cursor's on
    s.cur_col = 3  -- the column the left half of the cursor's on
    s.top_cur_col = s.height + (s.mode == "puzzle" and 0 or -1)

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

    self.initial_time = nil
    self.pop_time = nil
    self.x_offset = nil
    self.y_offset = nil
    self.width = nil
    self.height = nil
    self.garbage = nil
    self.metal = nil

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
  local exclude_hover_set = {matched=true, popping=true, popped=true,
      hovering=true, falling=true, swapping=true}
  function Panel.exclude_hover(self)
    return exclude_hover_set[self.state] or self.garbage
  end

  local exclude_match_set = {swapping=true, matched=true, popping=true,
      popped=true, hovering=true, dimmed=true, falling=true}
  function Panel.exclude_match(self)
    return exclude_match_set[self.state] or self.color == 0 or self.color == 9
      or (self.state == "landing" and self.timer == 12)
  end

  local exclude_swap_set = {matched=true, popping=true, popped=true,
      hovering=true, dimmed=true}
  function Panel.exclude_swap(self)
    return exclude_swap_set[self.state] or self.dont_swap or self.garbage
  end

  function Panel.support_garbage(self)
    return self.color ~= 0 or self.hovering
  end

  local block_garbage_fall_set = {matched=true, popping=true,
      popped=true, hovering=true, swapping=true}
  function Panel.block_garbage_fall(self)
    return block_garbage_fall_set[self.state] or self.color == 0
  end

  function Panel.dangerous(self)
    return self.color ~= 0 and (self.state ~= "falling" or not self.garbage)
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

function Stack.set_puzzle_state(self, pstr, n_turns)
  -- Copy the puzzle into our state
  while string.len(pstr) < self.size do
    pstr = "0" .. pstr
  end
  local idx = 1
  local panels = self.panels
  for row=self.height,1,-1 do
    for col=1, self.width do
      panels[row][col]:clear()
      panels[row][col].color = string.sub(pstr, idx, idx) + 0
      idx = idx + 1
    end
  end
  self.puzzle_moves = n_turns
end

function Stack.puzzle_done(self)
  local panels = self.panels
  for row=1, self.height do
    for col=1, self.width do
      local color = panels[row][col].color
      if color ~= 0 and color ~= 9 then
        return false
      end
    end
  end
  return true
end

function Stack.prep_first_row(self)
  if self.CLOCK == 0 and self.mode ~= "puzzle" then
    self:new_row()
    self.cur_row = self.cur_row-1
  end
end

--local_run is for the stack that belongs to this client.
function Stack.local_run(self)
  send_controls()
  controls(self)
  self:prep_first_row()
  self:PdP()
  self.CLOCK = self.CLOCK + 1
end

--foreign_run is for a stack that belongs to another client.
function Stack.foreign_run(self)
  local times_to_run = min(string.len(self.input_buffer),
      self.max_runs_per_frame)
  for i=1,times_to_run do
    fake_controls(self, string.sub(self.input_buffer,1,1))
    self:prep_first_row()
    self:PdP()
    self.CLOCK = self.CLOCK + 1
    self.input_buffer = string.sub(self.input_buffer,2)
  end
end

function Stack.enqueue_card(self, chain, x, y, n)
  self.card_q:push({frame=1, chain=chain, x=x, y=y, n=n})
end

local d_col = {up=0, down=0, left=-1, right=1}
local d_row = {up=1, down=-1, left=0, right=0}

-- The engine routine.
function Stack.PdP(self)
  local panels = self.panels
  local width = self.width
  local height = self.height
  local prow = nil
  local panel = nil

  -- TODO: We should really only have one variable for this shit.
  if self.stop_time ~= 0 then
    self.stop_time_timer = self.stop_time_timer - 1
    if self.stop_time_timer == 0 then
      self.stop_time = self.stop_time - 1
      if self.stop_time ~= 0 then
        self.stop_time_timer=60
      end
    end
  end

  self.panels_in_top_row = false
  local top_row = self.height--self.displacement%16==0 and self.height or self.height-1
  prow = panels[top_row]
  for idx=1,width do
    if prow[idx]:dangerous() then
      self.panels_in_top_row = true
    end
  end

  -- calculate which columns should bounce
  self.danger = false
  prow = panels[self.height-1]
  for idx=1,width do
    if prow[idx]:dangerous() then
      self.danger = true
      self.danger_col[idx] = true
    else
      self.danger_col[idx] = false
    end
  end
  if self.danger and self.stop_time == 0 then
    self.danger_timer = self.danger_timer - 1
    if self.danger_timer<0 then
      self.danger_timer=17
    end
  end

  -- determine whether to play danger music
  self.danger_music = false
  prow = panels[self.height-2]
  for idx=1,width do
    if prow[idx]:dangerous() then
      self.danger_music = true
    end
  end
  --[[
  if(self.danger_music) then
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

  if self.displacement == 0 and self.has_risen then
    self:new_row()
  end

  if self.n_active_panels ~= 0 then
    self.rise_lock = true
  else
    self.rise_lock = false
  end

  if self.panels_in_top_row and
      not self.rise_lock and self.stop_time == 0 then
    self.game_over = true
  end

  -- Increase the speed if applicable
  if self.panels_to_speedup <= 0 then
    self.speed = self.speed + 1
    self.panels_to_speedup = self.panels_to_speedup +
      panels_to_next_speed[self.speed]
    self.FRAMECOUNT_RISE = speed_to_rise_time[self.speed]
  end

  -- Phase 0 //////////////////////////////////////////////////////////////
  -- Stack automatic rising

  if self.speed ~= 0 and not self.manual_raise and self.stop_time == 0
      and not self.rise_lock and self.mode ~= "puzzle" then
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
          self:new_row()
        end
      end
      self.rise_timer = self.rise_timer + self.FRAMECOUNT_RISE
    end
  end

  -- Phase 2. /////////////////////////////////////////////////////////////
  -- Timer-expiring actions + falling
  local propogate_fall = {false,false,false,false,false,false}
  local skip_col = 0
  for row=1,#panels do
    for col=1,width do
      local cntinue = false
      if skip_col > 0 then
        skip_col = skip_col - 1
        cntinue=true
      end
      -- first of all, we do Nothin' if we're not even looking
      -- at a space with any flags.
      panel = panels[row][col]
      if cntinue then
      elseif panel.garbage then
        -- TODO: also deal with matching/popping garbage....
        if panel.state == "matched" then
          panel.timer = panel.timer - 1
          if panel.timer == 0 then
            if panel.y_offset == -1 then
              local color, chaining = panel.color, panel.chaining
              panel:clear()
              panel.color, panel.chaining = color, chaining
              self:set_hoverers(row,col,1,false,true)
            else
              panel.state = "normal"
            end
          end
        -- try to fall
        elseif (panel.state=="normal" or panel.state=="falling")
            and panel.x_offset==0 and panel.y_offset==0 then
          local prow = panels[row-1]
          local supported = false
          for i=col,col+panel.width-1 do
            supported = supported or prow[i]:support_garbage()
          end
          if supported then
            for x=col,col-1+panel.width do
              for y=row,row-1+panel.height do
                panels[y][x].state = "normal"
              end
            end
          else
            skip_col = panel.width-1
            for x=col,col-1+panel.width do
              panels[row-1][x]:clear()
              propogate_fall[x] = true
              for y=row,row-1+panel.height do
                panels[y][x].state = "falling"
                panels[y-1][x], panels[y][x] =
                  panels[y][x], panels[y-1][x]
              end
            end
          end
        end
        cntinue = true
      end
      if propogate_fall[col] and not cntinue then
        if panel:block_garbage_fall() then
          propogate_fall[col] = false
        else
          panel.state = "falling"
          panel.timer = 0
        end
      end
      if cntinue then
      elseif panel.state == "falling" then
        -- if it's on the bottom row, it should surely land
        if row == 1 then
          panel.state = "landing"
          panel.timer = 12
          --SFX_Land_Play=1;
          --SFX LAWL
        -- if there's a panel below, this panel's gonna land
        -- unless the panel below is falling.
        elseif panels[row-1][col].color ~= 0 and
            panels[row-1][col].state ~= "falling" then
          -- if it lands on a hovering panel, it inherits
          -- that panel's hover time.
          if panels[row-1][col].state == "hovering" then
            panel.state = "normal"
            self:set_hoverers(row,col,panels[row-1][col].timer,false,false)
          else
            panel.state = "landing"
            panel.timer = 12
          end
          --SFX_Land_Play=1;
          --SFX LEWL
        else
          panels[row-1][col], panels[row][col] =
            panels[row][col], panels[row-1][col]
          panels[row][col]:clear()
        end
      elseif panel:has_flags() and panel.timer~=0 then
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
              if row~=1 then
                if panels[row-1][col].color == 0 then
                  self:set_hoverers(row,col,
                      self.FRAMECOUNT_HOVER,false,true)
                  -- if there is no panel beneath this panel
                  -- it will begin to hover.
                  -- CRAZY BUG EMULATION:
                  -- the space it was swapping from hovers too
                  if from_left then
                    if panels[row][col-1].state == "falling" then
                      self:set_hoverers(row,col-1,
                          self.FRAMECOUNT_HOVER,false,true)
                    end
                  else
                    if panels[row][col+1].state == "falling" then
                      self:set_hoverers(row,col+1,
                          self.FRAMECOUNT_HOVER+1,false,false)
                    end
                  end
                elseif panels[row-1][col].state
                    == "hovering" then
                  -- swap may have landed on a hover
                  self:set_hoverers(row,col,
                      self.FRAMECOUNT_HOVER,false,true)
                end
              end
            else
              -- an empty space finished swapping...
              -- panels above it hover
              self:set_hoverers(row+1,col,
                  self.FRAMECOUNT_HOVER+1,false,false)
            end
            -- swap completed, a matches-check will occur this frame.
          elseif panel.state == "hovering" then
            -- This panel is no longer hovering.
            -- it will now fall without sitting around
            -- for any longer!
            if panels[row-1][col].color ~= 0 then
              panel.state = "landing"
              panel.timer = 12
            else
              panel.state = "falling"
              panels[row][col], panels[row-1][col] =
                panels[row-1][col], panels[row][col]
              panel.timer = 0
              -- Not sure if needed:
              panels[row][col]:clear_flags()
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
              self:set_hoverers(row+1,col,
                  self.FRAMECOUNT_HOVER+1,true,false)
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
            self.panels_to_speedup = self.panels_to_speedup - 1
            if panel.chaining then
              self.n_chain_panels = self.n_chain_panels - 1
            end
            panel.color = 0
            panel:clear_flags()
            -- Any panels sitting on top of it
            -- hover and are flagged as CHAINING
            self:set_hoverers(row+1,col,self.FRAMECOUNT_HOVER+1,true,false);
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
    end
  end

  -- Phase 3. /////////////////////////////////////////////////////////////
  -- Actions performed according to player input

  -- CURSOR MOVEMENT
  self.move_sound = false
  if self.cur_dir and (self.cur_timer == 0 or
    self.cur_timer == self.cur_wait_time) then
    self.cur_row = bound(1, self.cur_row + d_row[self.cur_dir],
            self.top_cur_col)
    self.cur_col = bound(1, self.cur_col + d_col[self.cur_dir],
            width - 1)
  end
  if self.cur_timer ~= self.cur_wait_time then
    self.cur_timer = self.cur_timer + 1
    --if(self.move_sound and self.cur_timer == 0) then SFX_P1Cursor_Play=1 end
    --TODO:SFX
  end

  -- SWAPPING
  if self.swap_1 or self.swap_2 then
    local row = self.cur_row
    local col = self.cur_col
    -- in order for a swap to occur, one of the two panels in
    -- the cursor must not be a non-panel.
    local do_swap = (panels[row][col].color ~= 0 or
              panels[row][col+1].color ~= 0) and
    -- also, both spaces must be swappable.
      (not panels[row][col]:exclude_swap()) and
      (not panels[row][col+1]:exclude_swap()) and
    -- also, neither space above us can be hovering.
      (self.cur_row == self.height or (panels[row+1][col].state ~=
        "hovering" and panels[row+1][col+1].state ~=
        "hovering"))
    -- If you have two pieces stacked vertically, you can't move
    -- both of them to the right or left by swapping with empty space.
    -- TODO: This might be wrong if something lands on a swapping panel?
    if panels[row][col].color == 0 or panels[row][col+1].color == 0 then
      do_swap = do_swap and not (self.cur_row ~= self.height and
        (panels[row+1][col].state == "swapping" and
          panels[row+1][col+1].state == "swapping") and
        (panels[row+1][col].color == 0 or
          panels[row+1][col+1].color == 0) and
        (panels[row+1][col].color ~= 0 or
          panels[row+1][col+1].color ~= 0))
      do_swap = do_swap and not (self.cur_row ~= 1 and
        (panels[row-1][col].state == "swapping" and
          panels[row-1][col+1].state == "swapping") and
        (panels[row-1][col].color == 0 or
          panels[row-1][col+1].color == 0) and
        (panels[row-1][col].color ~= 0 or
          panels[row-1][col+1].color ~= 0))
    end

    do_swap = do_swap and (self.puzzle_moves == nil or self.puzzle_moves > 0)

    if do_swap then
      if self.puzzle_moves then
        self.puzzle_moves = self.puzzle_moves - 1
      end
      panels[row][col], panels[row][col+1] =
        panels[row][col+1], panels[row][col]
      local tmp_chaining = panels[row][col].chaining
      panels[row][col]:clear_flags()
      panels[row][col].state = "swapping"
      panels[row][col].chaining = tmp_chaining
      tmp_chaining = panels[row][col+1].chaining
      panels[row][col+1]:clear_flags()
      panels[row][col+1].state = "swapping"
      panels[row][col+1].is_swapping_from_left = true
      panels[row][col+1].chaining = tmp_chaining

      panels[row][col].timer = 3
      panels[row][col+1].timer = 3

      --SFX_Swap_Play=1;
      --lol SFX

      -- If you're swapping a panel into a position
      -- above an empty space or above a falling piece
      -- then you can't take it back since it will start falling.
      if self.cur_row ~= 1 then
        if (panels[row][col].color ~= 0) and (panels[row-1][col].color
            == 0 or panels[row-1][col].state == "falling") then
          panels[row][col].dont_swap = true
        end
        if (panels[row][col+1].color ~= 0) and (panels[row-1][col+1].color
            == 0 or panels[row-1][col+1].state == "falling") then
          panels[row][col+1].dont_swap = true
        end
      end

      -- If you're swapping a blank space under a panel,
      -- then you can't swap it back since the panel should
      -- start falling.
      if self.cur_row ~= self.height then
        if panels[row][col].color == 0 and
            panels[row+1][col].color ~= 0 then
          panels[row][col].dont_swap = true
        end
        if panels[row][col+1].color == 0 and
            panels[row+1][col+1].color ~= 0 then
          panels[row][col+1].dont_swap = true
        end
      end
    end
    self.swap_1 = false
    self.swap_2 = false
  end

  -- MANUAL STACK RAISING
  if self.manual_raise and self.mode ~= "puzzle" then
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

  -- Phase 5. /////////////////////////////////////////////////////////////
  -- If a swap completed, one or more panels landed, or a new row was
  -- generated during this tick, a matches-check is done.
  self:check_matches()


  -- if at the end of the routine there are no chain panels, the chain ends.
  if self.chain_counter ~= 0 and self.n_chain_panels == 0 then
    self.chain_counter=0
  end

  if(self.score>99999) then
    self.score=99999
    -- lol owned
  end

  self.n_active_panels = 0
  for row=1,self.height do
    for col=1,self.width do
      local panel = panels[row][col]
      if (panel.garbage and panel.state == "matched") or
         (panel.color ~= 0 and panel:exclude_hover() and not panel.garbage) or
          panel.state == "swapping" then
        self.n_active_panels = self.n_active_panels + 1
      end
    end
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

  for row=#panels,height+1,-1 do
    local nonempty = false
    local prow = panels[row]
    for col=1,width do
      nonempty = nonempty or (prow[col].color ~= 0)
    end
    if nonempty then
      break
    else
      panels[row]=nil
    end
  end
end

-- drops a width x height garbage.
function Stack.drop_garbage(self, width, height, metal)
  local spawn_row = #self.panels+2
  for i=#self.panels+1,#self.panels+height+1 do
    self.panels[i] = {}
    for j=1,self.width do
      self.panels[i][j] = Panel()
    end
  end
  local cols = self.garbage_cols[width]
  local spawn_col = cols[cols.idx]
  cols.idx = wrap(1, cols.idx+1, #cols)
  for y=spawn_row,spawn_row+height-1 do
    for x=spawn_col,spawn_col+width-1 do
      local panel = self.panels[y][x]
      panel.garbage = true
      panel.color = 9
      panel.width = width
      panel.height = height
      panel.y_offset = y-spawn_row
      panel.x_offset = x-spawn_col
      panel.metal = metal
    end
  end
end

function Stack.check_matches(self)
  local row = 0
  local col = 0
  local count = 0
  local old_color = 0
  local is_chain = false
  local first_panel_row = 0
  local first_panel_col = 0
  local combo_index, garbage_index = 0, 0
  local combo_size, garbage_size = 0, 0
  local something = 0
  local whatever = 0
  local panels = self.panels
  local q, garbage = Queue(), {}
  local seen, seenm = {}, {}

  for col=1,self.width do
    for row=1,self.height do
      panels[row][col].matching = false
    end
  end

  for row=1,self.height do
    for col=1,self.width do
      if row~=1 and row~=self.height and
        --check vertical match centered here.
        (not (panels[row-1][col]:exclude_match() or
                    panels[row][col]:exclude_match() or
                    panels[row+1][col]:exclude_match()))
              and panels[row][col].color ==
                  panels[row-1][col].color
              and panels[row][col].color ==
                  panels[row+1][col].color then
        combo_size = combo_size +
                      (panels[row-1][col].matching and 0 or 1) +
                      (panels[row][col].matching and 0 or 1) +
                      (panels[row+1][col].matching and 0 or 1)
        panels[row-1][col].matching = true
        panels[row][col].matching = true
        panels[row+1][col].matching = true
        is_chain = is_chain or panels[row-1][col].chaining or
                    panels[row][col].chaining or
                    panels[row+1][col].chaining
        q:push({row,col,true,true})
      end
      if col~=1 and col~=self.width and
        --check horiz match centered here.
        (not (panels[row][col-1]:exclude_match() or
                    panels[row][col]:exclude_match() or
                    panels[row][col+1]:exclude_match()))
              and panels[row][col].color ==
                  panels[row][col-1].color
              and panels[row][col].color ==
                  panels[row][col+1].color then
        combo_size = combo_size +
                      (panels[row][col-1].matching and 0 or 1) +
                      (panels[row][col].matching and 0 or 1) +
                      (panels[row][col+1].matching and 0 or 1)
        panels[row][col-1].matching = true
        panels[row][col].matching = true
        panels[row][col+1].matching = true
        is_chain = is_chain or panels[row][col-1].chaining or
                    panels[row][col].chaining or
                    panels[row][col+1].chaining
        q:push({row,col,true,true})
      end
    end
  end

  while q:len() ~= 0 do
    local y,x,normal,metal = unpack(q:pop())
    local panel = panels[y][x]
    if ((panel.garbage and panel.state~="falling") or panel.matching)
        and ((normal and not seen[panel]) or
             (metal and not seenm[panel])) then
      if ((metal and panel.metal) or (normal and not panel.metal))
        and panel.garbage and not garbage[panel] then
        garbage[panel] = true
        garbage_size = garbage_size + 1
      end
      seen[panel] = seen[panel] or normal
      seenm[panel] = seenm[panel] or metal
      if panel.garbage then
        normal = normal and not panel.metal
        metal = metal and panel.metal
      end
      if normal or metal then
        if y~=1 then q:push({y-1, x, normal, metal}) end
        if y~=#panels then q:push({y+1, x, normal, metal}) end
        if x~=1 then q:push({y, x-1, normal, metal}) end
        if x~=self.width then q:push({y,x+1, normal, metal}) end
      end
    end
  end

  --[[for row=1,#panels do
    for col=1,self.width do
      local panel = panels[row][col]
      if garbage[panel] then
        if panel.y_offset == 0 then
          panel.color = math.random(1,self.NCOLORS)
          panel.state = "matching"
          panel.timer = 2
        else
          panel.y_offset = panel.y_offset - 1
          panel.height = panel.height - 1
        end
      end
    end
  end--]]

  if is_chain then
    if self.chain_counter ~= 0 then
      self.chain_counter = self.chain_counter + 1
    else
      self.chain_counter = 2
    end
  end

  local garbage_match_time = self.FRAMECOUNT_MATCH + garbage_bounce_time +
      self.FRAMECOUNT_POP * (combo_size + garbage_size)
  garbage_index=garbage_size-1
  combo_index=combo_size
  for row=1,self.height do
    for col=self.width,1,-1 do
      local panel = panels[row][col]
      if garbage[panel] then
        panel.state = "matched"
        panel.timer = garbage_match_time
        panel.initial_time = garbage_match_time
        panel.pop_time = self.FRAMECOUNT_POP * garbage_index
            + garbage_bounce_time
        panel.y_offset = panel.y_offset - 1
        panel.height = panel.height - 1
        if panel.y_offset == -1 then
          panel.color = math.random(1, self.NCOLORS)
          panel.chaining = true
          self.n_chain_panels = self.n_chain_panels + 1
        end
        garbage_index = garbage_index - 1
      elseif panel.matching then
        panel.state = "matched"
        panel.timer = self.FRAMECOUNT_MATCH
        if is_chain and not panel.chaining then
          panel.chaining = true
          self.n_chain_panels = self.n_chain_panels + 1
        end
        panel.combo_index = combo_index
        panel.combo_size = combo_size
        panel.chain_index = self.chain_counter
        combo_index = combo_index - 1
        if combo_index == 0 then
          first_panel_col = col
          first_panel_row = row
        end
      else
        -- if a panel wasn't matched but was eligible,
        -- we might have to remove its chain flag...!
        if not panel:exclude_match() then
          if row~=1 then
            -- no swapping panel below
            -- so this panel loses its chain flag
            if panels[row-1][col].state ~= "swapping" and
                panel.chaining then
              panel.chaining = false
              self.n_chain_panels = self.n_chain_panels - 1
            end
          -- a panel landed on the bottom row, so it surely
          -- loses its chain flag.
          elseif(panel.chaining) then
            panel.chaining = false
            self.n_chain_panels = self.n_chain_panels - 1
          end
        end
      end
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
      first_panel_row = first_panel_row + 1 -- offset chain cards
    end
    if(is_chain) then
      self:enqueue_card(true, first_panel_col, first_panel_row,
          self.chain_counter)
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
        if self.panels_in_top_row then
          self.stop_time = self.stop_time + stop_time_danger[self.difficulty]
        elseif is_chain then
          self.stop_time = self.stop_time + stop_time_chain[self.difficulty]
        else
          self.stop_time = self.stop_time + stop_time_combo[self.difficulty]
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

function Stack.set_hoverers(self, row, col, hover_time, add_chaining,
    extra_tick)
  -- the extra_tick flag is for use during Phase 1&2,
  -- when panels above the first should be given an extra tick of hover time.
  -- This is because their timers will be decremented once on the same tick
  -- they are set, as Phase 1&2 iterates backward through the stack.
  local not_first = 0   -- if 1, the current panel isn't the first one
  local hovers_time = hover_time
  local brk = row > self.height
  local panels = self.panels
  while not brk do
    local panel = panels[row][col]
    if panel.color == 0 or panel:exclude_hover() or
      panel.state == "hovering" and panel.timer <= hover_time then
      brk = true
    else
      if panel.state == "swapping" then
        hovers_time = hovers_time + panels[row][col].timer
      end
      local chaining = panel.chaining
      panel:clear_flags()
      panel.state = "hovering"
      local adding_chaining = (not chaining) and panel.color~=9 and
          add_chaining
      panel.chaining = chaining or adding_chaining
      panel.timer = hovers_time
      if extra_tick then
        panel.timer = panel.timer + not_first
      end
      if adding_chaining then
        self.n_chain_panels = self.n_chain_panels + 1
      end
      not_first = 1
    end
    row = row + 1
    brk = brk or row > self.height
  end
end

function Stack.new_row(self)
  local panels = self.panels
  -- move cursor up
  self.cur_row = bound(1, self.cur_row + 1, self.top_cur_col)
  -- move panels up
  for row=self.height,1,-1 do
    panels[row],panels[row-1] =
      panels[row-1],panels[row]
  end
  -- put bottom row into play
  for col=1,self.width do
    panels[1][col].state = "normal"
  end

  if string.len(self.panel_buffer) < self.width then
    error("Ran out of buffered panels.  Is the server down?")
  end
  -- generate a new row
  for col=1,self.width do
    local panel = panels[0][col]
    panel:clear()
    panel.color = string.sub(self.panel_buffer,col,col)+0
    panel.state = "dimmed"
  end
  self.panel_buffer = string.sub(self.panel_buffer,7)
  if string.len(self.panel_buffer) <= 10*self.width then
    ask_for_panels(string.sub(self.panel_buffer,-6))
  end
  self.displacement = 16
end

--[[function quiet_cursor_movement()
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
end--]]

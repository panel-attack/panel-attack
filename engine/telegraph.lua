local logger = require("logger")

Telegraph = class(function(self, sender, owner)

    -- Stores the actual queue of garbages in the telegraph but not queued long enough to exceed the "stoppers"
    self.garbage_queue = GarbageQueue(sender)
  
    -- Attacks must stay in the telegraph a certain amount of time before they can be sent, we track this with "stoppers"
    --note: keys for stoppers such as self.stoppers.chain[some_key]
    --will be the garbage block's index in the queue , and value will be the frame the stopper expires).
    --keys for self.stoppers.combo[some_key] will be garbage widths, and values will be frame_to_release
    self.stoppers =  {chain = {}, combo = {}, metal = nil}
    
    self.sender = sender -- The stack that sent this garbage
    self.owner = owner -- The stack that is receiving the garbage
    self.attacks = {} -- A copy of the chains and combos earned used to render the animation of going to the telegraph
    self.pendingGarbage = {} -- Table of garbage that needs to be pushed into the telegraph at specific CLOCK times
  end)
  
  function Telegraph.makeCopy(self)
    local copy = Telegraph(self.sender, self.owner)
    copy.garbage_queue = self.garbage_queue:makeCopy()
    copy.stoppers = deepcpy(self.stoppers)
    copy.attacks = deepcpy(self.attacks)
    copy.sender = self.sender
    copy.pos_x = self.pos_x
    copy.pos_y = self.pos_y
    return copy
  end

  function Telegraph.update(self) 
    if self.pendingGarbage[self.owner.CLOCK] then
      local garbage = self.pendingGarbage[self.owner.CLOCK]
      self:privatePush(unpack(garbage))
      self.pendingGarbage[self.owner.CLOCK] = nil
    end
  end
  
  -- Adds a piece of garbage to the queue
  function Telegraph.push(self, attack_type, attack_size, metal_count, attack_origin_col, attack_origin_row, frame_earned)

    -- If we got the attack in the future, wait to queue it
    if frame_earned > self.owner.CLOCK then
      self.pendingGarbage[frame_earned] = {attack_type, attack_size, metal_count, attack_origin_col, attack_origin_row, frame_earned}
      return
    end

    -- If we got an attack earlier then our current frame, we need to resimulate
    local timesToRun = nil
    local restoreFrame = nil
    if frame_earned < self.owner.CLOCK then
      restoreFrame = self.owner.CLOCK
      self.owner:rollbackToFrame(frame_earned)
      timesToRun = restoreFrame - frame_earned

      -- The garbage that we send this time might (rarely) not be the same
      -- as the garbage we sent before.  Wipe out the garbage we sent before...
      for k, v in pairs(self.owner.garbage_target.telegraph.pendingGarbage) do
        if k >= frame_earned then
          self.owner.garbage_target.telegraph.pendingGarbage[k] = nil
        end
      end
    end

    -- Now push this attack
    self:privatePush(attack_type, attack_size, metal_count, attack_origin_col, attack_origin_row, frame_earned)

    -- resimulate if needed now that we have the attack
    if timesToRun then
      for i = 1, timesToRun do
        self.owner:run()
      end
      assert(self.owner.CLOCK == restoreFrame)
    end
  end

  -- Adds a piece of garbage to the queue
  function Telegraph.privatePush(self, attack_type, attack_size, metal_count, attack_origin_col, attack_origin_row, frame_earned)

    print("telegraph.push")
    local x_displacement 
    if not metal_count then
      metal_count = 0
    end
    local stuff_to_send
    if attack_type == "chain" then
      self:grow_chain(frame_earned)
      stuff_to_send = {{6, self.sender.chain_counter-1,false, true}}
    elseif attack_type == "combo" then
      -- get combo_garbage_widths, n_resulting_metal_garbage
      stuff_to_send = self:add_combo_garbage(attack_size, metal_count, frame_earned)
      stuff_to_send = deepcpy(stuff_to_send) -- we don't want to use the same object as in the garbage queue so they don't change each other
    end
    if not self.attacks[frame_earned] then
      self.attacks[frame_earned] = {}
    end
    self.attacks[frame_earned][#self.attacks[frame_earned]+1] =
      {frame_earned=frame_earned, attack_type=attack_type, size=attack_size, origin_col=attack_origin_col, origin_row= attack_origin_row, stuff_to_send=stuff_to_send}

  end
  
  function Telegraph.add_combo_garbage(self, n_combo, n_metal, frame_earned)
    print("Telegraph.add_combo_garbage "..(n_combo or "nil").." "..(n_metal or "nil"))
    local stuff_to_send = {}
    for i=3,n_metal do
      stuff_to_send[#stuff_to_send+1] = {6, 1, true, false, frame_earned = frame_earned}
      self.stoppers.metal = frame_earned+GARBAGE_TRANSIT_TIME+GARBAGE_DELAY
    end
    local combo_pieces = combo_garbage[n_combo]
    for i=1,#combo_pieces do
      stuff_to_send[#stuff_to_send+1] = {combo_pieces[i], 1, false, false, frame_earned = frame_earned}
      self.stoppers.combo[combo_pieces[i]] = frame_earned+GARBAGE_TRANSIT_TIME+GARBAGE_DELAY
    end
    self.garbage_queue:push(stuff_to_send)
    return stuff_to_send
    
  end
  
  function Telegraph.grow_chain(self, frame_earned)
    self.garbage_queue:grow_chain(frame_earned)
    self.stoppers.chain[self.garbage_queue.chain_garbage.last] = frame_earned + GARBAGE_TRANSIT_TIME + GARBAGE_DELAY
    --print(frame_earned)
    --print("in Telegraph.grow_chain")
    --print("table_to_string(self.stoppers.chain):")
    --print(table_to_string(self.stoppers.chain))
    
  end
  
  --to see what's going to be ready at a given frame
  function Telegraph.peek_all_ready_garbage(self, frame)
    return self:pop_all_ready_garbage(frame, true--[[just_peeking]])
  end
  
  function Telegraph.soonest_stopper(self)
    local ret
    ret = self.stoppers.chain[1] or self.stoppers.combo[1] or self.stoppers.metal or nil
    return ret
  end
  
  -- Returns all the garbage that is ready to be sent.
  --
  -- We are recreating specific logic for what garbage is delayed.
  --
  -- A combo won't delay a chain
  -- A chain will delay a combo, combo goes on top
  
  -- Metal won't delay a combo
  -- Combo delays a metal, metal goes on top
  function Telegraph.pop_all_ready_garbage(self, time_to_check, just_peeking)
    local ready_garbage = {}
    local n_chain_stoppers, n_combo_stoppers = 0, 0 -- count of stoppers remaining
    local subject = self
    assert(time_to_check ~= nil)

    if just_peeking then
      subject = self:makeCopy()
    end
    --remove any chain stoppers that expire this frame,
    for chain_idx, chain_release_frame in pairs(subject.stoppers.chain) do
      if self.which == 1 then
        print("releasting")
      end
      if chain_release_frame <= time_to_check then
        print("in Telegraph.pop_all_ready_garbage")
        print("removing a stopper")
        subject.stoppers.chain[chain_idx] = nil
      else
        n_chain_stoppers = n_chain_stoppers + 1
      end
    end
  
    --remove any combo stoppers that expire this frame,
    for combo_garbage_width, combo_release_frame in pairs(subject.stoppers.combo) do
      if combo_release_frame <= time_to_check then
        subject.stoppers.combo[combo_garbage_width] = nil
      else 
        n_combo_stoppers = n_combo_stoppers + 1
      end
    end
  
    --remove the metal stopper if it expires this frame
    if subject.stoppers.metal and subject.stoppers.metal <= time_to_check then
      subject.stoppers.metal = nil
    end
    -- print(P1.CLOCK)
    -- print("table_to_string(subject.stoppers.chain):-")
    -- print(table_to_string(subject.stoppers.chain))
    
    while subject.garbage_queue.chain_garbage:peek() do
      -- print("in telegraph.pop_all_ready_garbage")
      -- print("while subject.garbage_queue.chain_garbage:peek()")
      -- print("subject.stoppers.chain[subject.garbage_queue.chain_garbage.first]:")
      -- print(subject.stoppers.chain[subject.garbage_queue.chain_garbage.first])
      -- print("subject.sender.chains.current:")
      -- print(subject.sender.chains.current)
      local sender_could_be_chaining = false --todo investigate this with garbage chains
      --see if we can determine whether the opponent could still be chaining
      if subject.sender.CLOCK >= time_to_check then
        if (not subject.sender.chains.current or (subject.sender.chains.current and subject.sender.chains.current > time_to_check)
            and
           ((subject.sender.chains.last_complete and subject.sender.chain.last_complete.finish <= time_to_check)
             or not subject.sender.chains.last_complete --[[ie: they have not yet finished a chain this round]])) then
          sender_could_be_chaining = false
        end
      end
      if subject.sender.CLOCK < time_to_check and not subject.waiting_on_end_of_chain then
        subject.waiting_on_end_of_chain = time_to_check
      end
      if not subject.stoppers.chain[subject.garbage_queue.chain_garbage.first] and not sender_could_be_chaining then
      -- and 
        -- ( (subject.sender.prev_states[time_to_check] and not subject.sender.prev_states[time_to_check].chains.current)
           -- or 
          -- (subject.sender.CLOCK >= time_to_check and not subject.sender.chains.current) ) then
        print("in Telegraph.pop_all_ready_garbage")
        --print("so there was not a stopper for the first chain now")
        print("popping the first chain")
        ready_garbage[#ready_garbage+1] = subject.garbage_queue:pop()
      else 
        logger.debug("could be chaining or stopper")
        --there was a stopper here or their chain could still be going, stop and return.
        if ready_garbage[1] then
          return ready_garbage
        else
          return nil
        end
      end
    end
  
    for combo_garbage_width=3,6 do
      local n_blocks_of_this_width = subject.garbage_queue.combo_garbage[combo_garbage_width]:len()
      
      local frame_to_release = subject.stoppers.combo[combo_garbage_width]
      if n_blocks_of_this_width > 0 then
        if not frame_to_release then
          for i=1,n_blocks_of_this_width do
            ready_garbage[#ready_garbage+1] = subject.garbage_queue:pop()
          end
        else 
          --there was a stopper here, stop and return
            if ready_garbage[1] then
              return ready_garbage
            else
              return nil
            end
        end
      end
    end
    
    local frame_to_release_metal = subject.stoppers.metal
    while subject.garbage_queue.metal:peek() and not subject.stoppers.metal do
        ready_garbage[#ready_garbage+1] = subject.garbage_queue:pop()
    end
    if ready_garbage[1] then
      return ready_garbage
    else
      return nil
    end
  end
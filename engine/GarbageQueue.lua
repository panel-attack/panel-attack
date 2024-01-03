local logger = require("logger")

GarbageQueue = class(function(s, allowIllegalStuff, mergeComboMetalQueue)
    s.chain_garbage = Queue()
    s.combo_garbage = {Queue(),Queue(),Queue(),Queue(),Queue(),Queue()} --index here represents width, and length represents how many of that width queued
    s.metal = Queue()
    s.illegalStuffIsAllowed = allowIllegalStuff
    s.mergeComboMetalQueue = mergeComboMetalQueue
  end)

  function GarbageQueue.makeCopy(self)
    local other = GarbageQueue(self.illegalStuffIsAllowed, self.mergeComboMetalQueue)
    other.chain_garbage = deepcpy(self.chain_garbage)
    for i=1, 6 do
      other.combo_garbage[i] = deepcpy(self.combo_garbage[i])
    end
    other.metal = deepcpy(self.metal)
    other.ghost_chain = self.ghost_chain
    return other
  end
  
  function GarbageQueue.push(self, garbage)
    if garbage then
      for k,v in pairs(garbage) do
        local width, height, metal, from_chain, finalized = unpack(v)
        if width and height then
          -- this being a global reference really sucks here, now that attackEngines live on match
          -- have to take care of that when getting to it
          if metal and not self.mergeComboMetalQueue then
            self.metal:push(v)
          elseif from_chain or (height > 1 and not self.illegalStuffIsAllowed) then
            if not from_chain then
              error("ERROR: garbage with height > 1 was not marked as 'from_chain'")
            end
            self.chain_garbage:push(v)
            self.ghost_chain = nil
          else
            self.combo_garbage[width]:push(v)
          end
        end
      end
    end
  end
  
  -- Returns the first chain, then combo, then metal, in that order.
  function GarbageQueue.pop(self, just_peeking)
    --check for any chain garbage, and return the first one (chronologically), if any
    local first_chain_garbage = self.chain_garbage:peek()
    if first_chain_garbage then
      if just_peeking then
        return self.chain_garbage:peek()
      else
        local ret = self.chain_garbage:pop()
        if self.chain_garbage:len() == 0 then
          self.ghost_chain = nil
        end
        return ret
      end
    end
    --check for any combo garbage, and return the smallest one, if any
    for k,v in ipairs(self.combo_garbage) do
      if v:peek() then
        if not just_peeking then
          return v:pop()
        end
          --returning {width, height, is_metal, is_from_chain}
        return v:peek()
      end
    end
    --check for any metal garbage, and return one if any
    if self.metal:peek() then
      if not just_peeking then
        return self.metal:pop()
      else
        return self.metal:peek()
      end
    end
    return nil
  end
  
  function GarbageQueue.to_string(self)
    local ret = "Combos:\n"
    for i=6, 3, -1 do
      ret = ret..i.."-wides: "..self.combo_garbage[i]:len().."\n"
    end
      ret = ret.."Chains:\n"
    if self.chain_garbage:peek() then
      --list chain garbage last to first such that the one to fall first is at the bottom of the list (if any).
      for i=self.chain_garbage:len()-1, 0, -1 do 
        --print("in GarbageQueue.to_string. i="..i)
        --print("table_to_string(self.chain_garbage)")
        --print(table_to_string(self.chain_garbage))
        --I've run into a bug where I think the following line errors if there is more than one chain_garbage in the queue... TODO: figure that out.
        if self.chain_garbage[i] then
          local width, height, metal, from_chain = unpack(self.chain_garbage[i])
          ret = ret..height.."-tall\n"
        end
      end
      
      --ret = ret..table_to_string(self.chain_garbage)
    end
    return ret
  end
  
  function GarbageQueue.peek(self)
    return self:pop(true) --(just peeking)
  end
  
  function GarbageQueue.len(self)
    local ret = 0
    ret = ret + self.chain_garbage:len()
    for k,v in ipairs(self.combo_garbage) do
      ret = ret + v:len()
    end
    ret = ret + self.metal:len()
    return ret
  end
  
  -- This is used by the telegraph to increase the size of the chain garbage being built
  -- or add a 6-wide if there is not chain garbage yet in the queue
  function GarbageQueue:grow_chain(timeAttackInteracts, newChain)
    local result = nil
  
    if newChain then
      result = {{6,1,false,true, timeAttackInteracts=timeAttackInteracts, finalized=nil}}
      self:push(result) --a garbage block 6-wide, 1-tall, not metal, from_chain
    else 
      result = self.chain_garbage[self.chain_garbage.first]
      result[2]--[[height]] = result[2]--[[height]] + 1
      result.timeAttackInteracts = timeAttackInteracts
      -- Note we are changing the value inside the queue so no need to pop and insert it.
      self.ghost_chain = result[2] - 1
      result = {result}
    end
  
    return result
  end
  
  --returns the index of the first garbage block matching the requested type and size, or where it would go if it was in the Garbage_Queue.
    --note: the first index for our implemented Queue object is 0, not 1
    --this will return 0 for the first index.
  function GarbageQueue.get_idx_of_garbage(self, garbage_width, garbage_height, is_metal, from_chain)
    local copy = self:makeCopy()
    local idx = -1
    local idx_found = false
  
    local current_block = copy:pop()
    while current_block and not idx_found do
      idx = idx + 1
      if from_chain and current_block[4]--[[from_chain]] and current_block[2]--[[height]] >= garbage_height then
        idx_found = true
      elseif not from_chain and not current_block[4]--[[from_chain]] and current_block[1]--[[width]] >= garbage_width then
        idx_found = true
      end
      current_block = copy:pop()  
    end
    if idx == -1 then
      idx = 0
    end
  
    return idx
  end

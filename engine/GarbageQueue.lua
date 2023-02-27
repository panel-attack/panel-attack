local logger = require("logger")

GarbageQueue = class(function(s)
  s.chainGarbage = Queue()
  s.comboGarbage = {Queue(), Queue(), Queue(), Queue(), Queue(), Queue()} -- index here represents width, and length represents how many of that width queued
  s.metal = Queue()
end)

function GarbageQueue.makeCopy(self)
  local other = GarbageQueue()
  local activeChain = self.chainGarbage:peek()
  if activeChain then
    -- width, height, metal, from_chain, finalized
    other.chainGarbage:push({
      width = activeChain.width,
      height = activeChain.height,
      isMetal = activeChain.isMetal,
      isChain = activeChain.isChain,
      timeAttackInteracts = activeChain.timeAttackInteracts,
      finalized = activeChain.finalized
    })
    for i = self.chainGarbage.first + 1, self.chainGarbage.last do
      other.chainGarbage:push(self.chainGarbage[i])
    end
  end

  for i = 1, 6 do
    for j = self.comboGarbage[i].first, self.comboGarbage[i].last do
      other.comboGarbage[i]:push(self.comboGarbage[i][j])
    end
  end
  for i = self.metal.first, self.metal.last do
    other.metal:push(self.metal[i])
  end
  other.ghostChain = self.ghostChain
  return other
end

function GarbageQueue.push(self, garbageArray)
  if garbageArray then
    for _, garbage in pairs(garbageArray) do
      if garbage.width and garbage.height then
        if garbage.isMetal and
            (GAME.battleRoom.trainingModeSettings == nil or not GAME.battleRoom.trainingModeSettings.mergeComboMetalQueue) then
          self.metal:push(garbage)
        elseif garbage.isChain or (garbage.height > 1 and not GAME.battleRoom.trainingModeSettings) then
          if not garbage.isChain then
            error("ERROR: garbage with height > 1 was not marked as 'from_chain'")
          end
          self.chainGarbage:push(garbage)
          self.ghostChain = nil
        else
          self.comboGarbage[garbage.width]:push(garbage)
        end
      end
    end
  end
end

function GarbageQueue.peek(self)
  local firstChainGarbage = self.chainGarbage:peek()
  if firstChainGarbage then
    return firstChainGarbage
  end

  for i = 1, 6 do
    local firstComboGarbage = self.comboGarbage[i]:peek()
    if firstComboGarbage then
      return firstComboGarbage
    end
  end

  local firstMetalGarbage = self.metal:peek()
  if firstMetalGarbage then
    return firstMetalGarbage
  end

  return nil
end

-- Returns the first chain, then combo, then metal, in that order.
function GarbageQueue.pop(self)
  -- check for any chain garbage, and return the first one (chronologically), if any
  local firstChainGarbage = self.chainGarbage:peek()
  if firstChainGarbage then
    local ret = self.chainGarbage:pop()
    if self.chainGarbage:len() == 0 then
      self.ghostChain = nil
    end
    return ret
  end
  -- check for any combo garbage, and return the smallest one, if any
  for _, v in ipairs(self.comboGarbage) do
    if v:peek() then
      return v:pop()
    end
  end
  -- check for any metal garbage, and return one if any
  if self.metal:peek() then
    return self.metal:pop()
  end
  return nil
end

function GarbageQueue:toString()
  local ret = "Combos:\n"
  for i = 6, 3, -1 do
    ret = ret .. i .. "-wides: " .. self.comboGarbage[i]:len() .. "\n"
  end
  ret = ret .. "Chains:\n"
  if self.chainGarbage:peek() then
    -- list chain garbage last to first such that the one to fall first is at the bottom of the list (if any).
    for i = self.chainGarbage.first, self.chainGarbage.last do
      -- print("in GarbageQueue.toString. i="..i)
      -- print("table_to_string(self.chainGarbage)")
      -- print(table_to_string(self.chainGarbage))
      -- I've run into a bug where I think the following line errors if there is more than one chainGarbage in the queue... TODO: figure that out.
      if self.chainGarbage[i] then
        ret = ret .. self.chainGarbage[i].height .. "-tall\n"
      end
    end

    -- ret = ret..table_to_string(self.chainGarbage)
  end
  return ret
end

function GarbageQueue.len(self)
  local count = 0
  count = count + self.chainGarbage:len()
  for _, v in ipairs(self.comboGarbage) do
    count = count + v:len()
  end
  count = count + self.metal:len()
  return count
end

-- This is used by the telegraph to increase the size of the chain garbage being built
-- or add a 6-wide if there is not chain garbage yet in the queue
function GarbageQueue:growChain(timeAttackInteracts, newChain)
  local result = nil

  if newChain then
    result = {{width = 6, height = 1, isMetal = false, isChain = true, timeAttackInteracts = timeAttackInteracts, finalized = nil}}
    self:push(result)
  else
    result = self.chainGarbage[self.chainGarbage.first]
    result.height = result.height + 1
    result.timeAttackInteracts = timeAttackInteracts
    -- Note we are changing the value inside the queue so no need to pop and insert it.
    self.ghostChain = result.height - 1
    result = {result}
  end

  return result
end

-- returns the index of the first garbage block matching the requested type and size, or where it would go if it was in the Garbage_Queue.
-- note: the first index for our implemented Queue object is 0, not 1
-- this will return 0 for the first index.
function GarbageQueue.getGarbageIndex(self, garbage)
  local copy = self:makeCopy()
  local idx = -1
  local idx_found = false

  local current_block = copy:pop()
  while current_block and not idx_found do
    idx = idx + 1
    if garbage.isChain and current_block.isChain and current_block.height >= garbage.height then
      idx_found = true
    elseif not garbage.isChain and not current_block.isChain and current_block.width >= garbage.width then
      idx_found = true
    end
    current_block = copy:pop()
  end
  if idx == -1 then
    idx = 0
  end

  return idx
end

local logger = require("common.lib.logger")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local Queue = require("common.lib.Queue")
require("table.clear")
require("table.new")
local RollbackBuffer = require("common.engine.RollbackBuffer")

-- +1 to compensate for a compensation someone made
-- the original thought was probably that the attack animation should only start on the frame AFTER the garbage gets queued
-- so all garbage got queued for a clock time 1 frame later than  the actual frame it was earned
-- now we don't do this anymore and the draw code has to be wary of that on his own so that the engine numbers are consistent at least
local STAGING_DURATION = GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME + 1

local function orderChainGarbage(a, b)
  if a.finalized == b.finalized then
    return a.frameEarned > b.frameEarned
  else
    return not a.finalized
  end
end

-- specifies order in the garbage queue if two elements are both combos
-- higher priority garbage is at the end so we can pop it without having to shift indexes
local function orderComboGarbage(a, b)
  -- both are combos
  if a.width ~= b.width then
    -- combos are ordered by width
    return a.width > b.width
  else
    -- same width ordered by time
    -- deviation here, new garbage goes before old garbage so it refreshes their releaseTime
    return a.frameEarned < b.frameEarned
  end
end

--  width
--  height
--  isMetal
--  isChain
--  frameEarned
--  finalized (optional)
-- orders garbage so that priority increases with index
-- higher priority garbage is at the end so we can pop it without having to shift indexes
local function orderGarbage(garbageQueue, treatMetalAsCombo)
  table.sort(garbageQueue, function(a, b)
    if a.isChain == b.isChain then
      if a.isChain then
        return orderChainGarbage(a, b)
      else
        -- we handle exclusively non-chain garbage!
        if a.isMetal == b.isMetal then
          -- both pieces are of the same type
          return orderComboGarbage(a, b)
        else
          -- it's a combo and a shock!
          -- some special case to enable armageddon shenanigans here
          if treatMetalAsCombo then
            -- under this setting, shock and combos are treated as if they were the same!
            return orderComboGarbage(a, b)
          else
            -- otherwise, combo always queues before shock
            return a.isMetal
          end
        end
      end
    else
      -- one is a chain, the other not
      -- chain should get sorted in after the combo
      return not a.isChain
    end
  end)

  return garbageQueue
end

-- Holds garbage in a queue and follows a specific order for which types should be popped out first.
GarbageQueue = class(function(self, allowIllegalStuff, treatMetalAsCombo)
  -- holds all garbage in the staging phase in a continously integer indexed array
  -- garbage is reordered from lowest to highest priority every frame
  self.stagedGarbage = {}
  -- holds all garbage that left staging phase in a non-continously integer indexed hash
  -- the clock time for delivery is used as the index, meaning it has a lot of gaps
  self.garbageInTransit = {}
  -- the garbage history contains references to all garbage that got pushed into this queue
  -- in the order it got pushed
  -- only exists for easier evaluation / testcases
  self.history = {}
  -- holds the clock times for which garbageInTransit has garbage in a continuously integer indexed ordered array
  -- for easier access and order sensitive iteration
  -- all calls to Queue functions should be done via access to the class function: Queue.func(self.transitTimers, args)
  -- that is in order to avoid having to rollback copy the metatable along with the actual content
  self.transitTimers = Queue()
  self.currentChain = nil
  -- illegal stuff means that chains may be queued as combos instead
  self.illegalStuffIsAllowed = allowIllegalStuff
  self.treatMetalAsCombo = treatMetalAsCombo

  -- seems like the rollback method of Stack counts differently
  -- so keep one extra copy to not run out of copies when rewinding stacks in replays
  self.rollbackBuffer = RollbackBuffer(MAX_LAG + 1)
end)

function GarbageQueue:rollbackCopy(frame)
  local copy = self.rollbackBuffer:getOldest()
  if copy then
    table.clear(copy.stagedGarbage)
    copy.currentChain = nil
    table.clear(copy.garbageInTransit)
    Queue.clear(copy.transitTimers)
    -- history does not need to be cleared
  else
    copy =
    {
      stagedGarbage = table.new(#self.stagedGarbage, 0),
      --copy.currentChain = nil,
      garbageInTransit = {},
      --copy.transitTimers = nil,
      history = table.new(#self.history, 0),
    }
  end

  for i = 1, #self.stagedGarbage do
    if self.stagedGarbage[i] == self.currentChain then
      -- the current chain can actually still get modified so we need to deepcopy it
      copy.currentChain = deepcpy(self.currentChain)
      copy.stagedGarbage[i] = copy.currentChain
    else
      -- all other garbage is already immutable and can be copied by reference
      copy.stagedGarbage[i] = self.stagedGarbage[i]
    end
  end

  -- create a copy of the history
  for i = 1, #self.history do
    if self.history[i] == self.currentChain then
      -- only need to make sure to use the deepcopied variant of the current chain as that still changes
      copy.history[i] = copy.currentChain
    else
      -- everything else has already become immutable and can be kept by reference
      copy.history[i] = self.history[i]
    end
  end

  -- TRANSIT INFO IS ONLY KEPT FOR REPLAY REWIND
  -- ONLINE ROLLBACK DOES NOT NEED / WANT THIS INFORMATION 

  -- create a copy of the garbage in transit for rewind
  for i = self.transitTimers.first, self.transitTimers.last do
    local transitFrame = self.transitTimers[i]
    -- garbage in transit is definitely immutable so use the reference
    copy.garbageInTransit[transitFrame] = self.garbageInTransit[transitFrame]
  end

  -- and the access table for transit garbage
  copy.transitTimers = Queue.getShallowCopy(self.transitTimers, copy.transitTimers)

  -- these two should never change during the life time of a garbage queue
  -- copy.illegalStuffIsAllowed = self.illegalStuffIsAllowed
  -- copy.treatMetalAsCombo = self.treatMetalAsCombo

  self.rollbackBuffer:saveCopy(frame, copy)
end

function GarbageQueue:rollbackToFrame(frame)
  assert(self.rollbackBuffer, "Attempted to rollback garbage queue to frame " .. frame .. " but no rollback buffer has been kept")

  local copy = self.rollbackBuffer:rollbackToFrame(frame)

  assert(copy, "Attempted to rollback garbage queue to frame " .. frame .. " but no rollback copy was available")

  self.stagedGarbage = copy.stagedGarbage
  self.currentChain = copy.currentChain
  self.history = copy.history

  -- the transit tables interact with the outside world and are consumed elsewhere
  -- so we cannot roll them back completely as that may lead to duplicate consumption
  -- only eliminate transits that are going to be readded with further pushes and processing
  -- this is somewhat based on the assumption that whenever we rollback surely our consumer must be behind in time
  -- this may not universally work for multiplayer with more than 2 players
  for i = self.transitTimers.last, self.transitTimers.first, -1 do
    local transitFrame = self.transitTimers[i]
    if transitFrame >= frame + GARBAGE_DELAY_LAND_TIME then
      self.garbageInTransit[transitFrame] = nil
      self.transitTimers.last = self.transitTimers.last - 1
    end
  end
end

function GarbageQueue:rewindToFrame(frame)
  assert(self.rollbackBuffer, "Attempted to rewind garbage queue to frame " .. frame .. " but no rollback buffer has been kept")

  local copy = self.rollbackBuffer:rollbackToFrame(frame)

  assert(copy, "Attempted to rewind garbage queue to frame " .. frame .. " but no rollback copy was available")

  self.stagedGarbage = copy.stagedGarbage
  self.currentChain = copy.currentChain
  self.history = copy.history
  self.garbageInTransit = copy.garbageInTransit
  self.transitTimers = copy.transitTimers
end

-- corrects garbage pushed as combo to be flagged as a finalized chain if it is higher than 1 row
-- and the garbage queue is configured to do so
local function correctChainingFlag(garbageQueue, garbage)
  if garbage.height > 1 and garbageQueue.illegalStuffIsAllowed then
    -- even though it's combo garbage, pretend it's a chain
    -- this has the notable advantage that multiple chains can be queued on the same frame
    -- which makes training mode files a little easier to automate
    garbage.isChain = true
    garbage.finalized = true
  end
end

-- garbage is expected to be a table with the values
--  width
--  height
--  isMetal
--  isChain
--  frameEarned
--  finalized (only if pushing chains)
--   for regular chaining you're NOT supposed to use this function
--   use GarbageQueue:addChainLink and GarbageQueue:finalizeCurrentChain instead
function GarbageQueue:push(garbage)
  logger.debug("pushing garbage " .. table_to_string(garbage))
  correctChainingFlag(self, garbage)
  self.stagedGarbage[#self.stagedGarbage+1] = garbage
  self.history[#self.history+1] = garbage

  orderGarbage(self.stagedGarbage, self.treatMetalAsCombo)
  logger.debug(self:toString())
end

-- accepts multiple pieces of garbage in an array
-- garbage is expected to be a table with the values
--  width
--  height
--  isMetal
--  isChain
--  frameEarned
--  finalized (only if pushing chains)
--   for regular chaining you're NOT supposed to use this function
--   use GarbageQueue:addChainLink and GarbageQueue:finalizeCurrentChain instead
function GarbageQueue:pushTable(garbageArray)
  logger.debug("pushing garbage table with " .. #garbageArray .. " entries")
  if garbageArray then
    for _, garbage in ipairs(garbageArray) do
      self:push(garbage)
    end
  end
end

function GarbageQueue:peek()
  return self.stagedGarbage[#self.stagedGarbage]
end

function GarbageQueue:pop()
  -- default value for table.remove is the length, so the last index
  local garbage = table.remove(self.stagedGarbage)
  logger.debug("popping garbage piece\n" .. table_to_string(garbage))
  logger.debug("remaining staged garbage\n" .. self:toString())
  return garbage
end

function GarbageQueue:getOldestFinishedTransitTime()
  return Queue.peek(self.transitTimers)
end

function GarbageQueue:popFinishedTransitsAt(clock)
  if Queue.peek(self.transitTimers) == clock then
    Queue.pop(self.transitTimers)
    return self.garbageInTransit[clock]
  end
end

-- traverses the garbage queue back to front (which is order of priority, high to low)
-- returning all sequential garbage that has not been changed within the staging duration
-- stops the traversal at the first piece of garbage that has not yet stayed the full staging duration
function GarbageQueue:processStagedGarbageForClock(clock)
  -- we don't want to create a table until it is confirmed that garbage is being popped
  -- otherwise we get a lot of unnecessary table garbage
  local poppedGarbage
  for i = #self.stagedGarbage, 1, -1 do
    local garbage = self.stagedGarbage[i]
    if garbage.isChain then
      if not garbage.finalized or garbage.frameEarned + STAGING_DURATION > clock then
        break
      else
        if not poppedGarbage then
          poppedGarbage = {}
        end
        poppedGarbage[#poppedGarbage+1] = table.remove(self.stagedGarbage)
      end
    else
      if garbage.frameEarned + STAGING_DURATION > clock then
        break
      else
        if not poppedGarbage then
          poppedGarbage = {}
        end
        poppedGarbage[#poppedGarbage+1] = table.remove(self.stagedGarbage)
      end
    end
  end

  if poppedGarbage then
    local deliveryTime = clock + GARBAGE_DELAY_LAND_TIME
    self.garbageInTransit[deliveryTime] = poppedGarbage
    Queue.push(self.transitTimers, deliveryTime)
  end
end

function GarbageQueue:toString()
  local garbageQueueString = "Garbage Queue Content\n Staged Garbage" 
  local jsonEncodedGarbage = tableUtils.map(self.stagedGarbage, function(garbage) return json.encode(garbage) end)
  garbageQueueString = garbageQueueString .. table.concat(jsonEncodedGarbage, "\n")
  garbageQueueString = garbageQueueString .. "\n\n Garbage in Delivery\n"
  jsonEncodedGarbage = tableUtils.map(self.garbageInTransit, function(garbage) return table_to_string(garbage) end)
  garbageQueueString = garbageQueueString .. table.concat(jsonEncodedGarbage, "\n")

  return garbageQueueString
end

function GarbageQueue:len()
  return #self.stagedGarbage
end

-- This is used by the telegraph to increase the size of the chain garbage being built
-- or add a 6-wide if there is not chain garbage yet in the queue
function GarbageQueue:addChainLink(frameEarned, row, column)
  if self.currentChain == nil then
    self.currentChain = {
      width = 6,
      height = 1,
      isMetal = false,
      isChain = true,
      frameEarned = frameEarned,
      finalized = false,
      links = {
        [frameEarned] = {
          rowEarned = row,
          colEarned = column,
        }
      },
      linkTimes = {frameEarned}
    }
    self:push(self.currentChain)
  else
    -- currentChain is always part of the queue already (see push in branch above)
    self.currentChain.height = self.currentChain.height + 1
    self.currentChain.frameEarned = frameEarned
    self.currentChain.links[frameEarned] = {
      rowEarned = row,
      colEarned = column,
    }
    self.currentChain.linkTimes[#self.currentChain.linkTimes+1] = frameEarned
  end
end

-- returns the index of the first garbage block matching the requested type and size, or where it would go if it was in the Garbage_Queue.
-- note: the first index for our implemented Queue object is 0, not 1
-- this will return 0 for the first index.
function GarbageQueue:getGarbageIndex(garbage)
  local garbageCount = #self.stagedGarbage
  for i = 1, #self.stagedGarbage do
    if self.stagedGarbage[i] == garbage then
      -- the garbage table is ordered back to front for cheaper element removal
      -- but telegraph expects the next element to pop as the one with the lowest index
      return garbageCount - i
    end
  end

  -- if we ever arrive here, that means there is garbage in the queue that is not in the queue
  error("commence explosion")
end

function GarbageQueue:finalizeCurrentChain(clock)
  logger.debug("Finalizing chain at " .. clock)
  self.currentChain.finalized = true
  self.currentChain.finalizedClock = clock
  self.currentChain = nil
end

return GarbageQueue
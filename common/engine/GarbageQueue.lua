local logger = require("common.lib.logger")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local Queue = require("common.lib.Queue")
require("table.clear")

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


-- tracking a release time actually seems unnecessary as timers don't matter as long as sorting happens correctly
-- meaning later attack times go higher in priority so they automatically stall the pop of any later ones

-- -- updates the releaseTime of the piece of garbage and all garbage after it
-- -- the idea is that no garbage can have a releaseTime smaller than garbage with higher priority
-- -- priority increases with index
-- local function updateReleaseTimes(garbageQueue)
--   local releaseTime = 0
--   for i = #garbageQueue, 1, -1 do
--     if garbageQueue[i].releaseTime == releaseTime then
--     elseif garbageQueue[i].releaseTime > releaseTime then
--       -- so if as expected, releaseTime is higher, refresh releaseTime to check for the next element
--       releaseTime = garbageQueue[i].releaseTime
--     else
--       -- if releaseTime is lower, the element inherits the releaseTime
--       garbageQueue[i].releaseTime = releaseTime
--     end
--   end
-- end

-- Holds garbage in a queue and follows a specific order for which types should be popped out first.
GarbageQueue = class(function(self, allowIllegalStuff, treatMetalAsCombo)
  -- holds all garbage in the staging phase in a continously integer indexed array
  -- garbage is reordered from lowest to highest priority every frame
  self.stagedGarbage = {}
  -- holds all garbage that left staging phase in a non-continously integer indexed hash
  -- the clock time for delivery is used as the index, meaning it has a lot of gaps
  self.garbageInTransit = {}
  -- holds the clock times for which garbageInTransit has garbage in a continuously integer indexed ordered array
  -- for easier access and order sensitive iteration
  self.transitTimers = Queue()
  self.currentChain = nil
  -- a ghost chain keeps the smaller version of a chain thats growing showing in the telegraph while the new chain's attack animation is still animating to the telegraph.
  self.ghostChain = nil
  -- illegal stuff means that chains are queued as combos instead
  self.illegalStuffIsAllowed = allowIllegalStuff
  self.treatMetalAsCombo = treatMetalAsCombo
end)

function GarbageQueue:rollbackCopy(frame)
  if not self.rollbackCopies then
    self.rollbackCopies = {}
    self.copyPool = {}
  end

  local copy
  if #self.copyPool > 0 then
    copy = self.copyPool[#self.copyPool]
    self.copyPool[#self.copyPool] = nil
    table.clear(copy.stagedGarbage)
    table.clear(copy.garbageInTransit)
    copy.transitTimers:clear()
  else
    copy = GarbageQueue()
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

  for clock, garbageTable in pairs(self.garbageInTransit) do
    -- all in-transit garbage is already immutable and can be copied by reference
    copy.garbageInTransit[clock] = garbageTable
  end
  -- shallow copy should be enough as it only holds numbers
  for i = self.transitTimers.first, self.transitTimers.last do
    copy.transitTimers:push(self.transitTimers[i])
  end

  -- these two should never change during the life time of a garbage queue
  -- copy.illegalStuffIsAllowed = self.illegalStuffIsAllowed
  -- copy.treatMetalAsCombo = self.treatMetalAsCombo

  -- ghostChain can get removed from the GarbageQueue later as it is a draw-only prop, completely irrelevant for physics
  copy.ghostChain = self.ghostChain

  self.rollbackCopies[frame] = copy
end

function GarbageQueue:rollbackToFrame(frame)
  if not self.rollbackCopies[frame] then
    error("Attempted to rollback garbage queue to frame " .. frame .. " but no rollback copy was available")
  end

  local copy = self.rollbackCopies[frame]
  self.stagedGarbage = copy.stagedGarbage
  self.garbageInTransit = copy.garbageInTransit
  self.transitTimers = copy.transitTimers
  self.currentChain = copy.currentChain
  self.ghostChain = copy.ghostChain

  for clock, rollbackCopy in pairs(self.rollbackCopies) do
    if clock > frame then
      self.copyPool[#self.copyPool+1] = rollbackCopy
      self.rollbackCopies[clock] = nil
    end
  end
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
--  finalized (optional)
-- for regular chaining you're NOT supposed to use this
-- use GarbageQueue:addChainLink and GarbageQueue:finalizeCurrentChain instead
function GarbageQueue:push(garbage)
  logger.debug("pushing garbage " .. table_to_string(garbage))
  correctChainingFlag(self, garbage)
  self.stagedGarbage[#self.stagedGarbage+1] = garbage

  orderGarbage(self.stagedGarbage, self.treatMetalAsCombo)
  logger.debug(self:toString())
  --updateReleaseTimes(self.stagedGarbage)
end

-- accepts multiple pieces of garbage in an array
-- garbage is expected to be a table with the values
--  width
--  height
--  isMetal
--  isChain
--  frameEarned
--  finalized (optional)
function GarbageQueue:pushTable(garbageArray)
  logger.debug("pushing garbage table with " .. #garbageArray .. " entries")
  if garbageArray then
    for _, garbage in ipairs(garbageArray) do
      self:push(garbage)
    end
    --orderGarbage(self.stagedGarbage, self.treatMetalAsCombo)
    --updateReleaseTimes(self.stagedGarbage)
  end
end

function GarbageQueue:peek()
  return self.stagedGarbage[#self.stagedGarbage]
end

function GarbageQueue:pop()
  -- default value for table.remove is the length, so the last index
  local garbage = table.remove(self.stagedGarbage)
  logger.debug("popping garbage piece " .. table_to_string(garbage))
  logger.debug("remaining staged garbage " .. self:toString())
  return garbage
end

function GarbageQueue:getOldestFinishedTransitTime()
  return self.transitTimers:peek()
end

function GarbageQueue:popFinishedTransitsAt(clock)
  if self.transitTimers:peek() == clock then
    self.transitTimers:pop()
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
    self.transitTimers:push(deliveryTime)
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
    self.currentChain = {width = 6, height = 1, isMetal = false, isChain = true, frameEarned = frameEarned, finalized = false}
    self:push(self.currentChain)
  else
    self.ghostChain = self.currentChain.height
    -- currentChain is always part of the queue already (see push in branch above)
    self.currentChain.height = self.currentChain.height + 1
    self.currentChain.frameEarned = frameEarned
  end
  --updateReleaseTimes(self.stagedGarbage)
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
  self.currentChain = nil
end

return GarbageQueue
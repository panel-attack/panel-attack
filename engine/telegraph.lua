local logger = require("logger")
require("engine.telegraphGraphics")

Telegraph = class(function(self, sender, owner)
  -- Stores the actual queue of garbages in the telegraph but not queued long enough to exceed the "stoppers"
  self.garbageQueue = GarbageQueue(sender)

  -- Attacks must stay in the telegraph a certain amount of time before they can be sent, we track this with "stoppers"
  -- note: keys for stoppers such as self.stoppers.chain[some_key]
  -- will be the garbage block's index in the queue , and value will be the frame the stopper expires).
  -- keys for self.stoppers.combo[some_key] will be garbage widths, and values will be frame_to_release
  self.stoppers = {chain = {}, combo = {}, metal = nil}
  -- The stack that sent this garbage
  self.sender = sender
  -- The stack that is receiving the garbage
  self.owner = owner
  -- A copy of the chains and combos earned used to render the animation of going to the telegraph
  self.attacks = {}
  -- Set when we start a new chain, cleared when the sender is done chaining, used to know if we should grow a chain or start a new one, and to know if we are allowed to send the attack since the sender is done.
  -- (typically sending is prevented by garbage chaining)
  self.senderCurrentlyChaining = false
  self.clonePool = {}

  self.graphics = TelegraphGraphics(self)
end)

function Telegraph:saveClone(toSave)
  self.clonePool[#self.clonePool+1] = toSave
end

function Telegraph:getRecycledInstance()
  local instance
  if #self.clonePool == 0 then
    instance = Telegraph(self.sender, self.owner)
  else
    instance = self.clonePool[#self.clonePool]
    self.clonePool[#self.clonePool] = nil
  end
  return instance
end

function Telegraph.rollbackCopy(source, other)
  if other == nil then
    other = source:getRecycledInstance()
  end

  other.garbageQueue = source.garbageQueue:makeCopy()
  other.stoppers = deepcpy(source.stoppers)
  if config.renderAttacks then
    other.attacks = deepcpy(source.attacks)
  end
  other.senderCurrentlyChaining = source.senderCurrentlyChaining

  -- We don't want saved copies to hold on to stacks, up to the rollback restore to set these back up.
  other.sender = nil
  other.owner = nil
  return other
end

-- Adds a piece of garbage to the queue
function Telegraph:push(garbage, attackOriginCol, attackOriginRow, frameEarned)
  assert(self.sender ~= nil and self.owner ~= nil, "telegraph needs owner and sender set")
  assert(frameEarned == self.sender.CLOCK, "expected sender clock to equal attack")

  self:privatePush(garbage, attackOriginCol, attackOriginRow, frameEarned + 1)
end

-- Adds a piece of garbage to the queue
function Telegraph:privatePush(garbage, attackOriginColumn, attackOriginRow, timeAttackInteracts)
  local garbageToSend
  if garbage.isChain then
    garbageToSend = self:growChain(timeAttackInteracts)
  else
    garbageToSend = self:addComboGarbage(garbage, timeAttackInteracts)
  end
  self:registerAttack(garbageToSend, attackOriginColumn, attackOriginRow, timeAttackInteracts)
end

function Telegraph:registerAttack(garbage, attackOriginColumn, attackOriginRow, timeAttackInteracts)
  if config.renderAttacks then
    if not self.attacks[timeAttackInteracts] then
      self.attacks[timeAttackInteracts] = {}
    end
    -- we don't want to use the same object as in the garbage queue so they don't change each other
    garbage = deepcpy(garbage)
    self.attacks[timeAttackInteracts][#self.attacks[timeAttackInteracts] + 1] = {
      timeAttackInteracts = timeAttackInteracts,
      originColumn = attackOriginColumn,
      originRow = attackOriginRow,
      garbageToSend = garbage
    }
  end
end

function Telegraph:addComboGarbage(garbage, timeAttackInteracts)
  logger.debug("Telegraph.add_combo_garbage " .. (garbage.width or "nil") .. " " .. (garbage.isMetal and "true" or "false"))
  local garbageToSend = {}
  if garbage.isMetal and (GAME.battleRoom.trainingModeSettings == nil or not GAME.battleRoom.trainingModeSettings.mergeComboMetalQueue) then
    garbageToSend[#garbageToSend + 1] = {width = 6, height = 1, isMetal = true, isChain = false, timeAttackInteracts = timeAttackInteracts}
    self.stoppers.metal = timeAttackInteracts + GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME
  else
    garbageToSend[#garbageToSend + 1] = {
      width = garbage.width,
      height = garbage.height,
      isMetal = garbage.isMetal,
      isChain = garbage.isChain,
      timeAttackInteracts = timeAttackInteracts
    }
    self.stoppers.combo[garbage.width] = timeAttackInteracts + GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME
  end
  self.garbageQueue:push(garbageToSend)
  return garbageToSend
end

function Telegraph:chainingEnded(frameEnded)
  logger.debug("Player " .. self.sender.which .. " chain ended at " .. frameEnded)

  if not GAME.battleRoom.trainingModeSettings then
    assert(frameEnded == self.sender.CLOCK, "expected sender clock to equal attack")
  end

  self:privateChainingEnded(frameEnded)
end

function Telegraph:privateChainingEnded(timeAttackInteracts)

  self.senderCurrentlyChaining = false
  local chain = self.garbageQueue.chain_garbage[self.garbageQueue.chain_garbage.last]
  if chain.timeAttackInteracts >= timeAttackInteracts then
    logger.error("Finalizing a chain that ended before it was earned.")
  end
  logger.debug("finalizing chain at " .. timeAttackInteracts)
  chain.finalized = timeAttackInteracts
end

function Telegraph.growChain(self, timeAttackInteracts)
  local newChain = false
  if not self.senderCurrentlyChaining then
    self.senderCurrentlyChaining = true
    newChain = true
  end

  local result = self.garbageQueue:growChain(timeAttackInteracts, newChain)
  self.stoppers.chain[self.garbageQueue.chain_garbage.last] = timeAttackInteracts + GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME
  return result
end

-- Returns all the garbage that is ready to be sent.
--
-- We are recreating specific logic for what garbage is delayed.
--
-- A combo won't delay a chain
-- A chain will delay a combo, combo goes on top

-- Metal won't delay a combo
-- Combo delays a metal, metal goes on top
function Telegraph:popAllReadyGarbage(time)
  local poppedGarbage = {}
  local chainStopperCount = 0
  local comboStopperCount = 0

  -- remove any chain stoppers that expire this frame,
  for chainIndex, chainReleaseFrame in pairs(self.stoppers.chain) do
    if chainReleaseFrame <= time then
      logger.debug("removing a chain stopper at " .. chainReleaseFrame)
      self.stoppers.chain[chainIndex] = nil
    else
      chainStopperCount = chainStopperCount + 1
    end
  end

  -- remove any combo stoppers that expire this frame,
  for comboGarbageWidth, comboReleaseFrame in pairs(self.stoppers.combo) do
    if comboReleaseFrame <= time then
      logger.debug("removing a combo stopper at " .. comboReleaseFrame)
      self.stoppers.combo[comboGarbageWidth] = nil
    else
      comboStopperCount = comboStopperCount + 1
    end
  end

  -- remove the metal stopper if it expires this frame
  if self.stoppers.metal and self.stoppers.metal <= time then
    logger.debug("removing a metal stopper at " .. self.stoppers.metal)
    self.stoppers.metal = nil
  end

  while self.garbageQueue.chain_garbage:peek() do

    if not self.stoppers.chain[self.garbageQueue.chain_garbage.first] and self.garbageQueue.chain_garbage:peek().finalized then
      logger.debug("committing chain at " .. time)
      poppedGarbage[#poppedGarbage + 1] = self.garbageQueue:pop()
    else
      logger.debug("could be chaining or stopper")
      -- there was a stopper here or their chain could still be going, stop and return.
      if poppedGarbage[1] then
        return poppedGarbage
      else
        return nil
      end
    end
  end

  for comboGarbageWidth = 1, 6 do
    local blockCount = self.garbageQueue.combo_garbage[comboGarbageWidth]:len()

    local frame_to_release = self.stoppers.combo[comboGarbageWidth]
    if blockCount > 0 then
      if not frame_to_release then
        logger.debug("committing combo at " .. time)
        for i = 1, blockCount do
          poppedGarbage[#poppedGarbage + 1] = self.garbageQueue:pop()
        end
      else
        -- there was a stopper here, stop and return
        if poppedGarbage[1] then
          return poppedGarbage
        else
          return nil
        end
      end
    end
  end

  while self.garbageQueue.metal:peek() and not self.stoppers.metal do
    logger.debug("committing metal at " .. time)
    poppedGarbage[#poppedGarbage + 1] = self.garbageQueue:pop()
  end

  if poppedGarbage[1] then
    return poppedGarbage
  else
    return nil
  end
end


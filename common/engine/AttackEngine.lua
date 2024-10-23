local logger = require("common.lib.logger")
local class = require("common.lib.class")

-- A pattern for sending garbage
AttackPattern =
  class(
  function(self, width, height, startTime, metal, chain, endsChain)
    self.width = width
    self.height = height
    self.startTime = startTime
    self.endsChain = endsChain
    self.garbage = {width = width, height = height, isMetal = metal or false, isChain = chain}
  end
)

-- An attack engine sends attacks based on a set of rules.
local AttackEngine =
  class(
  function(self, attackSettings, character)
    -- The number of frames before the first attack starts. Note if this is changed after attack patterns are added their times won't be updated.
    self.delayBeforeStart = attackSettings.delayBeforeStart or 0

    -- The number of frames at the end until the whole attack engine repeats.
    self.delayBeforeRepeat = attackSettings.delayBeforeRepeat or 0

    -- Attack patterns that put out a crazy amount of garbage can slow down the game, so by default we don't queue more than 72 attacks
    -- This flag can be optionally set to disable that.
    self.disableQueueLimit = attackSettings.disableQueueLimit or false

    -- whether the metal garbage is treated the same as combo garbage (aka they can mix)
    -- mergeComboMetalQueue is a reference to an old implementation in which different garbage types
    --  were organised in different queues
    --  we're stuck with the name because it is found in config data
    self.treatMetalAsCombo = attackSettings.mergeComboMetalQueue or false

    -- The table of AttackPattern objects this engine will run through.
    self.attackPatterns = {}
    self:addAttackPatternsFromTable(attackSettings.attackPatterns)
    self.attackSettings = attackSettings

    -- the clock to control the continuity of the sending process
    self.clock = 0

    self.outgoingGarbage = GarbageQueue(true, self.treatMetalAsCombo)

    -- a character table (not id) to send sfx, should be nil if no sfx should play
    self.character = character
  end
)

function AttackEngine:addAttackPatternsFromTable(attackPatternsTable)
  for _, values in ipairs(attackPatternsTable) do
    if values.chain then
      if type(values.chain) == "number" then
        for i = 1, values.height do
          self:addAttackPattern(6, i, values.startTime + ((i-1) * values.chain), false, true)
        end
        self:addEndChainPattern(values.startTime + ((values.height - 1) * values.chain) + values.chainEndDelta)
      elseif type(values.chain) == "table" then
        for i, chainTime in ipairs(values.chain) do
          self:addAttackPattern(6, i, chainTime, false, true)
        end
        self:addEndChainPattern(values.chainEndTime)
      else
        error("The 'chain' field in your attack file is invalid. It should either be a number or a list of numbers.")
      end
    else
      self:addAttackPattern(values.width, values.height or 1, values.startTime, values.metal or false, false)
    end
  end
end

function AttackEngine:setGarbageTarget(garbageTarget)
  assert(garbageTarget.stackCanvasWidth ~= nil)
  assert(garbageTarget.mirror_x ~= nil)
  assert(garbageTarget.panelOriginX ~= nil)
  assert(garbageTarget.panelOriginY ~= nil)
  assert(garbageTarget.incomingGarbage ~= nil)

  self.garbageTarget = garbageTarget
  self.garbageTarget.incomingGarbage.illegalStuffIsAllowed = true
  self.garbageTarget.incomingGarbage.treatMetalAsCombo = self.treatMetalAsCombo
end

-- Adds an attack pattern that happens repeatedly on a timer.
-- width - the width of the attack
-- height - the height of the attack
-- start -- the clock frame these attacks should start being sent
-- repeatDelay - the amount of time in between each attack after start
-- metal - if this is a metal block
-- chain - if this is a chain attack
function AttackEngine.addAttackPattern(self, width, height, start, metal, chain)
  assert(width ~= nil and height ~= nil and start ~= nil and metal ~= nil and chain ~= nil)
  local attackPattern = AttackPattern(width, height, self.delayBeforeStart + start, metal, chain, false)
  self.attackPatterns[#self.attackPatterns + 1] = attackPattern
end

function AttackEngine.addEndChainPattern(self, start, repeatDelay)
  local attackPattern = AttackPattern(0, 0, self.delayBeforeStart + start, false, false, true)
  self.attackPatterns[#self.attackPatterns + 1] = attackPattern
end

function AttackEngine.run(self)
  assert(self.garbageTarget, "No target set on attack engine")

  local highestStartTime = self.attackPatterns[#self.attackPatterns].startTime

  -- Finds the greatest startTime value found from all the attackPatterns
  for i = 1, #self.attackPatterns do
    highestStartTime = math.max(self.attackPatterns[i].startTime, highestStartTime)
  end

  local maxChain = 0
  local maxCombo = 0
  local hasMetal = false
  local totalAttackTimeBeforeRepeat = self.delayBeforeRepeat + highestStartTime - self.delayBeforeStart
  if self.disableQueueLimit or self.garbageTarget.incomingGarbage:len() <= 72 then
    for i = 1, #self.attackPatterns do
      if self.clock >= self.attackPatterns[i].startTime then
        local difference = self.clock - self.attackPatterns[i].startTime
        local remainder = difference % totalAttackTimeBeforeRepeat
        if remainder == 0 then
          if self.attackPatterns[i].endsChain then
            if not self.outgoingGarbage.currentChain then
              break
            end
            self.outgoingGarbage:finalizeCurrentChain(self.clock)
          else
            local garbage = self.attackPatterns[i].garbage
            if garbage.isChain then
              self.outgoingGarbage:addChainLink(self.clock, math.random(1, 11), math.random(1, 6))
              local chainCounter = garbage.height + 1
              maxChain = math.max(chainCounter, maxChain)
            else
              garbage.frameEarned = self.clock
              -- we need a coordinate for the origin of the attack animation
              garbage.rowEarned = math.random(1, 11)
              garbage.colEarned = math.random(1, 6)
              maxCombo = garbage.width + 1 -- TODO: Handle combos SFX greather than 7
              self.outgoingGarbage:push(garbage)
            end
            hasMetal = garbage.isMetal or hasMetal
          end
        end
      end
    end
  end

  self.outgoingGarbage:processStagedGarbageForClock(self.clock)
  local garbageDelivery = self.outgoingGarbage:popFinishedTransitsAt(self.clock)
  if garbageDelivery then
    logger.debug("Pushing garbage delivery to incoming garbage queue: " .. table_to_string(garbageDelivery))
    self.garbageTarget.incomingGarbage:pushTable(garbageDelivery)
  end

  local metalCount = 0
  if hasMetal then
    metalCount = 3
  end
  local newComboChainInfo = Stack.attackSoundInfoForMatch(maxChain > 0, maxChain, maxCombo, metalCount)
  if newComboChainInfo and self.character then
    self.character:playAttackSfx(newComboChainInfo)
  end

  self.clock = self.clock + 1
end

function AttackEngine:rollbackCopy(frame)
  self.outgoingGarbage:rollbackCopy(frame)
end

function AttackEngine:rollbackToFrame(frame)
  self.outgoingGarbage:rollbackToFrame(frame)
  self.clock = frame
end

function AttackEngine:rewindToFrame(frame)
  self.outgoingGarbage:rewindToFrame(frame)
  self.clock = frame
end

return AttackEngine
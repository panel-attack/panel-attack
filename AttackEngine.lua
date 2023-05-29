local logger = require("logger")

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
AttackEngine =
  class(
  function(self, delayBeforeStart, delayBeforeRepeat, disableQueueLimit, garbageTarget, sender, character)
    -- The number of frames before the first attack starts. Note if this is changed after attack patterns are added their times won't be updated.
    self.delayBeforeStart = delayBeforeStart 

    -- The number of frames at the end until the whole attack engine repeats.
    self.delayBeforeRepeat = delayBeforeRepeat

    -- Attack patterns that put out a crazy amount of garbage can slow down the game, so by default we don't queue more than 72 attacks
    -- This flag can be optionally set to disable that.
    self.disableQueueLimit = disableQueueLimit

    -- The table of AttackPattern objects this engine will run through.
    self.attackPatterns = {}
    self.clock = 0
    self.character = wait_for_random_character(character)
    self.telegraph = Telegraph(sender)
    self:setGarbageTarget(garbageTarget)
  end
)

function AttackEngine.createEngineForTrainingModeSettings(trainingModeSettings, garbageTarget, opponent, character)
  local delayBeforeStart = trainingModeSettings.delayBeforeStart or 0
  local delayBeforeRepeat = trainingModeSettings.delayBeforeRepeat or 0
  local disableQueueLimit = trainingModeSettings.disableQueueLimit or false
  local attackEngine = AttackEngine(delayBeforeStart, delayBeforeRepeat, disableQueueLimit, garbageTarget, opponent, character)
  attackEngine:addAttackPatternsFromTable(trainingModeSettings.attackPatterns)
  return attackEngine
end

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
  assert(garbageTarget.pos_x ~= nil)
  assert(garbageTarget.pos_y ~= nil)
  assert(garbageTarget.garbage_q ~= nil)
  assert(garbageTarget.receiveGarbage ~= nil)

  self.garbageTarget = garbageTarget
  if self.telegraph then
    self.telegraph:updatePositionForGarbageTarget(garbageTarget)
  end
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
  if self.disableQueueLimit or self.garbageTarget.garbage_q:len() <= 72 then
    for i = 1, #self.attackPatterns do
      if self.clock >= self.attackPatterns[i].startTime then
        local difference = self.clock - self.attackPatterns[i].startTime
        local remainder = difference % totalAttackTimeBeforeRepeat
        if remainder == 0 then
          if self.attackPatterns[i].endsChain then
            self.telegraph:chainingEnded(self.clock)
          else
            local garbage = self.attackPatterns[i].garbage
            if garbage.isChain then
              local chainCounter = garbage.height + 1
              maxChain = math.max(chainCounter, maxChain)
            else
              maxCombo = garbage.width + 1 -- TODO: Handle combos SFX greather than 7
            end
            hasMetal = garbage.isMetal or hasMetal
            self.telegraph:push(garbage, math.random(11, 17), math.random(1, 11), self.clock)
          end
        end
      end
    end
  end

  self.telegraph:popAllAndSendToTarget(self.clock, self.garbageTarget)

  local metalCount = 0
  if hasMetal then
    metalCount = 3
  end
  local newComboChainInfo = Stack.attackSoundInfoForMatch(maxChain > 0, maxChain, maxCombo, metalCount)    
  if newComboChainInfo then
    characters[self.character]:playAttackSfx(newComboChainInfo)
  end

  self.clock = self.clock + 1
end

function AttackEngine.render(self)

  self.telegraph:render()

end
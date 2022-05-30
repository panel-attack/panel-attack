local logger = require("logger")

-- A pattern for sending garbage
AttackPattern =
  class(
  function(self, width, height, startTime, metal, chain, endsChain)
    self.width = width
    self.height = height
    self.startTime = startTime
    self.endsChain = endsChain
    self.garbage = {width, height, metal or false, chain}
  end
)

-- An attack engine sends attacks based on a set of rules.
AttackEngine =
  class(
  function(self, target, delayBeforeStart, delayBeforeRepeat)
    self.target = target
    self.delayBeforeStart = delayBeforeStart
    self.delayBeforeRepeat = delayBeforeRepeat
    self.attackPatterns = {}
    self.clock = 0
  end
)

-- Adds an attack pattern that happens repeatedly on a timer.
-- width - the width of the attack
-- height - the height of the attack
-- start -- the CLOCK frame these attacks should start being sent
-- repeatDelay - the amount of time in between each attack after start
-- metal - if this is a metal block
-- chain - if this is a chain attack
function AttackEngine.addAttackPattern(self, width, height, start, metal, chain)
  --assert(width ~= nil and height ~= nil and start ~= nil and metal ~= nil and chain ~= nil)
  --assert(height == 1 or not chain, "chains should be sent one command at a time")

  local attackPattern = AttackPattern(width, height, self.delayBeforeStart + start, metal, chain, false)
  self.attackPatterns[#self.attackPatterns + 1] = attackPattern
end

function AttackEngine.addEndChainPattern(self, start, repeatDelay)
  local attackPattern = AttackPattern(0, 0, self.delayBeforeStart + start, false, false, true)
  self.attackPatterns[#self.attackPatterns + 1] = attackPattern
end



function AttackEngine.run(self)
  local garbageToSend = {}
  local highestStartTime = self.attackPatterns[#self.attackPatterns].startTime
  
  -- Finds the greatest startTime value found from all the attackPatterns
  for _, patterns in ipairs(self.attackPatterns) do
    highestStartTime = math.max(patterns.startTime, highestStartTime)
  end
  local totalAttackTimeBeforeRepeat = self.delayBeforeRepeat + self.attackPatterns[#self.attackPatterns].startTime - self.delayBeforeStart
  for _, attackPattern in ipairs(self.attackPatterns) do
    if self.clock >= attackPattern.startTime then
      local difference = self.clock - attackPattern.startTime
      local remainder = difference % totalAttackTimeBeforeRepeat
      if remainder == 0 then
        if attackPattern.endsChain then
          self.target.telegraph:chainingEnded(self.target.CLOCK)
        else
          self.target.telegraph:push(attackPattern.garbage, math.random(11, 17), math.random(1, 11), self.target.CLOCK)
        end
      end
    end
  end


  self.clock = self.clock + 1
end

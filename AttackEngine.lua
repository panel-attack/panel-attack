local logger = require("logger")

-- A pattern for sending garbage
AttackPattern =
  class(
  function(self, width, height, start, repeatDelay, attackCount, metal, chain)
    self.width = width
    self.height = height
    self.start = start
    self.attackCount = attackCount
    self.repeatDelay = repeatDelay and math.max(1, repeatDelay) or 1
    self.garbage = {width, height, metal or false, chain}
  end
)

-- An attack engine sends attacks based on a set of rules.
AttackEngine =
  class(
  function(self)
    self.attackPatterns = {}
    self.CLOCK = 0
    self.character = Character.wait_for_random_character(config.character)
    self.telegraph = Telegraph(self) 
    self.pos_x = 200
    self.pos_y = 10
    self.mirror_x = 1
  end
)

function AttackEngine:setTarget(target)
  self.target = target
  self.telegraph:updatePosition(target.pos_x, target.pos_y, target.mirror_x)
end

-- Adds an attack pattern that happens repeatedly on a timer.
-- width - the width of the attack
-- height - the height of the attack
-- start -- the CLOCK frame these attacks should start being sent
-- repeatDelay - the amount of time in between each attack after start
-- attackCount - the number of times to send the attack, nil for infinite
-- metal - if this is a metal block
-- chain - if this is a chain attack
function AttackEngine.addAttackPattern(self, width, height, start, repeatDelay, attackCount, metal, chain)
    local attackPattern = AttackPattern(width, height, start, repeatDelay, attackCount, metal, chain)
    self.attackPatterns[#self.attackPatterns+1] = attackPattern
end

-- 
function AttackEngine.run(self)
  assert(self.target, "No target set on attack engine")
  
  local garbageToSend = {}
  for _, attackPattern in ipairs(self.attackPatterns) do
    local lastAttackTime
    if attackPattern.attackCount then
      lastAttackTime = attackPattern.start + ((attackPattern.attackCount-1) * attackPattern.repeatDelay)
    end
    if self.CLOCK >= attackPattern.start and (attackPattern.attackCount == nil or self.CLOCK <= lastAttackTime) then
      local difference = self.CLOCK - attackPattern.start
      local remainder = difference % attackPattern.repeatDelay
      local origin_column = 17
      local origin_row = 11
      if remainder == 0 then
        if attackPattern.garbage[4] then
          for i = 1,  attackPattern.garbage[2], 1 do
            self.telegraph:push(attackPattern.garbage, origin_column, origin_row, self.CLOCK)
          end
          self.telegraph:chainingEnded(self.CLOCK)
        else
          self.telegraph:push(attackPattern.garbage, origin_column, origin_row, self.CLOCK)
        end
      end
    end
  end

  if self.telegraph then
    self.telegraph:popAllAndSendToTarget(self.CLOCK, self.target)
  end

  self.CLOCK = self.CLOCK + 1
end

function AttackEngine.render(self)

  self.telegraph:render()

end
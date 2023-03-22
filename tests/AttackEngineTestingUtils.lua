local AttackEngineTestingUtils = {}

local function stackRunOverride(self)
  self:updatePanels()

  if self.telegraph then
    local to_send = self.telegraph:popAllReadyGarbage(self.CLOCK)
    if to_send and to_send[1] then
      -- Right now the training attacks are put on the players telegraph, 
      -- but they really should be a seperate telegraph since the telegraph on the player's stack is for sending outgoing attacks.
      local receiver = self.garbage_target or self
      receiver:receiveGarbage(self.CLOCK + GARBAGE_DELAY_LAND_TIME, to_send)
    end
  end

  if self.later_garbage[self.CLOCK] then
    self.garbage_q:pushTable(self.later_garbage[self.CLOCK])
    self.later_garbage[self.CLOCK] = nil
  end

  if self.garbage_q:len() > 0 then
    local garbage = self.garbage_q:peek()
    if self:shouldDropGarbage(garbage) then
      if self:tryDropGarbage(garbage) then
        self.garbage_q:pop()
      end
    end
  end

  self.CLOCK = self.CLOCK + 1
end

local function stackShouldRunOverride(stack, runsSoFar)
  return runsSoFar < 1
end

function AttackEngineTestingUtils.createMatch(attackFile, stackHealth)
  local match = Match("vs")
  match.attackEngine = AttackEngine.createFromSettings(readAttackFile(attackFile))
  local P1 = Stack{which=1, match=match, wantsCanvas=false, is_local=true, panels_dir=config.panels, level=1, character=config.character, inputMethod="controller"}
  P1.health = stackHealth or 100000
  P1.run = stackRunOverride
  P1.shouldRun = stackShouldRunOverride
  match.P1 = P1
  match.attackEngine:setTarget(P1)

  P1:wait_for_random_character()
  P1:starting_state()
end

function AttackEngineTestingUtils.runToFrame(match, frame)
  while match.P1.CLOCK < frame do
    match:run()
  end
  assert(match.P1.CLOCK == frame)
end

-- clears panels until only "count" rows are left
function AttackEngineTestingUtils.reduceRowsTo(stack, count)
  for row = #stack.panels, count do
    for col = 1, stack.width do
      stack.panels[row][col]:clear(true)
    end
  end
end

function AttackEngineTestingUtils.simulateActivity(stack)
  stack.hasActivePanels = function() return true end
end

function AttackEngineTestingUtils.simulateInactivity(stack)
  stack.hasActivePanels = function() return false end
end

return AttackEngineTestingUtils
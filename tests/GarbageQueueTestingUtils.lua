require("save")
local GarbageQueueTestingUtils = {}

-- a reduced version of stackRun that skips on stuff like raise, health sfx, etc. as it's only meant to be on the receiving end of garbage
local function stackRunOverride(self)
  self:updatePanels()

  if self.telegraph then
    local to_send = self.telegraph:pop_all_ready_garbage(self.clock)
    if to_send and to_send[1] then
      -- Right now the training attacks are put on the players telegraph, 
      -- but they really should be a seperate telegraph since the telegraph on the player's stack is for sending outgoing attacks.
      local receiver = self.garbage_target or self
      receiver:receiveGarbage(self.clock + GARBAGE_DELAY_LAND_TIME, to_send)
    end
  end

  if self.later_garbage[self.clock] then
    self.garbage_q:push(self.later_garbage[self.clock])
    self.later_garbage[self.clock] = nil
  end

  if self.garbage_q:len() > 0 then
    if self:shouldDropGarbage() then
      if self:tryDropGarbage(unpack(self.garbage_q:peek())) then
        self.garbage_q:pop()
      end
    end
  end

  self.clock = self.clock + 1
end

local function stackShouldRunOverride(stack, runsSoFar)
  -- always run frame at a time for precision
  return runsSoFar < 1
end

function GarbageQueueTestingUtils.createMatch(stackHealth, attackFile)
  local battleRoom = BattleRoom()
  local match = Match("vs", battleRoom)
  local P1 = Stack{which=1, match=match, wantsCanvas=false, is_local=false, panels_dir=config.panels, level=1, character=config.character, inputMethod="controller"}
  P1.health = stackHealth or 100000
  P1.run = stackRunOverride
  P1.shouldRun = stackShouldRunOverride
  match.P1 = P1

  if attackFile then
    local trainingModeSettings = readAttackFile(attackFile)
    match.attackEngine = AttackEngine.createFromSettings(trainingModeSettings)
    match.attackEngine:setTarget(P1)
    battleRoom.trainingModeSettings = trainingModeSettings
  else
    P1.garbage_target = P1
  end

  P1:wait_for_random_character()
  P1:starting_state()
  -- make some space for garbage to fall
  GarbageQueueTestingUtils.reduceRowsTo(P1, 0)

  -- cause telegraph is very global needy
  GAME.battleRoom = battleRoom
  GAME.match = match
  return match
end

function GarbageQueueTestingUtils.runToFrame(match, frame)
  while match.P1.clock < frame do
    match:run()
  end
  assert(match.P1.clock == frame)
end

-- clears panels until only "count" rows are left
function GarbageQueueTestingUtils.reduceRowsTo(stack, count)
  for row = #stack.panels, count + 1 do
    for col = 1, stack.width do
      stack.panels[row][col]:clear(true)
    end
  end
end

-- fill up panels with non-matching panels until "count" rows are filled
function GarbageQueueTestingUtils.fillRowsTo(stack, count)
  for row = 1, count do
    if not stack.panels[row] then
      stack.panels[row] = {}
      for col = 1, stack.width do
        stack.createPanelAt(row, col)
      end
    end
    for col = 1, stack.width do
      stack.panels[row][col].color = 9
    end
  end
end

function GarbageQueueTestingUtils.simulateActivity(stack)
  stack.hasActivePanels = function() return true end
end

function GarbageQueueTestingUtils.simulateInactivity(stack)
  stack.hasActivePanels = function() return false end
end

function GarbageQueueTestingUtils.sendGarbage(stack, width, height, chain, metal, time)
  -- -1 cause this will get called after the frame ended instead of during the frame
  local frameEarned = time or stack.clock - 1
  local isChain = chain or false
  local isMetal = metal or false

  -- oddly enough telegraph accepts a time as a param for pushing garbage but asserts that time is equal to the stack
  local realClock = stack.clock
  stack.clock = frameEarned
  stack.telegraph:push({width = width, height = height, isChain = isChain, isMetal = isMetal}, 1, 1, frameEarned)
  stack.clock = realClock
end

return GarbageQueueTestingUtils
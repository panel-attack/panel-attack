require("client.src.save")
local Match = require("common.engine.Match")
local GameModes = require("common.engine.GameModes")
local Player = require("client.src.Player")
local LevelPresets = require("client.src.LevelPresets")
local inputs = require("common.lib.inputManager")

local GarbageQueueTestingUtils = {}

local function stackShouldRunOverride(stack, runsSoFar)
  -- always run frame at a time for precision
  return runsSoFar < 1
end

function GarbageQueueTestingUtils.createMatch(stackHealth, attackFile)
  local player = Player.getLocalPlayer()
  local mode
  if attackFile then
    mode = GameModes.getPreset("ONE_PLAYER_TRAINING")
    player:setAttackEngineSettings(readAttackFile(attackFile))
  else
    mode = GameModes.getPreset("ONE_PLAYER_VS_SELF")
  end

  player:setLevel(1)
  local levelData = LevelPresets.getModern(1)
  levelData.maxHealth = stackHealth or 100000
  player:setLevelData(levelData)
  player:restrictInputs(inputs.inputConfigurations[1])
  local match = Match({player}, mode.doCountdown, mode.stackInteraction, mode.winConditions, mode.gameOverConditions, false)
  match:start()
  -- the stack shouldn't die
  match.stacks[1].behaviours.passiveRaise = false
  -- the stack should run only 1 frame per Match:run
  match.stacks[1].shouldRun = stackShouldRunOverride

  -- make some space for garbage to fall
  GarbageQueueTestingUtils.reduceRowsTo(match.stacks[1], 0)

  return match
end

function GarbageQueueTestingUtils.runToFrame(match, frame)
  local stack = match.stacks[1]
  while stack.clock < frame do
    match:run()
    -- garbage only gets popped if there is a target
    -- since we don't have a target, pop manually like match would
    stack.outgoingGarbage:popFinishedTransitsAt(stack.clock)
  end
  assert(stack.clock == frame)
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
  local frameEarned = time or stack.clock
  local isChain = chain or false
  local isMetal = metal or false

  -- oddly enough telegraph accepts a time as a param for pushing garbage but asserts that time is equal to the stack
  local realClock = stack.clock
  stack.clock = frameEarned
  stack.outgoingGarbage:push({
    width = width,
    height = height,
    isMetal = isMetal,
    isChain = isChain,
    frameEarned = stack.clock,
    rowEarned = 1,
    colEarned = 1
  })
  stack.clock = realClock
end

return GarbageQueueTestingUtils
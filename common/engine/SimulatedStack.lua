local logger = require("common.lib.logger")
local Health = require("common.engine.Health")
local StackBase = require("common.engine.StackBase")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local AttackEngine = require("common.engine.AttackEngine")

-- TODO move graphics related functionality to client
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- A simulated stack sends attacks and takes damage from a player, it "loses" if it takes too many attacks.
SimulatedStack = class(function(self, arguments)
  self.panels_dir = config.panels
  self.max_runs_per_frame = 1
  self.multiBarFrameCount = 240

  self.incomingGarbage = GarbageQueue()

  self.stackHeightQuad = GraphicsUtil:newRecycledQuad(0, 0, themes[config.theme].images.IMG_multibar_shake_bar:getWidth(),
                                                      themes[config.theme].images.IMG_multibar_shake_bar:getHeight(),
                                                      themes[config.theme].images.IMG_multibar_shake_bar:getWidth(),
                                                      themes[config.theme].images.IMG_multibar_shake_bar:getHeight())
  self.difficultyQuads = {}
  -- somehow bad things happen if this is called in the base class constructor instead
  self:moveForRenderIndex(self.which)
end, StackBase)

-- adds an attack engine to the simulated opponent
function SimulatedStack:addAttackEngine(attackSettings, shouldPlayAttackSfx)
  if shouldPlayAttackSfx then
    self.attackEngine = AttackEngine(attackSettings, characters[self.character])
  else
    self.attackEngine = AttackEngine(attackSettings)
  end

  self.outgoingGarbage = self.attackEngine.outgoingGarbage

  return self.attackEngine
end

function SimulatedStack:addHealth(healthSettings)
  self.healthEngine = Health(healthSettings.framesToppedOutToLose, healthSettings.lineClearGPM, healthSettings.lineHeightToKill,
                             healthSettings.riseSpeed)
  self.health = healthSettings.framesToppedOutToLose
end

function SimulatedStack:run()
  if self.attackEngine then
    self.attackEngine:run()
  end

  if self.do_countdown and self.countdown_timer > 0 then
    self.healthEngine.clock = self.clock
    if self.clock >= consts.COUNTDOWN_START then
      self.countdown_timer = self.countdown_timer - 1
    end
  else
    if self.healthEngine then
      -- perform the equivalent of queued garbage being dropped
      -- except a little quicker than on real stacks
      for i = #self.incomingGarbage.stagedGarbage, 1, -1 do
        self.healthEngine:receiveGarbage(self.clock, self.incomingGarbage:pop())
      end

      self.health = self.healthEngine:run()
      if self.health <= 0 then
        self:setGameOver()
      end
    end
  end

  self.clock = self.clock + 1
end

function SimulatedStack:runGameOver()
  -- currently nothing, could add kickstart a fancy animation in setGameOver later that is ran to conclusion here
end

function SimulatedStack:setGameOver()
  self.game_over_clock = self.clock

  SoundController:playSfx(themes[config.theme].sounds.game_over)
end

function SimulatedStack:shouldRun(runsSoFar)
  if self:game_ended() then
    return false
  end

  if self.lastRollbackFrame > self.clock then
    return true
  end

  -- a local automated stack shouldn't be falling behind
  if self.framesBehind > runsSoFar then
    return true
  end

  return runsSoFar < self.max_runs_per_frame
end

function SimulatedStack:game_ended()
  if self.healthEngine then
    if self.health <= 0 and self.game_over_clock < 0 then
      self.game_over_clock = self.clock
    end
  end

  if self.game_over_clock > 0 then
    return self.clock >= self.game_over_clock
  else
    return false
  end
end

function SimulatedStack:drawDebug()
  if config.debug_mode then
    local drawX = self.frameOriginX + self:stackCanvasWidth() / 2
    local drawY = 10
    local padding = 14

    GraphicsUtil.drawRectangle("fill", drawX - 5, drawY - 5, 1000, 100, 0, 0, 0, 0.5)
    GraphicsUtil.printf("Clock " .. self.clock, drawX, drawY)

    drawY = drawY + padding
    GraphicsUtil.printf("P" .. self.which .. " Ended?: " .. tostring(self:game_ended()), drawX, drawY)
  end
end

function SimulatedStack:render()
  self:setCanvas()
  self:drawCharacter()
  self:renderStackHeight()
  self:drawFrame()
  self:drawWall(0, 12)
  self:drawCanvas()

  self:drawDebug()
end

function SimulatedStack:renderStackHeight()
  local percentage = self.healthEngine:getTopOutPercentage()
  local xScale = (self:stackCanvasWidth() - 8) / themes[config.theme].images.IMG_multibar_shake_bar:getWidth()
  local yScale = (self.canvas:getHeight() - 4) / themes[config.theme].images.IMG_multibar_shake_bar:getHeight() * percentage

  GraphicsUtil.setColor(1, 1, 1, 0.6)
  GraphicsUtil.drawQuad(themes[config.theme].images.IMG_multibar_shake_bar, self.stackHeightQuad, 4, self.canvas:getHeight(), 0, xScale,
                     -yScale)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function SimulatedStack:saveForRollback()
  local copy

  if self.rollbackCopyPool:len() > 0 then
    copy = self.rollbackCopyPool:pop()
  else
    copy = {}
  end

  self.incomingGarbage:rollbackCopy(self.clock)

  if self.healthEngine then
    self.healthEngine:saveRollbackCopy()
  end

  if self.attackEngine then
    self.attackEngine:rollbackCopy(self.clock)
  end

  copy.health = self.health

  self.rollbackCopies[self.clock] = copy

  local deleteFrame = self.clock - MAX_LAG - 1
  if self.rollbackCopies[deleteFrame] then
    self.rollbackCopyPool:push(self.rollbackCopies[deleteFrame])
    self.rollbackCopies[deleteFrame] = nil
  end
end

local function internalRollbackToFrame(stack, frame)
  local copy = stack.rollbackCopies[frame]

  if copy and frame < stack.clock then
    for f = frame, stack.clock do
      if stack.rollbackCopies[f] then
        stack.rollbackCopyPool:push(stack.rollbackCopies[f])
        stack.rollbackCopies[f] = nil
      end
    end

    if stack.healthEngine then
      stack.healthEngine:rollbackToFrame(frame)
      stack.health = stack.healthEngine.framesToppedOutToLose
    else
      stack.health = copy.health
    end

    return true
  end

  return false
end

function SimulatedStack:rollbackToFrame(frame)
  if internalRollbackToFrame(self, frame) then
    self.incomingGarbage:rollbackToFrame(frame)

    if self.attackEngine then
      self.attackEngine:rollbackToFrame(frame)
    end

    self.lastRollbackFrame = self.clock
    self.clock = frame
    return true
  end

  return false
end

function SimulatedStack:rewindToFrame(frame)
  if internalRollbackToFrame(self, frame) then
    self.incomingGarbage:rewindToFrame(frame)

    if self.attackEngine then
      self.attackEngine:rewindToFrame(frame)
    end

    self.clock = frame
    return true
  end

  return false
end

function SimulatedStack:starting_state()
  if self.do_countdown then
    self.countdown_timer = consts.COUNTDOWN_LENGTH
  end
end

function SimulatedStack:setGarbageTarget(garbageTarget)
  if garbageTarget ~= nil then
    assert(garbageTarget.frameOriginX ~= nil)
    assert(garbageTarget.frameOriginY ~= nil)
    assert(garbageTarget.mirror_x ~= nil)
    assert(garbageTarget.stackCanvasWidth ~= nil)
    assert(garbageTarget.incomingGarbage ~= nil)
  end
  self.garbageTarget = garbageTarget
  if self.attackEngine then
    self.attackEngine:setGarbageTarget(garbageTarget)
  end
end

function SimulatedStack:getAttackPatternData()
  if self.attackEngine then
    return self.attackEngine.attackSettings
  end
end

function SimulatedStack:drawScore()
  -- no fake score for simulated stacks yet
  -- could be fun for fake 1p time attack vs later on, lol
end

function SimulatedStack:drawSpeed()
  if self.healthEngine then
    self:drawLabel(themes[config.theme].images["IMG_speed_" .. self.which .. "P"], themes[config.theme].speedLabel_Pos,
                   themes[config.theme].speedLabel_Scale)
    self:drawNumber(self.healthEngine.currentRiseSpeed, themes[config.theme].speed_Pos, themes[config.theme].speed_Scale)
  end
end

-- rating is substituted for challenge mode difficulty here
function SimulatedStack:drawRating()
  if self.player.settings.difficulty then
    self:drawLabel(themes[config.theme].images["IMG_rating_" .. self.which .. "P"], themes[config.theme].ratingLabel_Pos,
                   themes[config.theme].ratingLabel_Scale, true)
    self:drawNumber(self.player.settings.difficulty, themes[config.theme].rating_Pos,
                    themes[config.theme].rating_Scale)
  end
end

function SimulatedStack:drawLevel()
  -- no level
  -- thought about drawing stage number here but it would be
  -- a) redundant with human player win count
  -- b) not offset nicely because level is an image, not a number
end

function SimulatedStack:drawMultibar()
  if self.health then
    self:drawAbsoluteMultibar(0, 0)
  end
end

-- in the long run we should have all quads organized in a Stack.quads table
-- that way deinit could be implemented generically in StackBase
function SimulatedStack:deinit()
  self.healthQuad:release()
  self.stackHeightQuad:release()
  for _, quad in ipairs(self.difficultyQuads) do
    GraphicsUtil:releaseQuad(quad)
  end
end

return SimulatedStack

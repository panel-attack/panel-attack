local logger = require("logger")
local Health = require("Health")
local graphicsUtil = require("graphics_util")
local StackBase = require("StackBase")
local class = require("class")
local consts = require("consts")
require("queue")

-- A simulated stack sends attacks and takes damage from a player, it "loses" if it takes too many attacks.
SimulatedStack =
  class(
  function(self, arguments)
    self.panels_dir = config.panels
    self.max_runs_per_frame = 1
    self.multiBarFrameCount = 240

    self.stackHeightQuad = GraphicsUtil:newRecycledQuad(0, 0, themes[config.theme].images.IMG_multibar_shake_bar:getWidth(), themes[config.theme].images.IMG_multibar_shake_bar:getHeight(), themes[config.theme].images.IMG_multibar_shake_bar:getWidth(), themes[config.theme].images.IMG_multibar_shake_bar:getHeight())
  end,
  StackBase
)

-- adds an attack engine to the simulated opponent
function SimulatedStack:addAttackEngine(attackSettings, shouldPlayAttackSfx)
  self.telegraph = Telegraph(self)

  if shouldPlayAttackSfx then
    self.attackEngine = AttackEngine(attackSettings, self.telegraph, characters[self.character])
  else
    self.attackEngine = AttackEngine(attackSettings, self.telegraph)
  end

  return self.attackEngine
end

function SimulatedStack:addHealth(healthSettings)
  self.healthEngine = Health(
    healthSettings.framesToppedOutToLose,
    healthSettings.lineClearGPM,
    healthSettings.lineHeightToKill,
    healthSettings.riseSpeed
  )
  self.health = healthSettings.framesToppedOutToLose
end

function SimulatedStack:run()
  if not self:game_ended() then
    if self.attackEngine then
      self.attackEngine:run()
    end
    self.clock = self.clock + 1
  end

  if self.do_countdown and self.countdown_timer > 0 then
    self.healthEngine.clock = self.clock
    if self.clock > 8 then
      self.countdown_timer = self.countdown_timer - 1
    end
  else
    if self.healthEngine then
      self.health = self.healthEngine:run()
    end
  end
end

function SimulatedStack:shouldRun(runsSoFar)
  return runsSoFar < self.max_runs_per_frame
end

function SimulatedStack:game_ended()
  if self.game_over then
    return self.game_over
  end

  if self.health <= 0 then
    self:setGameOver()
  end

  return self.game_over
end

function SimulatedStack:setGameOver()
  if not self.game_over then
    self.game_over = true
    self.game_over_clock = self.clock
  end
end

function SimulatedStack:drawDebug()
  if config.debug_mode then
    local drawX = self.frameOriginX + self:stackCanvasWidth() / 2
    local drawY = 10
    local padding = 14

    grectangle_color("fill", (drawX - 5) / GFX_SCALE, (drawY - 5) / GFX_SCALE, 1000 / GFX_SCALE, 100 / GFX_SCALE, 0, 0, 0, 0.5)
    gprintf("Clock " .. self.clock, drawX, drawY)

    drawY = drawY + padding
    gprintf("P" .. self.which .." Ended?: " .. tostring(self:game_ended()), drawX, drawY)
  end
end

function SimulatedStack:render()
  self:setCanvas()
  self:drawCharacter()
  self:renderStackHeight()
  self:drawFrame()
  self:drawWall(0, 12)
  self:drawCanvas()
  self:drawAbsoluteMultibar(0, 0)

  if self.telegraph then
    self.telegraph:render()
  end

  self:drawDebug()
end

function SimulatedStack:renderStackHeight()
  local percentage = self.healthEngine:getTopOutPercentage()
  local xScale = (self:stackCanvasWidth() - 8) / themes[config.theme].images.IMG_multibar_shake_bar:getWidth()
  local yScale = (self.canvas:getHeight() - 4) / themes[config.theme].images.IMG_multibar_shake_bar:getHeight() * percentage

  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.draw(themes[config.theme].images.IMG_multibar_shake_bar, self.stackHeightQuad, 4, self.canvas:getHeight(), 0, xScale, - yScale)
  love.graphics.setColor(1, 1, 1, 1)
end

function SimulatedStack:receiveGarbage(frameToReceive, garbageList)
  if not self:game_ended() then
    if self.healthEngine then
      self.healthEngine:receiveGarbage(frameToReceive, garbageList)
    end
  end
end

function SimulatedStack:saveForRollback()
  local copy = {}

  if self.healthEngine then
    self.healthEngine:saveRollbackCopy()
  end

  if self.telegraph then
    -- this is pretty stupid, telegraph should just save its own rollback on itself
    -- so that when rollback happens we just telegraph:rollbackToFrame
    copy.telegraph = self.telegraph:rollbackCopy()
  end

  self.rollbackCopies[self.clock] = copy
end

function SimulatedStack:rollbackToFrame(frame)
  local copy = self.rollbackCopies[frame]

  if copy then
    if self.telegraph then
      copy.telegraph:rollbackCopy(self.telegraph)
    end
  end

  if self.healthEngine then
    self.healthEngine:rollbackToFrame(frame)
  end
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
    assert(garbageTarget.receiveGarbage ~= nil)
  end
  self.garbageTarget = garbageTarget
  if self.telegraph then
    self.attackEngine:setGarbageTarget(garbageTarget)
    self.telegraph:updatePositionForGarbageTarget(garbageTarget)
  end
end

function SimulatedStack:deinit()
  self.healthQuad:release()
  self.stackHeightQuad:release()
  if self.healthEngine then
    -- need to merge beta to get Health:deinit()
    --self.healthEngine:deinit()
  end
end

return SimulatedStack
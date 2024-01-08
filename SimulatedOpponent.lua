local logger = require("logger")

-- A simulated opponent sends attacks and takes damage from a player, it "loses" if it takes too many attacks.
SimulatedOpponent =
  class(
  function(self, health, character, positionX, positionY, mirror)
    self.health = health
    self.character = character
    self.frameOriginX = positionX / GFX_SCALE
    self.frameOriginY = positionY / GFX_SCALE
    self.mirror_x = mirror
    self.clock = 0
  end
)

function SimulatedOpponent:setAttackEngine(attackEngine) 
  self.attackEngine = attackEngine
end

function SimulatedOpponent:stackCanvasWidth()
  return 288
end

function SimulatedOpponent:run()
  if self.health then
    self.health:run()
  end
  if not self:isDefeated() then
    if self.attackEngine then
      self.attackEngine:run()
    end
    self.clock = self.clock + 1
  end
end

function SimulatedOpponent:isDefeated()
  if not self.health then
    return false
  end
  return self.health:isFullyDepleted()
end

function SimulatedOpponent:drawCharacter()
  local characterObject = characters[self.character]
  characterObject:drawPortrait(2, self.frameOriginX, self.frameOriginY, 0)
end

local healthBarXOffset = -56
function SimulatedOpponent.render(self)

  if self.health then
    self:drawCharacter()
    self.health:render(self.frameOriginX * GFX_SCALE + healthBarXOffset)
  end

  if self.attackEngine then
    self.attackEngine:render()
  end

end

function SimulatedOpponent:receiveGarbage(frameToReceive, garbageList)
  if self.health and self.health:isFullyDepleted() == false then
    self.health:receiveGarbage(frameToReceive, garbageList)
  end
end

function SimulatedOpponent:deinit()
  if self.health then
    self.health:deinit()
  end
end
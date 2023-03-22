local logger = require("logger")

-- A simulated opponent sends attacks and takes damage from a player, it "loses" if it takes too many attacks.
SimulatedOpponent =
  class(
  function(self, health, character, positionX, positionY, mirror)
    self.health = health
    self.character = character
    self.pos_x = positionX / GFX_SCALE
    self.pos_y = positionY / GFX_SCALE
    self.mirror_x = mirror
    self.CLOCK = 0
  end
)

function SimulatedOpponent:setAttackEngine(attackEngine) 
  self.attackEngine = attackEngine
end

function SimulatedOpponent:stackCanvasWidth()
  return 96
end

function SimulatedOpponent:run()
  if self.health then
    self.health:run()
  end
  if not self:isLost() then
    if self.attackEngine then
      self.attackEngine:run()
    end
    self.CLOCK = self.CLOCK + 1
  end
end

function SimulatedOpponent:isLost()
  if not self.health then
    return false
  end
  return self.health:isLost()
end

function SimulatedOpponent:drawCharacter()
  local characterObject = characters[self.character]
  local portraitImageName = characterObject:player2Portrait()
  local portraitImage = characterObject.images[portraitImageName]
  local portrait_w, portrait_h = portraitImage:getDimensions()

  draw(portraitImage, self.pos_x, self.pos_y, 0, 96 / portrait_w, 192 / portrait_h)
end

local healthBarXOffset = -56
function SimulatedOpponent.render(self)

  if self.health then
    self:drawCharacter()
    self.health:render(self.pos_x * GFX_SCALE + healthBarXOffset)
  end

  if self.attackEngine then
    self.attackEngine:render()
  end

end

function SimulatedOpponent:receiveGarbage(frameToReceive, garbageList)
  if self.health and self.health:isLost() == false then
    self.health:receiveGarbage(frameToReceive, garbageList)
  end
end
local logger = require("logger")

SimulatedOpponent =
  class(
  function(self, health, character, attackEngine, positionX, positionY, mirror)
    self.health = health
    self.character = character
    self.attackEngine = attackEngine
    self.pos_x = positionX
    self.pos_y = positionY
    self.mirror_x = mirror
  end
)

function SimulatedOpponent.currentStageForWinCount(winCount) 
  return winCount + 1
end

function SimulatedOpponent:currentStage() 
  return SimulatedOpponent.currentStageForWinCount(GAME.battleRoom.playerWinCounts[P1.player_number])
end

function SimulatedOpponent:run()
  self.health:run()
  if not self:isLost() then
    if self.attackEngine then
      self.attackEngine:run()
    end
  end
end

function SimulatedOpponent:isLost()
  if not self.health then
    return false
  end
  return self.health:isLost()
end

local stageQuads = {}

function SimulatedOpponent.render(self)

  if self.health then
    self.health:render()
  end

  -- todo render character

  -- todo print stage
  draw_number(self:currentStage(), themes[config.theme].images.IMG_timeNumber_atlas, 12, stageQuads, P1.score_x + themes[config.theme].win_Pos[1], P1.score_y + themes[config.theme].win_Pos[2], themes[config.theme].win_Scale, 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale, "center")
end

function SimulatedOpponent:receiveGarbage(frameToReceive, garbageList)
  if self.health and self.health:isLost() == false then
    self.health:receiveGarbage(frameToReceive, garbageList)
  end
end
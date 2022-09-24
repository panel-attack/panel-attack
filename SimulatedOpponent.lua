local logger = require("logger")

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

function SimulatedOpponent.currentStageForWinCount(winCount) 
  return winCount + 1
end

function SimulatedOpponent:currentStage() 
  return SimulatedOpponent.currentStageForWinCount(GAME.battleRoom.playerWinCounts[P1.player_number])
end

function SimulatedOpponent:stackWidth()
  return 96
end

function SimulatedOpponent:run()
  self.health:run()
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

  draw(portraitImage, self.pos_x + 50 / GFX_SCALE, self.pos_y, 0, 96 / portrait_w, 192 / portrait_h)
end

function SimulatedOpponent:drawTimeSplits()
  local totalTime = 0
  local xPosition = 1160
  local yPosition = 120
  local yOffset = 20
  local row = 0
  for _, time in ipairs(GAME.battleRoom.trainingModeSettings.stageTimes) do
    local time_quads = {}
    totalTime = totalTime + time
    draw_time(frames_to_time_string(time, true), time_quads, xPosition, yPosition + yOffset * row, 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale)
    row = row + 1
  end

  if GAME.match.P1:game_ended() == false then
    local time = GAME.match.P1.game_stopwatch
    local time_quads = {}
    totalTime = totalTime + time
    draw_time(frames_to_time_string(time, true), time_quads, xPosition, yPosition + yOffset * row, 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale)
    row = row + 1
  end

  set_color(1,1,0.8,1)
  draw_time(frames_to_time_string(totalTime, true), time_quads, xPosition, yPosition + yOffset * row, 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale)
  set_color(1,1,1,1)
end

local stageQuads = {}

function SimulatedOpponent.render(self)

  self:drawCharacter()

  if self.health then
    self.health:render(self.pos_x * GFX_SCALE)
  end

  if self.attackEngine then
    self.attackEngine:render()
  end

  self:drawTimeSplits()

  -- todo print stage
  draw_number(self:currentStage(), themes[config.theme].images.IMG_timeNumber_atlas, 12, stageQuads, P1.score_x + themes[config.theme].win_Pos[1], P1.score_y + themes[config.theme].win_Pos[2], themes[config.theme].win_Scale, 20 / themes[config.theme].images.timeNumberWidth * themes[config.theme].time_Scale, 26 / themes[config.theme].images.timeNumberHeight * themes[config.theme].time_Scale, "center")
end

function SimulatedOpponent:receiveGarbage(frameToReceive, garbageList)
  if self.health and self.health:isLost() == false then
    self.health:receiveGarbage(frameToReceive, garbageList)
  end
end
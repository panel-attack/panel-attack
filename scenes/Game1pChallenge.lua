local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")
local Signal = require("helpers.signal")

--@module endlessGame
-- Scene for an endless mode instance of the game
local Game1pChallenge = class(
  function (self, sceneParams)
    self.nextScene = "CharacterSelectChallenge"
    self:load(sceneParams)
    Signal.connectSignal(self.match, "onMatchEnded", self, self.onMatchEnded)
    self.stageTimeQuads = {}
    self.totalTimeQuads = {}
    self.stageQuads = {}
    self.stageIndex = GAME.battleRoom.stageIndex
    self.stages = GAME.battleRoom.stages
  end,
  GameBase
)

Game1pChallenge.name = "Game1pChallenge"
sceneManager:addScene(Game1pChallenge)

function Game1pChallenge:onMatchEnded(match)
  Replay.finalizeAndWriteReplay("Challenge Mode", "stage-" .. match.players[1].wins + 1, match.replay)
end

function Game1pChallenge:customDraw()
  self:drawTimeSplits()

  local drawX = canvas_width / 2
  local drawY = 440
  local limit = 400
  gprintf(loc("difficulty"), drawX - limit/2, drawY, limit, "center", nil, nil, 10)
  gprintf(GAME.battleRoom.difficultyName, drawX - limit/2, drawY + 26, limit, "center", nil, nil, 10)

  drawY = 520
  gprintf("Stage", drawX - limit/2, drawY, limit, "center", nil, nil, 10)
  GraphicsUtil.draw_number(self.stageIndex, themes[config.theme].images.IMG_number_atlas_2P, self.stageQuads, drawX, drawY + 26, themes[config.theme].win_Scale, "center")

  drawY = 600
  gprintf("Continues", drawX - limit/2, drawY, limit, "center", nil, nil, 10)
  gprintf(GAME.battleRoom.continues, drawX - limit/2, drawY + 26, limit, "center", nil, nil, 10)
end

function Game1pChallenge:drawTimeSplits()
  local totalTime = 0
  local xPosition = 1180
  local yPosition = 120
  local yOffset = 30
  local row = 0
  local padding = 6
  local width = 180
  local height = yOffset * (#self.stages + 1) + padding * 2

  -- Background
  grectangle_color("fill", (xPosition - width/2) / GFX_SCALE , yPosition / GFX_SCALE, width/GFX_SCALE, height/GFX_SCALE, 0, 0, 0, 0.5)

  yPosition = yPosition + padding

  for i = 1, self.stageIndex do
    if self.stageTimeQuads[i] == nil then
      self.stageTimeQuads[i] = {}
    end
    local time = self.stages[i].expendedTime
    local currentStageTime = time
    local isCurrentStage = i == self.stageIndex
    if isCurrentStage and self.match.P1:game_ended() == false then
      currentStageTime = currentStageTime + self.match.P1.game_stopwatch
    end
    totalTime = totalTime + currentStageTime

    if isCurrentStage then
      set_color(0.8,0.8,1,1)
    end
    GraphicsUtil.draw_time(frames_to_time_string(currentStageTime, true), self.stageTimeQuads[i], xPosition, yPosition + yOffset * row, themes[config.theme].time_Scale)
    if isCurrentStage then
      set_color(1,1,1,1)
    end

    row = row + 1
  end

  set_color(1,1,0.8,1)
  GraphicsUtil.draw_time(frames_to_time_string(totalTime, true), self.totalTimeQuads, xPosition, yPosition + yOffset * row, themes[config.theme].time_Scale)
  set_color(1,1,1,1)
end

return Game1pChallenge
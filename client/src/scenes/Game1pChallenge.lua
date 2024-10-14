local GameBase = require("client.src.scenes.GameBase")
local Replay = require("common.engine.Replay")
local class = require("common.lib.class")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- @module endlessGame
-- Scene for an endless mode instance of the game
local Game1pChallenge = class(function(self, sceneParams)
  self.nextScene = "CharacterSelectChallenge"
  self:load(sceneParams)
  self.match:connectSignal("matchEnded", self, self.onMatchEnded)
  self.stageTimeQuads = {}
  self.totalTimeQuads = {}
  self.stageIndex = GAME.battleRoom.stageIndex
  self.stages = GAME.battleRoom.stages
end, GameBase)

Game1pChallenge.name = "Game1pChallenge"

function Game1pChallenge:onMatchEnded(match)
  local extraFilename = "diff-" .. GAME.battleRoom.difficulty .. "-stage-" .. GAME.battleRoom.stageIndex
  if match.replay.winnerIndex then
    extraFilename = extraFilename .. "-P" .. match.replay.winnerIndex .. "wins"
  else
    extraFilename = extraFilename .. "-draw"
  end
  Replay.finalizeAndWriteReplay("Challenge Mode", extraFilename, match.replay)
end

function Game1pChallenge:draw()
  if self.backgroundImage then
    self.backgroundImage:draw()
  end
  self.match:render()
  self:drawHUD()
end

function Game1pChallenge:drawHUD()
  if GAME.battleRoom then
    local drawX = consts.CANVAS_WIDTH / 2
    local drawY = 110
    local width = 200
    local height = consts.CANVAS_HEIGHT - drawY

    -- Background
    GraphicsUtil.drawRectangle("fill", drawX - width / 2, drawY, width, height, 0, 0, 0, 0.5)

    drawY = 140
    self:drawDifficultyName(drawX, drawY)

    drawY = 220
    self:drawStageInfo(drawX, drawY)

    drawY = 280
    self:drawContinueInfo(drawX, drawY)

    drawY = 320
    self:drawTimeSplits(drawX, drawY)

    if not self.match.isPaused then
      for i, stack in ipairs(self.match.stacks) do
        if stack.player and stack.player.human then
          if config.show_ingame_infos then
            stack:drawMultibar()
            stack:drawAnalyticData()
          end
        else
          stack:drawMultibar()
        end
      end
    end
  end
end

function Game1pChallenge:drawDifficultyName(drawX, drawY)
  local limit = 400
  GraphicsUtil.printf(loc("difficulty"), drawX - limit / 2, drawY, limit, "center", nil, nil, 10)
  GraphicsUtil.printf(GAME.battleRoom.difficultyName, drawX - limit / 2, drawY + 26, limit, "center", nil, nil, 10)
end

function Game1pChallenge:drawStageInfo(drawX, drawY)
  local limit = 400
  GraphicsUtil.printf("Stage", drawX - limit / 2, drawY, limit, "center", nil, nil, 10)
  GraphicsUtil.drawPixelFont(self.stageIndex, themes[config.theme].fontMaps.numbers[2], drawX, drawY + 26,
                           themes[config.theme].win_Scale, themes[config.theme].win_Scale, "center", 0)
end

function Game1pChallenge:drawContinueInfo(drawX, drawY)
  local limit = 400
  GraphicsUtil.printf("Continues", drawX - limit / 2, drawY, limit, "center", nil, nil, 4)
  GraphicsUtil.printf(GAME.battleRoom.continues, drawX - limit / 2, drawY + 20, limit, "center", nil, nil, 4)
end

function Game1pChallenge:drawTimeSplits(xPosition, yPosition)
  local totalTime = 0

  local yOffset = 30
  local row = 0
  local padding = 6

  yPosition = yPosition + padding

  for i = 1, self.stageIndex do
    if self.stageTimeQuads[i] == nil then
      self.stageTimeQuads[i] = {}
    end
    local time = self.stages[i].expendedTime
    local currentStageTime = time
    local isCurrentStage = i == self.stageIndex
    if isCurrentStage and not self.match.ended then
      currentStageTime = currentStageTime + (self.match.stacks[1].game_stopwatch or 0)
    end
    totalTime = totalTime + currentStageTime

    if isCurrentStage then
      GraphicsUtil.setColor(0.8, 0.8, 1, 1)
    end
    GraphicsUtil.draw_time(frames_to_time_string(currentStageTime, true), xPosition, yPosition + yOffset * row,
                           themes[config.theme].time_Scale)
    if isCurrentStage then
      GraphicsUtil.setColor(1, 1, 1, 1)
    end

    row = row + 1
  end

  GraphicsUtil.setColor(1, 1, 0.8, 1)
  GraphicsUtil.draw_time(frames_to_time_string(totalTime, true), xPosition, yPosition + yOffset * row,
                         themes[config.theme].time_Scale)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

return Game1pChallenge

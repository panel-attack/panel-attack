local logger = require("logger")
require("ChallengeStage")

-- Challenge Mode is a particular play through of the challenge mode in the game, it contains all the settings for the mode.
ChallengeMode =
  class(
  function(self)
    self.currentStageIndex = 0
    self.nextStageIndex = 1
    self.stages = {}
    local lineHeightToKill = 6
    for i = 1, 10, 1 do
      self.stages[#self.stages+1] = ChallengeStage(i, 1, 4 * (1 + .1 * i), lineHeightToKill, 2)
    end
    self.stageTimeQuads = {}
    self.totalTimeQuads = {}
  end
)

function ChallengeMode:beginStage()
  self.currentStageIndex = self.nextStageIndex
end

function ChallengeMode:recordStageResult(gameResult, gameLength)
  local lastStageIndex = self.currentStageIndex

  if gameResult > 0 then
    self.nextStageIndex = self.currentStageIndex + 1
  end

  local challengeStage = self.stages[lastStageIndex]
  challengeStage.expendedTime = gameLength + challengeStage.expendedTime
end

local stageQuads = {}

function ChallengeMode.render(self)
  self:drawTimeSplits()

  local stageX = 614
  local stageY = 440
  local limit = 400
  gprintf("Stage", stageX - limit/2, stageY, limit, "center", nil, nil, 10)
  GraphicsUtil.draw_number(self.currentStageIndex, themes[config.theme].images.IMG_number_atlas_2P, stageQuads, stageX, stageY + 26, themes[config.theme].win_Scale, "center")
end


function ChallengeMode:drawTimeSplits()
  local totalTime = 0
  local xPosition = 1160
  local yPosition = 120
  local yOffset = 30
  local row = 0
  for i = 1, self.currentStageIndex do
    if self.stageTimeQuads[i] == nil then
      self.stageTimeQuads[i] = {}
    end
    local time = self.stages[i].expendedTime
    local currentStageTime = time
    local isCurrentStage = i == self.currentStageIndex
    if isCurrentStage and GAME.match.P1:game_ended() == false then
      currentStageTime = currentStageTime + GAME.match.P1.game_stopwatch
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

function ChallengeMode:characterForStageNumber(stageNumber, playerCharacter)
  -- Get all other characters than the player character
  local otherCharacters = {}
  for _, currentCharacter in ipairs(characters_ids_for_current_theme) do
    if currentCharacter ~= playerCharacter and characters[currentCharacter]:is_bundle() == false then
      otherCharacters[#otherCharacters+1] = currentCharacter
    end
  end

  -- If we couldn't find any characters, try sub characters as a last resort
  if #otherCharacters == 0 then
    for _, currentCharacter in ipairs(characters_ids_for_current_theme) do
      if characters[currentCharacter]:is_bundle() == true then
        currentCharacter = characters[currentCharacter].sub_characters[1]
      end
      if currentCharacter ~= playerCharacter then
        otherCharacters[#otherCharacters+1] = currentCharacter
      end 
    end
  end

  local character = otherCharacters[((stageNumber - 1) % #otherCharacters) + 1]
  return character
end
  
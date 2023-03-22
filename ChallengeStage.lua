local logger = require("logger")
require("Health")

-- Challenge Stage is a particular stage in challenge mode.
ChallengeStage =
  class(
  function(self, stageNumber, secondsToppedOutToLose, lineClearGPM, lineHeightToKill, riseDifficulty, attackSettings)
    self.stageNumber = stageNumber
    self.secondsToppedOutToLose = secondsToppedOutToLose
    self.lineClearGPM = lineClearGPM
    self.lineHeightToKill = lineHeightToKill
    self.riseDifficulty = riseDifficulty
    self.expendedTime = 0
    self.attackSettings = attackSettings
  end
)


function ChallengeStage:createHealth()
  return Health(self.secondsToppedOutToLose, self.lineClearGPM, self.lineHeightToKill, self.riseDifficulty)
end

function ChallengeStage:createAttackEngine(opponent, character)
  local attackEngine = AttackEngine.createEngineForTrainingModeSettings(self.attackSettings, opponent, character)
  return attackEngine
end

function ChallengeStage:characterForStageNumber(playerCharacter)
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

  local character = otherCharacters[((self.stageNumber - 1) % #otherCharacters) + 1]
  return character
end
  
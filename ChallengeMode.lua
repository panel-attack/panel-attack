local logger = require("logger")

-- Challenge Mode is a particular play through of the challenge mode in the game, it cantains all the settings for the mode.
ChallengeMode =
  class(
  function(self, mode, battleRoom)
    self.P1 = nil
  end
)


function ChallengeMode.render(self)
  
end


function ChallengeMode.characterForStageNumber(stageNumber)
    local character = characters_ids_for_current_theme[((stageNumber - 1) % #characters_ids_for_current_theme) + 1]
    if characters[character]:is_bundle() then -- may have picked a bundle
      character = characters[character].sub_characters[1]
    end
    return character
  end
  
  function select_screen.characterForStage(stageNumber, playerCharacter)
    local character = select_screen.characterForStageNumber(stageNumber)
    if character.id == playerCharacter.id then
      local character = select_screen.characterForStageNumber(stageNumber+1)
      
    end
  
    
  
    return character
  end

  
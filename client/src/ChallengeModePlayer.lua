local MatchParticipant = require("MatchParticipant")
local class = require("class")
local SimulatedStack = require("SimulatedStack")
local CharacterLoader = require("mods.CharacterLoader")

local ChallengeModePlayer = class(function(self, playerNumber)
  self.name = "Challenger"
  self.playerNumber = playerNumber
  self.isLocal = true
  self.settings.attackEngineSettings = nil
  self.settings.healthSettings = nil
  self.settings.wantsReady = true
  self.usedCharacterIds = {}
  self.human = false
end,
MatchParticipant)

local function characterForStageNumber(stageNumber)
  -- Get all other characters than the player character
  local otherCharacters = {}
  for _, currentCharacter in ipairs(characters_ids_for_current_theme) do
    if currentCharacter ~= config.character and characters[currentCharacter]:is_bundle() == false then
      otherCharacters[#otherCharacters+1] = currentCharacter
    end
  end

  -- If we couldn't find any characters, try sub characters as a last resort
  if #otherCharacters == 0 then
    for _, currentCharacter in ipairs(characters_ids_for_current_theme) do
      if characters[currentCharacter]:is_bundle() == true then
        currentCharacter = characters[currentCharacter].sub_characters[1]
      end
      if currentCharacter ~= config.character then
        otherCharacters[#otherCharacters+1] = currentCharacter
      end 
    end
  end

  local character = otherCharacters[((stageNumber - 1) % #otherCharacters) + 1]
  return character
end

function ChallengeModePlayer:createStackFromSettings(match, which)
  assert(self.settings.healthSettings and self.settings.attackEngineSettings)
  local simulatedStack = SimulatedStack({which = which, character = self.settings.characterId, is_local = true})
  simulatedStack:addAttackEngine(self.settings.attackEngineSettings, true)
  simulatedStack:addHealth(self.settings.healthSettings)
  self.stack = simulatedStack
  simulatedStack.player = self

  return simulatedStack
end

function ChallengeModePlayer:setCharacterForStage(stageNumber)
  self:setCharacter(characterForStageNumber(stageNumber))
end

-- challenge mode players are always ready
function ChallengeModePlayer:setWantsReady(wantsReady)
  self.settings.wantsReady = true
  self:wantsReadyChanged(true)
end

function ChallengeModePlayer.createFromReplayPlayer(replayPlayer, playerNumber)
  local player = ChallengeModePlayer(playerNumber)
  player.settings.attackEngineSettings = replayPlayer.settings.attackEngineSettings
  player.settings.healthSettings = replayPlayer.settings.healthSettings
  player.settings.characterId = CharacterLoader.fullyResolveCharacterSelection(replayPlayer.settings.characterId)
  player.settings.difficulty = replayPlayer.settings.difficulty
  player.isLocal = false
  return player
end

function ChallengeModePlayer:getInfo()
  local info = {}
  info.characterId = self.settings.characterId
  info.selectedCharacterId = self.settings.selectedCharacterId
  info.stageId = self.settings.stageId
  info.selectedStageId = self.settings.selectedStageId
  info.panelId = self.settings.panelId
  info.wantsReady = self.settings.wantsReady
  info.playerNumber = self.playerNumber
  info.isLocal = self.isLocal
  info.human = self.human
  info.wins = self.wins
  info.modifiedWins = self.modifiedWins

  return info
end

return ChallengeModePlayer
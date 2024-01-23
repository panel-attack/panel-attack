local class = require("class")
local util = require("util")
local consts = require("consts")
local Signal = require("helpers.signal")
local logger = require("logger")

-- a match participant represents the minimum spec for a what constitutes a "player" in a battleRoom / match
local MatchParticipant = class(function(self)
  self.name = "participant"
  self.wins = 0
  self.modifiedWins = 0
  self.winrate = 0
  self.expectedWinrate = 0
  self.settings = {
    characterId = consts.RANDOM_CHARACTER_SPECIAL_VALUE,
    stageId = consts.RANDOM_STAGE_SPECIAL_VALUE,
    wantsReady = false
  }
  self.human = false

  Signal.addSignal(self, "winsChanged")
  Signal.addSignal(self, "winrateChanged")
  Signal.addSignal(self, "expectedWinrateChanged")
  Signal.addSignal(self, "panelIdChanged")
  Signal.addSignal(self, "stageIdChanged")
  Signal.addSignal(self, "selectedStageIdChanged")
  Signal.addSignal(self, "characterIdChanged")
  Signal.addSignal(self, "selectedCharacterIdChanged")
  Signal.addSignal(self, "wantsReadyChanged")
end)

-- returns the count of wins modified by the `modifiedWins` property
function MatchParticipant:getWinCountForDisplay()
  return self.wins + self.modifiedWins
end

function MatchParticipant:setWinCount(count)
  self.wins = count
  self.winsChanged(self:getWinCountForDisplay())
end

function MatchParticipant:incrementWinCount()
  self.wins = self.wins + 1
  self.winsChanged(self:getWinCountForDisplay())
end

function MatchParticipant:setWinrate(winrate)
  self.winrate = winrate
  self.winrateChanged(winrate)
end

function MatchParticipant:setExpectedWinrate(expectedWinrate)
  self.expectedWinrate = expectedWinrate
  self.expectedWinrateChanged(expectedWinrate)
end

-- returns a table with some key properties on functions to be run as part of a match
function MatchParticipant:createStackFromSettings(match, which)
  error("MatchParticipant needs to implement function createStackFromSettings")
end

function MatchParticipant:setStage(stageId)
  if stageId ~= self.settings.selectedStageId then
    self.settings.selectedStageId = StageLoader.resolveStageSelection(stageId)
    self.selectedStageIdChanged(self.settings.selectedStageId)
  end
  -- even if it's the same stage as before, refresh the pick, cause it could be bundle or random
  self:refreshStage()
end

function MatchParticipant:refreshStage()
  local currentId = self.settings.stageId
  self.settings.stageId = StageLoader.resolveBundle(self.settings.selectedStageId)
  if currentId ~= self.settings.stageId then
    self.stageIdChanged(self.settings.stageId)
    CharacterLoader.load(self.settings.stageId)
  end
end

function MatchParticipant:setCharacter(characterId)
  if characterId ~= self.settings.selectedCharacterId then
    self.settings.selectedCharacterId = CharacterLoader.resolveCharacterSelection(characterId)
    self.selectedCharacterIdChanged(self.settings.selectedCharacterId)
  end
  -- even if it's the same character as before, refresh the pick, cause it could be bundle or random
  self:refreshCharacter()
end

function MatchParticipant:refreshCharacter()
  local currentId = self.settings.characterId
  self.settings.characterId = CharacterLoader.resolveBundle(self.settings.selectedCharacterId)
  if currentId ~= self.settings.characterId then
    self.characterIdChanged(self.settings.characterId)
    CharacterLoader.load(self.settings.characterId)
  end
end

function MatchParticipant:setWantsReady(wantsReady)
  if wantsReady ~= self.settings.wantsReady then
    self.settings.wantsReady = wantsReady
    self:wantsReadyChanged(wantsReady)
  end
end

-- a callback that runs whenever a match ended
function MatchParticipant:onMatchEnded()
   -- to prevent the game from instantly restarting, unready all players
   if self.human then
    self:setWantsReady(false)
   end
   if self.isLocal then
     -- if they're local, refresh the character in case they use a bundle / random
     self:refreshCharacter()
     self:refreshStage()
   end
end

return MatchParticipant
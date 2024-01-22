local class = require("class")
local util = require("util")
local consts = require("consts")

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
  self.subscriptionList = util.getWeaklyKeyedTable()
  self.human = false
end)

-- returns the count of wins modified by the `modifiedWins` property
function MatchParticipant:getWinCountForDisplay()
  return self.wins + self.modifiedWins
end

function MatchParticipant:setWinCount(count)
  self.wins = count
end

function MatchParticipant:incrementWinCount()
  self.wins = self.wins + 1
end

-- returns a table with some key properties on functions to be run as part of a match
function MatchParticipant:createStackFromSettings(match, which)
  error("MatchParticipant needs to implement function createStackFromSettings")
end

-- Other elements (ui, network) can subscribe to properties in MatchParticipant.settings by passing a callback
function MatchParticipant:subscribe(subscriber, property, callback)
  if self.settings[property] ~= nil then
    if not self.subscriptionList[property] then
      self.subscriptionList[property] = {}
    end
    self.subscriptionList[property][subscriber] = callback
    return true
  end

  return false
end

function MatchParticipant:unsubscribe(subscriber, property)
  if property then
    self.subscriptionList[property][subscriber] = nil
  else
    -- if no property is given, unsubscribe everything for that subscriber
    for property, _ in pairs(self.subscriptionList) do
      self.subscriptionList[property][subscriber] = nil
    end
  end
end

-- clears all subscriptions 
function MatchParticipant:clearSubscriptions()
  self.subscriptionList = util.getWeaklyKeyedTable()
end

-- the callback is executed with the new property value as the argument whenever a property is modified via its setter
function MatchParticipant:onPropertyChanged(property)
  if self.subscriptionList[property] then
    for subscriber, callback in pairs(self.subscriptionList[property]) do
      callback(subscriber, self.settings[property])
    end
  end
end

function MatchParticipant:setStage(stageId)
  if stageId ~= self.settings.selectedStageId then
    self.settings.selectedStageId = StageLoader.resolveStageSelection(stageId)
    self:onPropertyChanged("selectedStageId")
  end
  -- even if it's the same stage as before, refresh the pick, cause it could be bundle or random
  self:refreshStage()
end

function MatchParticipant:refreshStage()
  local currentId = self.settings.stageId
  self.settings.stageId = StageLoader.resolveBundle(self.settings.selectedStageId)
  if currentId ~= self.settings.stageId then
    self:onPropertyChanged("stageId")
    CharacterLoader.load(self.settings.stageId)
  end
end

function MatchParticipant:setCharacter(characterId)
  if characterId ~= self.settings.selectedCharacterId then
    self.settings.selectedCharacterId = CharacterLoader.resolveCharacterSelection(characterId)
    self:onPropertyChanged("selectedCharacterId")
  end
  -- even if it's the same character as before, refresh the pick, cause it could be bundle or random
  self:refreshCharacter()
end

function MatchParticipant:refreshCharacter()
  local currentId = self.settings.characterId
  self.settings.characterId = CharacterLoader.resolveBundle(self.settings.selectedCharacterId)
  if currentId ~= self.settings.characterId then
    self:onPropertyChanged("characterId")
    CharacterLoader.load(self.settings.characterId)
  end
end

function MatchParticipant:setWantsReady(wantsReady)
  if wantsReady ~= self.settings.wantsReady then
    self.settings.wantsReady = wantsReady
    self:onPropertyChanged("wantsReady")
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
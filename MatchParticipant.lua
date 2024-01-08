local class = require("class")
local util = require("util")
local consts = require("consts")

-- a match participant represents the minimum spec for a what constitutes a "player" in a battleRoom / match
local MatchParticipant = class(function(self)
  self.name = "participant"
  self.wins = 0
  self.modifiedWins = 0
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
  if stageId ~= self.settings.stageId then
    stageId = StageLoader.resolveStageSelection(stageId)
    self.settings.stageId = stageId
    StageLoader.load(stageId)

    self:onPropertyChanged("stageId")
  end
end

function MatchParticipant:setCharacter(characterId)
  if characterId ~= self.settings.characterId then
    characterId = CharacterLoader.resolveCharacterSelection(characterId)
    self.settings.characterId = characterId
    CharacterLoader.load(characterId)

    self:onPropertyChanged("characterId")
  end
end

function MatchParticipant:setWantsReady(wantsReady)
  if wantsReady ~= self.settings.wantsReady then
    self.settings.wantsReady = wantsReady
    self:onPropertyChanged("wantsReady")
  end
end

return MatchParticipant
local class = require("class")
local consts = require("consts")
local Signal = require("helpers.signal")
local logger = require("logger")
local CharacterLoader = require("mods.CharacterLoader")
local StageLoader = require("mods.StageLoader")
local ModController = require("mods.ModController")

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
    panelId = config.panels,
    wantsReady = false,
  }
  self.hasLoaded = false
  self.ready = false
  self.human = false

  Signal.turnIntoEmitter(self)
  self:createSignal("winsChanged")
  self:createSignal("winrateChanged")
  self:createSignal("expectedWinrateChanged")
  self:createSignal("panelIdChanged")
  self:createSignal("stageIdChanged")
  self:createSignal("selectedStageIdChanged")
  self:createSignal("characterIdChanged")
  self:createSignal("selectedCharacterIdChanged")
  self:createSignal("wantsReadyChanged")
  self:createSignal("readyChanged")
  self:createSignal("hasLoadedChanged")
end)

-- returns the count of wins modified by the `modifiedWins` property
function MatchParticipant:getWinCountForDisplay()
  return self.wins + self.modifiedWins
end

function MatchParticipant:setWinCount(count)
  self.wins = count
  self:emitSignal("winsChanged", self:getWinCountForDisplay())
end

function MatchParticipant:incrementWinCount()
  self:setWinCount(self.wins + 1)
end

function MatchParticipant:setWinrate(winrate)
  self.winrate = winrate
  self:emitSignal("winrateChanged", winrate)
end

function MatchParticipant:setExpectedWinrate(expectedWinrate)
  self.expectedWinrate = expectedWinrate
  self:emitSignal("expectedWinrateChanged", expectedWinrate)
end

-- returns a table with some key properties on functions to be run as part of a match
function MatchParticipant:createStackFromSettings(match, which)
  error("MatchParticipant needs to implement function createStackFromSettings")
end

function MatchParticipant:setStage(stageId)
  if stageId ~= self.settings.selectedStageId then
    self.settings.selectedStageId = StageLoader.resolveStageSelection(stageId)
    self:emitSignal("selectedStageIdChanged", self.settings.selectedStageId)
  end
  -- even if it's the same stage as before, refresh the pick, cause it could be bundle or random
  self:refreshStage()
end

function MatchParticipant:refreshStage()
  local currentId = self.settings.stageId
  self.settings.stageId = StageLoader.resolveBundle(self.settings.selectedStageId)
  if currentId ~= self.settings.stageId then
    self:emitSignal("stageIdChanged", self.settings.stageId)
    if not stages[self.settings.stageId].fully_loaded then
      logger.debug("Loading stage " .. self.settings.stageId .. " as part of stageRefresh")
      if self.isLocal then
        ModController:loadModFor(stages[self.settings.stageId], self)
        self:setLoaded(false)
      else
        ModController:loadModFor(stages[self.settings.stageId], self)
      end
    end
  end
end

function MatchParticipant:setCharacter(characterId)
  if characterId ~= self.settings.selectedCharacterId then
    self.settings.selectedCharacterId = CharacterLoader.resolveCharacterSelection(characterId)
    self:emitSignal("selectedCharacterIdChanged", self.settings.selectedCharacterId)
  end
  -- even if it's the same character as before, refresh the pick, cause it could be bundle or random
  self:refreshCharacter()
end

function MatchParticipant:refreshCharacter()
  local currentId = self.settings.characterId
  self.settings.characterId = CharacterLoader.resolveBundle(self.settings.selectedCharacterId)
  if currentId ~= self.settings.characterId then
    self:emitSignal("characterIdChanged", self.settings.characterId)
    if not characters[self.settings.characterId].fully_loaded then
      logger.debug("Loading character " .. self.settings.characterId .. " as part of stageRefresh")
      if self.isLocal then
        self:setLoaded(false)
        ModController:loadModFor(characters[self.settings.characterId], self)
      else
        ModController:loadModFor(characters[self.settings.characterId], self)
      end
    end
  end
end

function MatchParticipant:setWantsReady(wantsReady)
  if wantsReady ~= self.settings.wantsReady then
    self.settings.wantsReady = wantsReady
    self:emitSignal("wantsReadyChanged", wantsReady)
  end
end

function MatchParticipant:setReady(ready)
  if ready ~= self.ready then
    self.ready = ready
    self:emitSignal("readyChanged", ready)
  end
end

function MatchParticipant:setLoaded(hasLoaded)
  if hasLoaded ~= self.hasLoaded then
    self.hasLoaded = hasLoaded
    self:emitSignal("hasLoadedChanged", hasLoaded)
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
local class = require("class")
local GameModes = require("GameModes")

-- A player is mostly a data representation of a Panel Attack player
-- It holds data pertaining to their online status (like name, public id)
-- It holds data pertaining to their client status (like character, stage, panels, level etc)
-- Player implements a lot of setters that feed into an observer-like pattern, notifying possible subscribers about property changes
-- Due to this, unless for a good reason, all properties on Player should be set using the setters
local Player = class(function(self, name, publicId, isLocal)
  self.name = name
  self.wins = 0
  self.modifiedWins = 0
  self.settings = {}
  self.publicId = publicId
  self.trainingModeSettings = nil
  self.rating = nil
  self.stack = nil
  self.playerNumber = nil
  self.isLocal = isLocal or false
  self.inputConfiguration = nil
  self.subscriptionList = {}
end)

-- returns the count of wins modified by the `modifiedWins` property
function Player:getWinCount()
  return self.wins + self.modifiedWins
end

function Player:setWinCount(count)
  self.wins = count
end

function Player:incrementWinCount()
  self.wins = self.wins + 1
end

-- creates a stack for the given match according to the player's settings and returns it
-- the stack is also saved as a reference on player
function Player:createStackFromSettings(match)
  local args = {}
  args.which = self.playerNumber
  args.player_number = self.playerNumber
  args.match = match
  args.is_local = self.isLocal
  args.panels_dir = self.settings.panelId
  args.character = self.settings.characterId
  if self.settings.style == GameModes.Styles.MODERN then
    args.level = self.settings.level
    if match.battleRoom.mode.stackInteraction == GameModes.StackInteraction.NONE then
      args.allowAdjacentColors = true
    else
      args.allowAdjacentColors = args.level < 8
    end
  else
    args.difficulty = self.settings.difficulty
    args.speed = self.settings.speed
    args.allowAdjacentColors = true
  end
  if match.isFromReplay and self.settings.allowAdjacentColors ~= nil then
    args.allowAdjacentColors = self.settings.allowAdjacentColors
  end
  args.inputMethod = self.settings.inputMethod

  self.stack = Stack(args)

  return self.stack
end

function Player:getRatingDiff()
  return self.rating.new - self.rating.old
end

-- Other elements (ui, network) can subscribe to properties in Player.settings by passing a callback
function Player:subscribe(property, callback)
  if self.settings[property] then
    if not self.subscriptionList[property] then
      self.subscriptionList[property] = {}
    end
    self.subscriptionList[property][#self.subscriptionList[property] + 1] = callback
    return true
  end

  return false
end

-- the callback is executed with the new property value as the argument whenever a property is modified via its setter
function Player:onPropertyChanged(property)
  if self.subscriptionList[property] then
    for i = 1, #self.subscriptionList[property] do
      self.subscriptionList[property][i](self.settings[property])
    end
  end
end

function Player:setStage(stageId)
  if stageId ~= self.settings.stageId then
    stageId = StageLoader.resolveStageSelection(stageId)
    self.settings.stageId = stageId
    StageLoader.load(stageId)

    self:onPropertyChanged("stageId")
  end
end

function Player:setCharacter(characterId)
  if characterId ~= self.settings.characterId then
    characterId = CharacterLoader.resolveCharacterSelection(characterId)
    self.settings.characterId = characterId
    CharacterLoader.load(characterId)

    self:onPropertyChanged("characterId")
  end
end

function Player:setPanels(panelId)
  if panelId ~= self.settings.panelId then
    if panels[panelId] then
      self.settings.panelId = panelId
    else
      -- default back to config panels always
      self.settings.panelId = config.panels
    end
    -- panels are always loaded so no loading is necessary

    self:onPropertyChanged("panelId")
  end
end

function Player:setWantsRanked(wantsRanked)
  if wantsRanked ~= self.settings.wantsRanked then
    self.settings.wantsRanked = wantsRanked
    self:onPropertyChanged("wantsRanked")
  end
end

function Player:setWantsReady(wantsReady)
  if wantsReady ~= self.settings.wantsReady then
    self.settings.wantsReady = wantsReady
    self:onPropertyChanged("wantsReady")
  end
end

function Player:setLoaded(hasLoaded)
  -- loaded is only set for non-local players to determine if they are ready for the match
  -- the battleRoom is in charge of checking whether all assets have been loaded locally
  if not self.isLocal then
    if hasLoaded ~= self.settings.hasLoaded then
      self.settings.hasLoaded = hasLoaded
      self:onPropertyChanged("hasLoaded")
    end
  end
end

function Player:setDifficulty(difficulty)
  if difficulty ~= self.settings.difficulty then
    self.settings.difficulty = difficulty
    self:onPropertyChanged("difficulty")
  end
end

function Player:setSpeed(speed)
  if speed ~= self.settings.speed then
    self.settings.speed = speed
    self:onPropertyChanged("speed")
  end
end

function Player:setLevel(level)
  if level ~= self.settings.level then
    self.settings.level = level
    self:onPropertyChanged("level")
  end
end

function Player:setInputMethod(inputMethod)
  if inputMethod ~= self.settings.inputMethod then
    self.settings.inputMethod = inputMethod
    self:onPropertyChanged("inputMethod")
  end
end

-- sets the style of "level" presets the player selects from
-- 1 = classic
-- 2 = modern
function Player:setStyle(style)
  if style ~= self.settings.style then
    self.settings.style = style
    self:onPropertyChanged("style")
  end
end

function Player:setPuzzleSet(puzzleSet)
  if puzzleSet ~= self.settings.puzzleSet then
    self.settings.puzzleSet = puzzleSet
    self:onPropertyChanged("puzzleSet")
  end
end

function Player.getLocalPlayer()
  local player = Player(config.name)

  player:setDifficulty(config.endless_difficulty)
  player:setSpeed(config.endless_speed)
  player:setLevel(config.level)
  player:setCharacter(config.character)
  player:setStage(config.stage)
  player:setPanels(config.panels)
  player:setWantsRanked(config.ranked)
  player:setInputMethod(config.inputMethod)
  if config.endless_level then
    player:setStyle(GameModes.Styles.MODERN)
  else
    player:setStyle(GameModes.Styles.CLASSIC)
  end

  player.isLocal = true

  return player
end

return Player
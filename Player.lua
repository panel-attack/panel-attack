local class = require("class")
local GameModes = require("GameModes")
local LevelPresets = require("LevelPresets")
local input = require("inputManager")
local util = require("util")
local MatchParticipant = require("MatchParticipant")
local consts = require("consts")
local Signal = require("helpers.signal")

-- A player is mostly a data representation of a Panel Attack player
-- It holds data pertaining to their online status (like name, public id)
-- It holds data pertaining to their client status (like character, stage, panels, level etc)
-- Player implements a lot of setters that emit signals on changes, allowing other components to be notified about the changes by connecting a function to it
-- Due to this, unless for a good reason, all properties on Player should be set using the setters
local Player = class(function(self, name, publicId, isLocal)
  self.name = name
  self.settings = {
    -- these need to all be initialized so subscription works
    -- the gist is that all settings inside here are modifiable clientside for local players as part of match setup
    -- while everything outside settings is static or dictated server side
    level = 1,
    difficulty = 1,
    speed = 1,
    levelData = LevelPresets.getModern(1),
    style = GameModes.Styles.MODERN,
    characterId = "",
    stageId = "",
    panelId = "",
    wantsReady = false,
    wantsRanked = true,
    inputMethod = "controller",
    attackEngineSettings = nil,
    puzzleSet = nil,
  }
  -- planned for the future, players don't have public ids yet
  self.publicId = publicId or -1
  self.rating = nil
  self.ratingHistory = {}
  self.stack = nil
  self.playerNumber = nil
  self.isLocal = isLocal or false
  -- a player has only one configuration at a time
  -- this is either everything or a single input configuration
  self.inputConfiguration = input
  self.human = true

  -- the player emits signals when its properties change that other components may be interested in
  -- they can register a callback with each signal via Signal.connectSignal
  -- there are a few more signals in MatchParticipant
  Signal.addSignal(self, "styleChanged")
  Signal.addSignal(self, "levelChanged")
  Signal.addSignal(self, "difficultyChanged")
  Signal.addSignal(self, "startingSpeedChanged")
  Signal.addSignal(self, "colorCountChanged")
  Signal.addSignal(self, "levelDataChanged")
  Signal.addSignal(self, "inputMethodChanged")
  Signal.addSignal(self, "attackEngineSettingsChanged")
  Signal.addSignal(self, "puzzleSetChanged")
  Signal.addSignal(self, "ratingChanged")
  Signal.addSignal(self, "wantsRankedChanged")
  Signal.addSignal(self, "hasLoadedChanged")

end,
MatchParticipant)

-- creates a stack for the given match according to the player's settings and returns it
-- the stack is also saved as a reference on player
function Player:createStackFromSettings(match, which)
  local args = {}
  args.which = which
  args.player_number = self.playerNumber
  args.match = match
  args.is_local = self.isLocal
  args.panels_dir = self.settings.panelId
  args.character = self.settings.characterId
  if self.settings.style == GameModes.Styles.MODERN then
    args.level = self.settings.level
    if match.stackInteraction == GameModes.StackInteractions.NONE then
      args.allowAdjacentColors = true
    else
      args.allowAdjacentColors = args.level < 8
    end
  else
    args.difficulty = self.settings.difficulty
    args.allowAdjacentColors = true
  end

  args.levelData = self.settings.levelData

  if match.isFromReplay and self.settings.allowAdjacentColors ~= nil then
    args.allowAdjacentColors = self.settings.allowAdjacentColors
  end
  args.inputMethod = self.settings.inputMethod

  self.stack = Stack(args)
  -- so the stack can draw player information
  self.stack.player = self

  return self.stack
end

function Player:getRatingDiff()
  return self.rating.new - self.rating.old
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

    self.panelIdChanged(self.settings.panelId)
  end
end

function Player:setWantsRanked(wantsRanked)
  if wantsRanked ~= self.settings.wantsRanked then
    self.settings.wantsRanked = wantsRanked
    self.wantsRankedChanged(wantsRanked)
  end
end

function Player:setLoaded(hasLoaded)
  -- loaded is only set for non-local players to determine if they are ready for the match
  -- the battleRoom is in charge of checking whether all assets have been loaded locally
  if not self.isLocal then
    if hasLoaded ~= self.settings.hasLoaded then
      self.settings.hasLoaded = hasLoaded
      self.hasLoadedChanged()
    end
  end
end

function Player:setDifficulty(difficulty)
  if difficulty ~= self.settings.difficulty then
    self.settings.difficulty = difficulty
    self:setLevelData(LevelPresets.getClassic(difficulty))
    self.difficultyChanged(difficulty)
  end
end

function Player:setLevelData(levelData)
  self.settings.levelData = levelData
  self:setColorCount(levelData.colors)
  self:setSpeed(levelData.startingSpeed)
  self.levelDataChanged(levelData)
end

function Player:setSpeed(speed)
  if speed ~= self.settings.speed or speed ~= self.settings.levelData.startingSpeed then
    self.settings.levelData.startingSpeed = speed
    self.settings.speed = speed
    self.startingSpeedChanged(speed)
  end
end

function Player:setColorCount(colorCount)
  if colorCount ~= self.settings.colorCount or colorCount ~= self.settings.levelData.colors  then
    self.settings.levelData.colors = colorCount
    self.settings.colorCount = colorCount
    self.colorCountChanged(colorCount)
  end
end

function Player:setLevel(level)
  if level ~= self.settings.level then
    self.settings.level = level
    self:setLevelData(LevelPresets.getModern(level))
    self.levelChanged(level)
  end
end

function Player:setInputMethod(inputMethod)
  if inputMethod ~= self.settings.inputMethod then
    self.settings.inputMethod = inputMethod
    self.inputMethodChanged(inputMethod)
  end
end

-- sets the style of "level" presets the player selects from
-- 1 = classic
-- 2 = modern
function Player:setStyle(style)
  if style ~= self.settings.style then
    self.settings.style = style
    if style == GameModes.Styles.MODERN then
      self:setLevelData(LevelPresets.getModern(self.settings.level or config.level))
    else
      self:setLevelData(LevelPresets.getClassic(self.settings.difficulty or config.difficulty))
      self:setSpeed(self.settings.speed)
    end
    -- reset color count while we don't have an established caching mechanism for it
    self:setColorCount(self.settings.levelData.colors)
    self.styleChanged(style)
  end
end

function Player:setPuzzleSet(puzzleSet)
  if puzzleSet ~= self.settings.puzzleSet then
    self.settings.puzzleSet = puzzleSet
    self.puzzleSetChanged(puzzleSet)
  end
end

function Player:setRating(rating)
  if self.rating then
    self.ratingHistory[#self.ratingHistory + 1] = self.rating
  end
  self.rating = rating
  self.ratingChanged(rating)
end

function Player:setAttackEngineSettings(attackEngineSettings)
  if attackEngineSettings ~= self.settings.attackEngineSettings then
    self.settings.attackEngineSettings = attackEngineSettings
    self.attackEngineSettingsChanged(attackEngineSettings)
  end
end

function Player:restrictInputs(inputConfiguration)
  if inputConfiguration.usedByPlayer ~= nil and inputConfiguration.usedByPlayer ~= self then
    error("Trying to assign input configuration to player " .. self.playerNumber ..
      " that is already in use by player " .. inputConfiguration.usedByPlayer.playerNumber)
  end
  self.inputConfiguration = inputConfiguration
  self.inputConfiguration.usedByPlayer = self
end

function Player:unrestrictInputs()
  self.inputConfiguration.usedByPlayer = nil
  self.inputConfiguration = input
end

function Player.getLocalPlayer()
  local player = Player(config.name)

  player:setDifficulty(config.endless_difficulty)
  player:setSpeed(config.endless_speed)
  player:setLevel(config.level)
  player:setCharacter(config.character)
  player:setStage(config.stage)
  player:setPanels(config.panels)
  player:setWantsReady(false)
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

function Player.createFromReplayPlayer(replayPlayer, playerNumber)
  local player = Player(replayPlayer.name, replayPlayer.publicId)

  player.playerNumber = playerNumber
  player.wins = replayPlayer.wins
  player.settings.panelId = replayPlayer.settings.panelId
  player.settings.characterId = CharacterLoader.fullyResolveCharacterSelection(replayPlayer.settings.characterId)
  player.settings.selectedCharacterId = player.settings.characterId
  player.settings.inputMethod = replayPlayer.settings.inputMethod
  -- style will be obsolete for replays with style-independent levelData
  player.settings.style = replayPlayer.settings.style
  player.settings.level = replayPlayer.settings.level
  player.settings.difficulty = replayPlayer.settings.difficulty
  player.settings.levelData = replayPlayer.settings.levelData
  player.settings.allowAdjacentColors = replayPlayer.settings.allowAdjacentColors
  player.settings.attackEngineSettings = replayPlayer.settings.attackEngineSettings

  return player
end

function Player:updateWithMenuState(menuState)
  if characters[menuState.characterId] then
    -- if we have their character, use it
    self:setCharacter(menuState.characterId)
    if characters[menuState.selectedCharacterId] then
      -- picking their bundle for display is a bonus
      self.settings.selectedCharacterId = menuState.selectedCharacterId
      self:onPropertyChanged("selectedCharacterId")
    end
  elseif menuState.selectedCharacterId and characters[menuState.selectedCharacterId] then
    -- if we don't have their character rolled from their bundle, but the bundle itself, use that
    -- very unlikely tbh
    self:setCharacter(menuState.selectedCharacterId)
  elseif self.settings.characterId == "" then
    -- we don't have their character and we didn't roll them a random character yet
    self:setCharacter(consts.RANDOM_CHARACTER_SPECIAL_VALUE)
  end

  if stages[menuState.stageId] then
    -- if we have their stage, use it
    self:setStage(menuState.stageId)
    if stages[menuState.selectedStageId] then
      -- picking their bundle for display is a bonus
      self.settings.selectedStageId = menuState.selectedStageId
      self:onPropertyChanged("selectedStageId")
    end
  elseif menuState.selectedStageId and stages[menuState.selectedStageId] then
    -- if we don't have their stage rolled from their bundle, but the bundle itself, use that
    -- very unlikely tbh
    self:setStage(menuState.selectedStageId)
  elseif self.settings.stageId == "" then
    -- we don't have their stage and we didn't roll them a random stage yet
    self:setStage(consts.RANDOM_STAGE_SPECIAL_VALUE)
  end

  self:setWantsRanked(menuState.wantsRanked)
  if menuState.panelId then
    -- panelId may be absent in some messages due to a server bug
    self:setPanels(menuState.panelId)
  end

  self:setLevel(menuState.level)
  self:setInputMethod(menuState.inputMethod)
end

return Player
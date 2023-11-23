local class = require("class")
local tableUtils = require("tableUtils")
local GameModes = require("GameModes")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")

local MatchSetup = class(function(match, mode, online, localPlayerNumber)
  match.mode = mode
  match:initializeSubscriptionList()
  if mode.style == GameModes.Styles.CHOOSE then
    if config.endless_level then
      match.style = GameModes.Styles.MODERN
    else
      match.style = GameModes.Styles.CLASSIC
    end
  else
    match.style = match.mode.style
  end

  match.online = online
  match.localPlayerNumber = localPlayerNumber

  match.players = {}
  for i = 1, mode.playerCount do
    match.players[i] = {}
    match.players[i].rating = {}
    if not online or i == localPlayerNumber then
      match.players[i].isLocal = true
      match:initializeLocalPlayer(i)
    end
  end
end)

function MatchSetup:initializeSubscriptionList()
  self.subscriptionList = {}
  for i = 1, self.mode.playerCount do
    self.subscriptionList[i] = {}
    self.subscriptionList[i].characterId = {}
    -- extend as necessary
  end
end

-- Ui Elements can subscribe to properties by passing a callback 
-- the callback is executed with the new property value as the argument whenever the property is modified for the player
function MatchSetup:subscribe(property, player, callback)
  self.subscriptionList[player][property][#self.subscriptionList[player][property] + 1] = callback
end

function MatchSetup:onPropertyChanged(property, player)
  if self.subscriptionList[player][property] then
    for i = 1, #self.subscriptionList[player][property] do
      self.subscriptionList[player][property][i](self.players[player][property])
    end
  end
end

function MatchSetup:updateLocalConfig(playerNumber)
  -- update config, does not redefine it
  local player = self.players[playerNumber]
  config.character = player.characterId
  config.stage = player.stageId
  config.level = player.level
  config.inputMethod = player.inputMethod
  config.ranked = player.ranked
  config.panels = player.panelId
end

function MatchSetup:initializeLocalPlayer(playerNumber)
  if self.mode.style == GameModes.Styles.CLASSIC then
    self:setDifficulty(config.endless_difficulty, playerNumber)
    self:setSpeed(config.endless_speed, playerNumber)
  else
    self:setLevel(config.level, playerNumber)
  end

  self:setCharacter(config.character, playerNumber)
  self:setStage(config.stage, playerNumber)
  self:setPanels(config.panels, playerNumber)

  if self.online and self.mode.selectRanked then
    self:setRanked(config.ranked, playerNumber)
  end
end

function MatchSetup:setStage(stageId, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end
  if stageId ~= self.players[player].stageId then
    stageId = StageLoader.resolveStageSelection(stageId)
    self.players[player].stageId = stageId
    StageLoader.load(stageId)

    self:onPropertyChanged("stageId", player)
  end
end

function MatchSetup:setCharacter(characterId, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end
  if characterId ~= self.players[player].characterId then
    characterId = CharacterLoader.resolveCharacterSelection(characterId)
    self.players[player].characterId = characterId
    CharacterLoader.load(characterId)

    self:onPropertyChanged("characterId", player)
  end
end

function MatchSetup:setPanels(panelId, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end

  if panels[panelId] then
    self.players[player].panelId = panelId
  else
    -- default back to player panels always
    self.players[player].panelId = config.panels
  end
  -- panels are always loaded so no loading is necessary

  self:onPropertyChanged("panelId", player)
end

function MatchSetup:setRanked(wantsRanked, player)
  if self.online and self.mode.selectRanked then
    self.players[player].wantsRanked = wantsRanked

    self:onPropertyChanged("wantsRanked", player)
  else
    error("Trying to set ranked in a game mode that doesn't support ranked play")
  end
end

function MatchSetup:setWantsReady(wantsReady, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end

  self.players[player].wantsReady = wantsReady
  self:onPropertyChanged("wantsReady", player)
end

function MatchSetup:setLoaded(hasLoaded, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end

  self.players[player].hasLoaded = hasLoaded
  self:onPropertyChanged("hasLoaded", player)
end

function MatchSetup:setRating(rating, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end

  if self.players[player].rating.new then
    self.players[player].rating.old = self.players[player].rating.new
  end
  self.players[player].rating.new = rating

  self:onPropertyChanged("rating", player)
end

function MatchSetup:setPuzzleFile(puzzleFile, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end

  if self.mode.selectFile == GameModes.FileSelection.Puzzle then
    self.players[player].puzzleFile = puzzleFile
    self:onPropertyChanged("puzzleFile", player)
  else
    error("Trying to set a puzzle file in a game mode that doesn't support puzzle file selection")
  end
end

function MatchSetup:setTrainingFile(player, trainingFile)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end

  if self.mode.selectFile == GameModes.FileSelection.Training then
    self.players[player].trainingFile = trainingFile
    self:onPropertyChanged("trainingFile", player)
  else
    error("Trying to set a training file in a game mode that doesn't support training file selection")
  end
end

function MatchSetup:setStyle(styleChoice)
  -- not sure if style should be configurable per player, doesn't seem to make sense
  if self.mode.style == GameModes.Styles.CHOOSE then
    self.style = styleChoice
    self.onStyleChanged(styleChoice)
  else
    error("Trying to set difficulty style in a game mode that doesn't support style selection")
  end
end

-- not player specific, so this gets a separate callback that can only be overwritten once
function MatchSetup.onStyleChanged(style, player)
end

function MatchSetup:setDifficulty(difficulty, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end

  if self.style == GameModes.Styles.CLASSIC then
    self.players[player].difficulty = difficulty
    self:onPropertyChanged("difficulty", player)
  else
    error("Trying to set difficulty while a non-classic style was selected")
  end
end

function MatchSetup:setSpeed(speed, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end

  if self.style == GameModes.Styles.CLASSIC then
    self.players[player].speed = speed
    self:onPropertyChanged("speed", player)
  else
    error("Trying to set speed while a non-classic style was selected")
  end
end

function MatchSetup:setWinCount(winCount, player)
  if self.mode.playerCount > 1 then
    self.players[player].winCount = winCount
    self:onPropertyChanged("winCount", player)
  else
    error("Trying to set win count in one player modes")
  end
end

function MatchSetup:setLevel(level, player)
  if not player and self.mode.playerCount == 1 then
    player = 1
  end

  if self.style == GameModes.Styles.CLASSIC then
    error("Trying to set level while classic style was selected")
  else
    self.players[player].level = level
    self:onPropertyChanged("level", player)
  end
end

function MatchSetup:refreshReadyStates()
  for playerNumber = 1, #self.players do
    self.players[playerNumber].ready = tableUtils.trueForAll(self.players, function(pc)
      return pc.hasLoaded and pc.wantsReady
    end)
  end
end

function MatchSetup:allReady()
  for playerNumber = 1, #self.players do
    if not self.players[playerNumber].ready then
      return false
    end
  end

  return true
end

function MatchSetup:updateRankedStatus(rankedStatus, comments)
  if self.online and self.mode.selectRanked and rankedStatus ~= self.ranked then
    self.ranked = rankedStatus
    self.rankedComments = comments
    -- legacy crutches
    if self.ranked then
      match_type = "Ranked"
    else
      match_type = "Casual"
    end
  else
    error("Trying to apply ranked state to the match even though it is either not online or does not support ranked")
  end
end

function MatchSetup:abort()
  self.abort = true
end

function MatchSetup:startMatch(stageId, seed, replayOfMatch)
  -- lock down configuration to one per player to avoid macro like abuses via multiple configs
  -- if self.online and self.localPlayerNumber then
  --   GAME.input:requestSingleInputConfigurationForPlayerCount(1)
  -- elseif not self.online then
  --   GAME.input:requestSingleInputConfigurationForPlayerCount(#self.players)
  -- end

  if not GAME.battleRoom then
    GAME.battleRoom = BattleRoom()
  end
  GAME.match = Match(self.mode.matchMode or "vs", GAME.battleRoom)

  self:setMatchStage(stageId)
  self:setSeed(seed)

  if match_type == "Ranked" and not GAME.match.room_ratings then
    GAME.match.room_ratings = {}
  end

  CharacterLoader.wait()
  StageLoader.wait()

  local stacks = self:createStacks()

  if replayOfMatch then
    self:loadReplayData(stacks, replayOfMatch)
  end

  replay = Replay.createNewReplay(GAME.match)

  -- game dies when using the fade transition for unclear reasons
  sceneManager:switchToScene(self.mode.scene, {}, "none")
end

function MatchSetup:setMatchStage(stageId)
  if stageId then
    -- we got one from the server
    self.stageId = StageLoader.resolveStageSelection(stageId)
  elseif self.mode.playerCount == 1 then
    if self.players[1].stageId == random_stage_special_value then
      self.stageId = StageLoader.resolveStageSelection(tableUtils.getRandomElement(stages_ids_for_current_theme))
    else
      self.stageId = self.players[1].stageId
    end
  else
    self.stageId = StageLoader.resolveStageSelection(tableUtils.getRandomElement(stages_ids_for_current_theme))
  end
  StageLoader.load(self.stageId)
  -- TODO check if we can unglobalize that
  current_stage = self.stageId
end

function MatchSetup:getAttackEngine()
  -- TODO: Get these settings via self.trainingFile instead
  local trainingModeSettings = GAME.battleRoom.trainingModeSettings
  local attackEngine = AttackEngine:createEngineForTrainingModeSettings(trainingModeSettings)

  return attackEngine
end

function MatchSetup:generateSeed()
  local seed = 17
  seed = seed * 37 + self.players[1].rating.new
  seed = seed * 37 + self.players[2].rating.new
  seed = seed * 37 + GAME.battleRoom.playerWinCounts[1]
  seed = seed * 37 + GAME.battleRoom.playerWinCounts[2]

  return seed
end

function MatchSetup:getRatingDiff(player)
  return self.players[player].rating.new - self.players[player].rating.old
end

function MatchSetup:setSeed(seed)
  if seed then
    GAME.match.seed = seed
  elseif self.online and #self.players > 1 then
    GAME.match.seed = self:generateSeed()
  elseif self.online and self.ranked and #self.players == 1 then
    -- not used yet but for future time attack leaderboard
    error("Didn't get provided with a seed from the server")
  else
    -- GAME.match has a random seed by default already
  end
end

function MatchSetup:createStacks()
  local stacks = {}

  for playerId = 1, #self.players do
    stacks[playerId] = Stack ({
      which = playerId,
      match = GAME.match,
      is_local = self.players[playerId].isLocal,
      panels_dir = self.players[playerId].panelId,
      level = self.players[playerId].level,
      character = self.players[playerId].characterId,
      player_number = playerId
    })
  end

  GAME.match:addPlayer(stacks[1])
  if stacks[2] then
    GAME.match:addPlayer(stacks[2])
  end

  if self.online and self.localPlayerNumber then
    -- to make sure the local player ends up as player 1 locally
    -- but without messing up the interpretation of server messages by flipping numbers
    table.sort(stacks, function(a, b)
      return a.isLocal > b.isLocal
    end)
  end

  if stacks[2] then
    stacks[2]:moveForPlayerNumber(2)
  end

  if self.mode.stackInteraction == GameModes.StackInteraction.Versus then
    for i = 1, #stacks do
      for j = 1, #stacks do
        if i ~= j then
          -- once we have more than 2P in a single mode, setGarbageTarget needs to put these into an array
          -- or we rework it anyway for team play
          stacks[i]:setGarbageTarget(stacks[j])
        end
      end
    end
  elseif self.mode.stackInteraction == GameModes.StackInteraction.Self then
    for i = 1, #stacks do
      stacks[i]:setGarbageTarget(stacks[i])
    end
  elseif self.mode.stackInteraction == GameModes.StackInteraction.AttackEngine then
    local attackEngine
    self:getAttackEngine()
    for i = 1, #stacks do
      local attackEngineClone = deepcpy(attackEngine)
      attackEngineClone:setGarbageTarget(stacks[i])
    end
  end

  -- Prepare to start the game
  for i = 1, #stacks do
    stacks[i]:starting_state()
  end

  return stacks
end

function MatchSetup:loadReplayData(stacks, replay)
  if self.online and not self.localPlayerNumber then
    -- we're spectating
    stacks[1]:receiveConfirmedInput(uncompress_input_string(replay.vs.in_buf))
    if stacks[2] then
      stacks[2]:receiveConfirmedInput(uncompress_input_string(replay.vs.I))
    end

    replay_of_match_so_far = nil
    -- this makes non local stacks run until caught up
    stacks[1].play_to_end = true
    if stacks[2] then
      stacks[2].play_to_end = true
    end
  end

  return stacks
end

function MatchSetup:updateLoadingState()
  local fullyLoaded = true
  for i = 1, #self.players do
    if not characters[self.players[i].characterId].fully_loaded or not stages[self.players[i].stageId].fully_loaded then
      fullyLoaded = false
    end
  end

  for i = 1, #self.players do
    -- only need to update for local players, network will update us for others
    if self.players[i].isLocal then
      self:setLoaded(fullyLoaded, i)
    end
  end
end

function MatchSetup:update()
  -- here we fetch network updates and update the match setup if applicable

  -- if there are still unloaded assets, we can load them 1 asset a frame in the background
  StageLoader.update()
  CharacterLoader.update()

  self:updateLoadingState()
  self:refreshReadyStates()
  if self:allReady() then
    self:startMatch()
  end
end

return MatchSetup

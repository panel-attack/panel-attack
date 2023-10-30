local class = require("class")
local util = require("util")
local tableUtils = require("tableUtils")
local logger = require("logger")
local GameModes = require("GameModes")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")

local MatchSetup = class(function(match, mode, online, localPlayerNumber)
  match.mode = mode
  if mode.style == GameModes.Styles.Choose then
    if config.endless_level then
      match.style = GameModes.Styles.Modern
    else
      match.style = GameModes.Styles.Classic
    end
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

function MatchSetup:initializeLocalPlayer(playerNumber)
  if self.style == GameModes.Styles.Classic then
    self:setDifficulty(playerNumber, config.endless_difficulty)
    self:setSpeed(playerNumber, config.endless_speed)
  else
    self:setLevel(playerNumber, config.level)
  end

  self:setCharacter(playerNumber, config.character)
  self:setStage(playerNumber, config.stage)
  self:setPanels(playerNumber, config.panels)

  if self.online and self.mode.selectRanked then
    self:setRanked(playerNumber, config.ranked)
  end
end

function MatchSetup:setStage(player, stageId)
  if stageId ~= self.players[player].stageId then
    stageId = StageLoader.resolveStageSelection(stageId)
    self.players[player].stageId = stageId
    StageLoader.load(stageId)
  end
end

function MatchSetup:setCharacter(player, characterId)
  if characterId ~= self.players[player].characterId then
    characterId = CharacterLoader.resolveCharacterSelection(characterId)
    self.players[player].characterId = characterId
    CharacterLoader.load(characterId)
  end
end

function MatchSetup:setPanels(player, panelId)
  -- panels are always loaded
  if panels[panelId] then
    self.players[player].panelId = panelId
  else
    -- default back to player panels always
    self.players[player].panelId = config.panels
  end
end

function MatchSetup:setRanked(player, wantsRanked)
  if self.online and self.mode.selectRanked then
    self.players[player].wantsRanked = wantsRanked
  else
    error("Trying to set ranked in a game mode that doesn't support ranked play")
  end
end

function MatchSetup:setWantsReady(player, wantsReady)
  self.players[player].wantsReady = wantsReady
end

function MatchSetup:setLoaded(player, hasLoaded)
  self.players[player].hasLoaded = hasLoaded
end

function MatchSetup:setRating(player, rating)
  if self.players[player].rating.new then
    self.players[player].rating.old = self.players[player].rating.new
  end
  self.players[player].rating.new = rating
end

function MatchSetup:setPuzzleFile(player, puzzleFile)
  if self.mode.selectFile == GameModes.FileSelection.Puzzle then
    self.players[player].puzzleFile = puzzleFile
  else
    error("Trying to set a puzzle file in a game mode that doesn't support puzzle file selection")
  end
end

function MatchSetup:setTrainingFile(player, trainingFile)
  if self.mode.selectFile == GameModes.FileSelection.Training then
    self.players[player].trainingFile = trainingFile
  else
    error("Trying to set a training file in a game mode that doesn't support training file selection")
  end
end

function MatchSetup:setStyle(styleChoice)
  -- not sure if style should be configurable per player, doesn't seem to make sense
  if self.mode.style == GameModes.Styles.Choose then
    self.style = styleChoice
  else
    error("Trying to set difficulty style in a game mode that doesn't support style selection")
  end
end

function MatchSetup:setDifficulty(player, difficulty)
  if self.style == GameModes.Styles.Classic then
    self.players[player].difficulty = difficulty
  else
    error("Trying to set difficulty while a non-classic style was selected")
  end
end

function MatchSetup:setSpeed(player, speed)
  if self.style == GameModes.Styles.Classic then
    self.players[player].speed = speed
  else
    error("Trying to set speed while a non-classic style was selected")
  end
end

function MatchSetup:setWinCount(player, winCount)
  if self.mode.playerCount > 1 then
    self.players[player].winCount = winCount
  else
    error("Trying to set win count in one player modes")
  end
end

function MatchSetup:setLevel(player, level)
  if self.style == GameModes.Styles.Classic then
    error("Trying to set level while classic style was selected")
  else
    self.players[player].level = level
  end
end

function MatchSetup.refreshReadyStates(self)
  for playerNumber = 1, #self.players do
    self.players[playerNumber].ready = tableUtils.trueForAll(self.players, function(pc)
      return pc.hasLoaded and pc.wantsReady
    end)
  end
end

function MatchSetup:setCursorPositionId(player, cursorPositionId)
  self.players[player].cursorPositionId = cursorPositionId
end

function MatchSetup:updateRankedStatus(rankedStatus, comments)
  if self.online and self.mode.selectRanked then
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

  sceneManager:switchToScene(self.mode.scene)
end

function MatchSetup:setMatchStage(stageId)
  if stageId then
    -- we got one from the server
    self.stageId = StageLoader.resolveStageSelection(stageId)
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
    stacks[playerId] = Stack {
      which = playerId,
      match = GAME.match,
      is_local = self.players[playerId].isLocal,
      panels_dir = self.players[playerId].panels,
      level = self.players[playerId].level,
      character = self.players[playerId].character,
      player_number = playerId
    }
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
      self:setLoaded(i, fullyLoaded)
    end
  end
end

function MatchSetup:update()
  -- here we fetch network updates and update the match setup if applicable
end

return MatchSetup

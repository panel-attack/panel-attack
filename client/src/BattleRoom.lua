local logger = require("common.lib.logger")
local Player = require("client.src.Player")
local tableUtils = require("common.lib.tableUtils")
local sceneManager = require("client.src.scenes.sceneManager")
local GameModes = require("common.engine.GameModes")
local class = require("common.lib.class")
local ServerMessages = require("client.src.network.ServerMessages")
local ReplayV1 = require("client.src.replayV1")
local Signal = require("common.lib.signal")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local ModController = require("client.src.mods.ModController")
local ModLoader = require("client.src.mods.ModLoader")
local Match = require("common.engine.match")
require("client.src.graphics.match_graphics")

-- A Battle Room is a session of matches, keeping track of the room number, player settings, wins / losses etc
BattleRoom = class(function(self, mode)
  assert(mode)
  self.mode = mode
  self.players = {}
  self.spectators = {}
  self.spectating = false
  self.allAssetsLoaded = false
  self.ranked = false
  self.state = 1
  self.matchesPlayed = 0
  -- this is a bit naive but effective for now
  self.online = GAME.tcpClient:isConnected()

  Signal.turnIntoEmitter(self)
  self:createSignal("rankedStatusChanged")
  self:createSignal("allAssetsLoadedChanged")
end)

-- defining these here so they're available in network.BattleRoom too
-- maybe splitting BattleRoom wasn't so smart after all
BattleRoom.states = { Setup = 1, MatchInProgress = 2 }


function BattleRoom.createFromMatch(match)
  local gameMode = {}
  gameMode.playerCount = #match.players
  gameMode.doCountdown = match.doCountdown
  gameMode.stackInteraction = match.stackInteraction
  gameMode.winConditions = deepcpy(match.winConditions)
  gameMode.gameOverConditions = deepcpy(match.gameOverConditions)
  gameMode.playerCount = #match.players

  local battleRoom = BattleRoom(gameMode)

  for i = 1, #match.players do
    battleRoom:addPlayer(match.players[i])
  end

  battleRoom.match = match
  battleRoom.match:start()
  battleRoom.state = BattleRoom.states.MatchInProgress

  return battleRoom
end

function BattleRoom.createFromServerMessage(message)
  local battleRoom
  -- two player versus being the only option so far
  -- in the future this information should be in the message!
  local gameMode = GameModes.getPreset("TWO_PLAYER_VS")

  if message.spectate_request_granted then
    message = ServerMessages.sanitizeSpectatorJoin(message)
    if message.replay then
      local replay = ReplayV1.transform(message.replay)
      local match = Match.createFromReplay(replay, false)
      -- need this to make sure both have the same player tables
      -- there's like one stupid reference to battleRoom in engine that breaks otherwise
      battleRoom = BattleRoom.createFromMatch(match)
      battleRoom.mode.gameScene = gameMode.gameScene
      battleRoom.mode.setupScene = gameMode.setupScene
      battleRoom.mode.richPresenceLabel = gameMode.richPresenceLabel
    else
      battleRoom = BattleRoom(gameMode)
      for i = 1, #message.players do
        local player = Player(message.players[i].name, message.players[i].playerNumber, false)
        battleRoom:addPlayer(player)
      end
    end
    for i = 1, #battleRoom.players do
      battleRoom.players[i]:updateWithMenuState(message.players[i])
      battleRoom.players[i]:setRating(message.players[i].ratingInfo.new)
      battleRoom.players[i]:setLeague(message.players[i].ratingInfo.league)
    end
    if message.winCounts then
      battleRoom:setWinCounts(message.winCounts)
    end
    battleRoom.spectating = true
  else
    battleRoom = BattleRoom(gameMode)
    message = ServerMessages.sanitizeCreateRoom(message)
    -- player 1 is always the local player so that data can be ignored in favor of local data
    battleRoom:addPlayer(GAME.localPlayer)
    GAME.localPlayer.playerNumber = message.players[1].playerNumber
    GAME.localPlayer:setRating(message.players[1].ratingInfo.new)
    GAME.localPlayer:setLeague(message.players[1].ratingInfo.league)

    local player2 = Player(message.players[2].name, -1, false)
    player2.playerNumber = message.players[2].playerNumber
    player2:updateWithMenuState(message.players[2])
    player2:setRating(message.players[2].ratingInfo.new)
    player2:setLeague(message.players[2].ratingInfo.league)
    battleRoom:addPlayer(player2)
  end

  battleRoom:assignInputConfigurations()
  battleRoom:registerNetworkCallbacks()

  return battleRoom
end

function BattleRoom.createLocalFromGameMode(gameMode)
  local battleRoom = BattleRoom(gameMode)

  if gameMode.playerCount == 1 then
    -- always use the game client's local player
    battleRoom:addPlayer(GAME.localPlayer)
  else
    -- with more than 1 local player we can't be sure which player is the "real" regular user
    -- so make them both local players that don't update config settings
    for i = 1, gameMode.playerCount do
      local player = Player.getLocalPlayer()
      player.name = loc("player_n", i)
      battleRoom:addPlayer(player)
    end
  end

  if gameMode.style ~= GameModes.Styles.CHOOSE then
    for i = 1, #battleRoom.players do
      battleRoom.players[i]:setStyle(gameMode.style)
    end
  end

  battleRoom:assignInputConfigurations()

  return battleRoom
end

function BattleRoom.setWinCounts(self, winCounts)
  for _, player in ipairs(self.players) do
    -- win counts are sent indexed by player number
    player:setWinCount(winCounts[player.playerNumber])
  end

  self:updateWinrates()
end

function BattleRoom:updateWinrates()
  local gamesPlayed
  if tableUtils.trueForAny(self.players, function(p) return p.isLocal end) then
    gamesPlayed = self.matchesPlayed
  else
    gamesPlayed = self:totalGames()
  end
  for _, player in ipairs(self.players) do
    if gamesPlayed > 0 then
      local winrate = 100 * round(player.wins / gamesPlayed, 2)
      player:setWinrate(winrate)
    else
      player:setWinrate(0)
    end
  end
end

local RATING_SPREAD_MODIFIER = 400
function BattleRoom:updateExpectedWinrates()
  if tableUtils.trueForAll(self.players, function(p) return p.rating and tonumber(p.rating) end) then
    -- this isn't feasible to do for n-player matchups at this point
    local p1 = self.players[1]
    local p2 = self.players[2]
    p1:setExpectedWinrate((100 * round(1 / (1 + 10 ^ ((p2.rating - p1.rating) / RATING_SPREAD_MODIFIER)), 2)))
    p2:setExpectedWinrate((100 * round(1 / (1 + 10 ^ ((p1.rating - p2.rating) / RATING_SPREAD_MODIFIER)), 2)))
  end
end

-- returns the total amount of games played, derived from the sum of wins across all players
-- (this means draws don't count as games, reference BattleRoom.matchesPlayed if you want draws included)
function BattleRoom:totalGames()
  local totalGames = 0
  for i = 1, #self.players do
    totalGames = totalGames + self.players[i].wins
  end
  return totalGames
end

-- Returns the player with more win count.
-- TODO handle ties?
function BattleRoom:winningPlayer()
  if #self.players == 1 then
    return self.players[1]
  else
    if self.players[1].wins >= self.players[2].wins then
      return self.players[1]
    else
      return self.players[2]
    end
  end
end

-- creates a match with the players in the BattleRoom
function BattleRoom:createMatch()
  local supportsPause = not self.online or #self.players == 1
  local optionalArgs = { timeLimit = self.mode.timeLimit , ranked = self.ranked}

  self.match = Match(
    self.players,
    self.mode.doCountdown,
    self.mode.stackInteraction,
    shallowcpy(self.mode.winConditions),
    shallowcpy(self.mode.gameOverConditions),
    supportsPause,
    optionalArgs
  )

  self.match:connectSignal("matchEnded", self, self.onMatchEnded)

  for _, player in ipairs(self.players) do
    self.match:connectSignal("matchEnded", player, player.onMatchEnded)
  end

  self.match:setSpectatorList(self.spectators)

  return self.match
end

-- creates a new Player based on their minimum information and adds them to the BattleRoom
function BattleRoom:addNewPlayer(name, publicId, isLocal)
  local player = Player(name, publicId, isLocal)
  player.playerNumber = #self.players + 1
  self:addPlayer(player)
  return player
end

-- adds an existing Player to the BattleRoom
function BattleRoom:addPlayer(player)
  if not player.playerNumber then
    player.playerNumber = #self.players + 1
  end
  self.players[#self.players + 1] = player

  if player.isLocal then
    self:connectSignal("allAssetsLoadedChanged", player, player.setLoaded)
  end
end

function BattleRoom:updateLoadingState()
  local fullyLoaded = true
  for i = 1, #self.players do
    local player = self.players[i]
    if not characters[player.settings.characterId].fully_loaded or not stages[player.settings.stageId].fully_loaded then
      fullyLoaded = false
    end
  end

  if self.allAssetsLoaded ~= fullyLoaded then
    self.allAssetsLoaded = fullyLoaded
    self:emitSignal("allAssetsLoadedChanged", self.allAssetsLoaded)
  end

  if not self.allAssetsLoaded then
    self:startLoadingNewAssets()
  end
end

function BattleRoom:refreshReadyStates()
  local minimumCondition = tableUtils.trueForAll(self.players, function(p)
    -- everyone remote finished loading and actually wants to start
    return p.isLocal or (p.hasLoaded and p.settings.wantsReady)
  end)

  for _, player in ipairs(self.players) do
    if player.isLocal then
      -- every local human player has an input configuration assigned; touch substitutes for an inputConfiguration
      local ready = minimumCondition
        and self.allAssetsLoaded and player.settings.wantsReady
        and (not player.human or (player.inputConfiguration or player.settings.inputMethod == "touch"))
      player:setReady(ready)
    else
      -- non local players send us their ready via network
    end
  end
end

-- returns true if all players are ready, false otherwise
function BattleRoom:allReady()
  -- ready should probably be a battleRoom prop, not a player prop? at least for local player(s)?
  for playerNumber = 1, #self.players do
    if not self.players[playerNumber].ready then
      return false
    end
  end

  return true
end

function BattleRoom:updateRankedStatus(rankedStatus, comments)
  if self.online then
    self.ranked = rankedStatus
    self.rankedComments = comments
    self:emitSignal("rankedStatusChanged", rankedStatus, comments)
  else
    error("Trying to apply ranked state to the room even though it is either not online or does not support ranked")
  end
end

-- creates a match based on the room and player settings, starts it up and switches to the Game scene
function BattleRoom:startMatch(stageId, seed, replayOfMatch)
  local match = self:createMatch()

  match.replay = replayOfMatch
  match:setStage(stageId)
  match:setSeed(seed)

  if (#match.players > 1 or match.stackInteraction == GameModes.StackInteractions.VERSUS) then
    GAME.rich_presence:setPresence((match:hasLocalPlayer() and "Playing" or "Spectating") .. " a " .. (self.mode.richPresenceLabel or self.mode.gameScene) ..
                                       " match", match.players[1].name .. " vs " .. (match.players[2].name), true)
  else
    GAME.rich_presence:setPresence("Playing " .. self.mode.richPresenceLabel .. " mode", nil, true)
  end

  if self.ranked and not match.room_ratings then
    match.room_ratings = {}
  end

  match:start()
  self.state = BattleRoom.states.MatchInProgress
  local scene = sceneManager:createScene(self.mode.gameScene, {match = self.match, nextScene = self.mode.setupScene})
  sceneManager:switchToScene(scene)
end

-- sets the style of "level" presets the players select from
-- 1 = classic
-- 2 = modern
-- in the future this may become a player only prop but for now it's battleRoom wide and players have to match
function BattleRoom:setStyle(styleChoice)
  -- style could be configurable per play instead but let's not for now
  if self.mode.style == GameModes.Styles.CHOOSE then
    self.style = styleChoice
    self.onStyleChanged(styleChoice)
  else
    error("Trying to set difficulty style in a game mode that doesn't support style selection")
  end
end

-- not player specific, so this gets a separate callback that can only be overwritten once
-- so the UI can update and load up the different controls for it
function BattleRoom.onStyleChanged(style, player)
end

function BattleRoom:startLoadingNewAssets()
  if ModLoader.loading_mod == nil then
    for _, player in ipairs(self.players) do
      if not stages[player.settings.stageId].fully_loaded then
        logger.debug("Loading stage " .. player.settings.stageId .. " as part of BattleRoom:startLoadingNewAssets")
        ModController:loadModFor(stages[player.settings.stageId], player)
      end
      if not characters[player.settings.characterId].fully_loaded then
        logger.debug("Loading stage " .. player.settings.characterId .. " as part of BattleRoom:startLoadingNewAssets")
        ModController:loadModFor(characters[player.settings.characterId], player)
      end
    end
  end
end

-- updates a player's input configuration
-- if lock is true it tries to claim the first unclaim inputConfiguration for which a key is down (may not claim any)
-- if lock is false it unclaims the player's current inputConfiguration
function BattleRoom.updateInputConfigurationForPlayer(player, lock)
  if lock then
    for _, inputConfiguration in ipairs(GAME.input.inputConfigurations) do
      if not inputConfiguration.claimed and tableUtils.length(inputConfiguration.isDown) > 0 then
        -- assign the first unclaimed input configuration that is used
        player:setInputMethod("controller")
        player:restrictInputs(inputConfiguration)
        break
      end
    end
    if not player.inputConfiguration and not GAME.input.mouse.claimed then
      if GAME.input.mouse.isDown[1] or GAME.input.mouse.isPressed[1] then
        player:setInputMethod("touch")
        player:restrictInputs(GAME.input.mouse)
      end
    end
  else
    -- player can always go from controller to touch but not the other way around
    player:setInputMethod("controller")
    player:unrestrictInputs()
  end
end

-- sets up the process to get an input configuration assigned for every local player
function BattleRoom:assignInputConfigurations()
  local localPlayers = {}
  for i = 1, #self.players do
    if self.players[i].isLocal and self.players[i].human then
      localPlayers[#localPlayers + 1] = self.players[i]
    end
  end

  -- assert that there are enough valid input configurations actually configured
  local validInputConfigurationCount = 0
  for _, inputConfiguration in ipairs(GAME.input.inputConfigurations) do
    if inputConfiguration["Swap1"] then
      validInputConfigurationCount = validInputConfigurationCount + 1
    end
  end

  if validInputConfigurationCount < #localPlayers then
    local messageText = "There are more local players than input configurations configured." ..
    "\nPlease configure enough input configurations and try again"
    local nextScene = sceneManager:createScene("MainMenu")
    local transition = MessageTransition(GAME.timer, 5, sceneManager.activeScene, nextScene, messageText)
    sceneManager:switchToScene(nextScene, transition)
    self:shutdown()
  else
    if #localPlayers == 1 then
      -- lock the inputConfiguration whenever the player readies up (and release it when they unready)
      -- the ready up press guarantees that at least 1 input config has a key down
      localPlayers[1]:connectSignal("wantsReadyChanged", localPlayers[1], self.updateInputConfigurationForPlayer)
    elseif #localPlayers > 1 then
      -- with multiple local players we need to lock immediately so they can configure
      -- set a flag so this is continuously attempted in update
      self.tryLockInputs = true
    end
  end
end

-- tries to assign unclaimed input configurations for all local players based on currently used inputs
function BattleRoom:tryAssignInputConfigurations()
  if self.tryLockInputs then
    for _, player in ipairs(self.players) do
      if player.isLocal and player.human and not player.inputConfiguration then
        BattleRoom.updateInputConfigurationForPlayer(player, true)
      end
    end
    self.tryLockInputs = tableUtils.trueForAny(self.players,
                          function(p)
                            return p.isLocal and p.human and not p.inputConfiguration
                          end)
  end
end

function BattleRoom:update(dt)
  -- if there are still unloaded assets, we can load them 1 asset a frame in the background
  ModController:update()

  if self.online then
    -- here we fetch network updates and update the battleroom / match
    if not GAME.tcpClient:processIncomingMessages() then
      -- oh no, we probably disconnected
      self:shutdown()
      -- let's try to log in back via lobby
      sceneManager:switchToScene(sceneManager:createScene("Lobby"))
      return
    else
      GAME.tcpClient:updateNetwork(dt)
      self:runNetworkTasks()
    end
  end

  if self.state == BattleRoom.states.Setup then
    -- the setup phase of the room
    self:tryAssignInputConfigurations()
    self:updateLoadingState()
    self:refreshReadyStates()
    if self:allReady() then
      -- if online we have to wait for the server message
      if not self.online then
        self:startMatch()
      end
    end
  end
end

function BattleRoom:shutdown()
  for i, player in ipairs(self.players) do
    if player.human then
      -- this is to clear the input configs for future use
      player:unrestrictInputs()
    end
  end
  if self.match then
    self.match:deinit()
    self.match = nil
  end
  self:shutdownNetwork()
  self.hasShutdown = true
  GAME:initializeLocalPlayer()
  GAME.battleRoom = nil
  self = nil
end

-- a callback function that is getting registered to the Match:onMatchEnded signal
-- may get unregistered from the match in case of abortion
function BattleRoom:onMatchEnded(match)
  self.matchesPlayed = self.matchesPlayed + 1

  if not match.aborted then
    local winners = match:getWinners()
    -- apply wins and possibly statistical data up for collection
    if #winners == 1 then
      -- increment win count on winning player if there is only one
      winners[1]:incrementWinCount()
    end
    if self.online and match:hasLocalPlayer() then
      self:reportLocalGameResult(winners)
    end
  else
    -- match:deinit is the responsibility of the one switching out of the game scene
    match:deinit()
    -- in the case of a network based abort, the network part of the battleRoom would unregister from the onMatchEnded signal
    -- and initialise the transition to wherever else before calling abort on the match to finalize it
    -- that means whenever we land here, it was a match-side local abort that leaves the room intact
    local setupScene = sceneManager:createScene(self.mode.setupScene)
    if match.desyncError then
      -- match could have a desync error
      -- -> back to select screen, battleRoom stays intact
      -- ^ this behaviour is different to the past but until the server tells us the room is dead there is no reason to assume it to be dead
      sceneManager:switchToScene(setupScene, MessageTransition(GAME.timer, 5, sceneManager.activeScene, setupScene, "ss_latency_error"))
    else
      -- local player could pause and leave
      -- -> back to select screen, battleRoom stays intact
      sceneManager:switchToScene(setupScene)
    end

    -- other aborts come via network and are directly handled in response to the network message (or lack thereof)
  end

  -- nilling the match here doesn't keep the game scene from rendering it as the scene has its own reference
  self.match = nil
  self.state = BattleRoom.states.Setup
end

-- called in the errorhandler and thus has a lot worried checking
function BattleRoom:getInfo()
  local info = {}
  if self.players and type(self.players == "table") then
    info.players = {}
    for i, player in ipairs(self.players) do
      if player.getInfo and type(player.getInfo) == "function" then
        info.players[i] = player:getInfo()
      end
    end
  end
  info.online = tostring(self.online)
  info.spectating = tostring(self.spectating)
  info.allAssetsLoaded = tostring(self.allAssetsLoaded)
  info.state = self.state

  return info
end

return BattleRoom

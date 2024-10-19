local class = require("common.lib.class")
local TcpClient = require("client.src.network.TcpClient")
local MessageListener = require("client.src.network.MessageListener")
local ServerMessages = require("client.src.network.ServerMessages")
local ClientMessages = require("common.network.ClientProtocol")
local tableUtils = require("common.lib.tableUtils")
local NetworkProtocol = require("common.network.NetworkProtocol")
local logger = require("common.lib.logger")
local Signal = require("common.lib.signal")
local CharacterSelect2p = require("client.src.scenes.CharacterSelect2p")
local SoundController = require("client.src.music.SoundController")
local GameCatchUp = require("client.src.scenes.GameCatchUp")
local Game2pVs = require("client.src.scenes.Game2pVs")
local LoginRoutine = require("client.src.network.LoginRoutine")


local states = { OFFLINE = 1, LOGIN = 2, ONLINE = 3, ROOM = 4, INGAME = 5 }

-- Most functions of NetClient are private as they only should get triggered via incoming server messages
--  that get automatically processed via NetClient:update

local function resetLobbyData(self)
  self.lobbyData = {
    players = {},
    unpairedPlayers = {},
    willingPlayers = {},
    spectatableRooms = {},
    sentRequests = {}
  }
end

local function updateLobbyState(self, lobbyState)
  if lobbyState.players then
    self.lobbyData.players = lobbyState.players
  end

  if lobbyState.unpaired then
    self.lobbyData.unpairedPlayers = lobbyState.unpaired
    -- players who leave the unpaired list no longer have standing invitations to us.\
    -- we also no longer have a standing invitation to them, so we'll remove them from sentRequests
    local newWillingPlayers = {}
    local newSentRequests = {}
    for _, player in ipairs(self.lobbyData.unpairedPlayers) do
      newWillingPlayers[player] = self.lobbyData.willingPlayers[player]
      newSentRequests[player] = self.lobbyData.sentRequests[player]
    end
    self.lobbyData.willingPlayers = newWillingPlayers
    self.lobbyData.sentRequests = newSentRequests
  end

  if lobbyState.spectatable then
    self.lobbyData.spectatableRooms = lobbyState.spectatable
  end

  self:emitSignal("lobbyStateUpdate", self.lobbyData)
end

-- starts a 2p vs online match
local function start2pVsOnlineMatch(self, createRoomMessage)
  resetLobbyData(self)
  GAME.battleRoom = BattleRoom.createFromServerMessage(createRoomMessage)
  self.room = GAME.battleRoom
  love.window.requestAttention()
  SoundController:playSfx(themes[config.theme].sounds.notification)
  GAME.navigationStack:push(CharacterSelect2p())
  self.state = states.ROOM
end

local function processSpectatorListMessage(self, message)
  if self.room then
    self.room:setSpectatorList(message.spectators)
  end
end

local function processCharacterSelectMessage(self, message)
  -- receiving a character select message means that both players have reported their game results to the server
  -- that means from here on it is expected to receive no further input messages from either player
  -- if we went game over first, the opponent will notice later and keep sending inputs until we went game over on their end too
  -- these extra messages will remain unprocessed in the queue and need to be cleared up so they don't get applied the next match
  self.tcpClient:dropOldInputMessages()

  if not self.room then
    return
  end

  -- character_select and create_room are the same message
  -- except that character_select has an additional character_select = true flag
  message = ServerMessages.sanitizeCreateRoom(message)
  for _, messagePlayer in ipairs(message.players) do
    for _, roomPlayer in ipairs(self.room.players) do
      if messagePlayer.playerNumber == roomPlayer.playerNumber then
        if messagePlayer.ratingInfo then
          roomPlayer:setRating(messagePlayer.ratingInfo.new)
          roomPlayer:setLeague(messagePlayer.ratingInfo.league)
        end
        if not roomPlayer.isLocal then
          roomPlayer:updateWithMenuState(messagePlayer)
        end
      end
    end
  end

  self.room:updateExpectedWinrates()
  self.state = states.ROOM
end

local function processLeaveRoomMessage(self, message)
  if self.room then
    if self.room.match then
      -- we're ending the game via an abort so we don't want to enter the standard onMatchEnd callback
      self.room.match:disconnectSignal("matchEnded", self.room)
      -- instead we actively abort the match ourselves
      self.room.match:abort()
      self.room.match:deinit()
    end

    -- and then shutdown the room
    self.room:shutdown()
    self.room = nil

    self.state = states.ONLINE
    GAME.navigationStack:popToName("Lobby")
  end
end

local function processTauntMessage(self, message)
  if not self.room then
    return
  end

  local characterId = tableUtils.first(self.room.players, function(player)
    return player.playerNumber == message.player_number
  end).settings.characterId
  characters[characterId]:playTaunt(message.type, message.index)
end

local function processMatchStartMessage(self, message)
  if not self.room then
    return
  end

  message = ServerMessages.sanitizeStartMatch(message)

  for _, playerSettings in ipairs(message.playerSettings) do
    -- contains level, characterId, panelId
    for _, player in ipairs(self.room.players) do
      if playerSettings.playerNumber == player.playerNumber then
        -- verify that settings on server and local match to prevent desync / crash
        if playerSettings.level ~= player.settings.level then
          player:setLevel(playerSettings.level)
        end
        if player.isLocal then
          if not player.inputConfiguration then
            -- fallback in case the player lost their input config while the server sent the message
            player:restrictInputs(player.lastUsedInputConfiguration)
          end
        else
          if playerSettings.inputMethod ~= player.settings.inputMethod then
            -- since only one player can claim touch, touch is unclaimed every time we return to character select
            -- this also means they will send controller as their input method until they ready up
            -- if the remote touch player readies up AFTER the local client, we never get informed about the change in input method
            -- besides for the match start message itself
            -- so it's very important to set this here
            player:setInputMethod(playerSettings.inputMethod)
          end
        end
        -- generally I don't think it's a good idea to try and rematch the other diverging settings here
        -- everyone is loaded and ready which can only happen after character/panel data was already exchanged
        -- if they diverge it's because the chosen mod is missing on the other client
        -- generally I think server should only send physics relevant data with match_start
      end
    end
  end

  if self.state == states.INGAME then
    -- if there is a match in progress when receiving a match start that means we are in the process of catching up via transition
    -- deinit and nil to cancel the catchup
    self.room.match:deinit()
    self.room.match = nil

    -- although the most important thing is replacing the on-going transition but startMatch already does that as a default
  end

  self.tcpClient:dropOldInputMessages()
  self.room:startMatch(message.stageId, message.seed)
  self.state = states.INGAME
end

local function processWinCountsMessage(self, message)
  if not self.room then
    return
  end

  self.room:setWinCounts(message.win_counts)
end

local function processRankedStatusMessage(self, message)
  if not self.room then
    return
  end

  local rankedStatus = message.ranked_match_approved or false
  local comments = ""
  if message.reasons then
    comments = comments .. table.concat(message.reasons, "\n")
  end
  if message.caveats then
    comments = comments .. table.concat(message.caveats, "\n")
  end
  self.room:updateRankedStatus(rankedStatus, comments)
end

local function processMenuStateMessage(player, message)
  local menuState = ServerMessages.sanitizeMenuState(message.menu_state)
  if message.player_number then
    -- only update if playernumber matches the player's
    if message.player_number == player.playerNumber then
      player:updateWithMenuState(menuState)
    else
      -- this update is for someone else
    end
  else
    player:updateWithMenuState(menuState)
  end
end

local function processInputMessages(self)
  local messages = self.tcpClient.receivedMessageQueue:pop_all_with(NetworkProtocol.serverMessageTypes.opponentInput.prefix, NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix)
  for _, msg in ipairs(messages) do
    for type, data in pairs(msg) do
      logger.trace("Processing: " .. type .. " with data:" .. data)
      if type == NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix then
        self.room.match.stacks[1]:receiveConfirmedInput(data)
      elseif type == NetworkProtocol.serverMessageTypes.opponentInput.prefix then
        self.room.match.stacks[2]:receiveConfirmedInput(data)
      end
    end
  end
end

local function processGameRequest(self, gameRequestMessage)
  if gameRequestMessage.game_request then
    self.lobbyData.willingPlayers[gameRequestMessage.game_request.sender] = true
    love.window.requestAttention()
    SoundController:playSfx(themes[config.theme].sounds.notification)
    -- this might be moot if the server sends a lobby update to everyone after receiving the challenge
    self:emitSignal("lobbyStateUpdate", self.lobbyData)
  end
end

-- starts to spectate a 2p vs online match
local function spectate2pVsOnlineMatch(self, spectateRequestGrantedMessage)
  GAME.battleRoom = BattleRoom.createFromServerMessage(spectateRequestGrantedMessage)
  self.room = GAME.battleRoom
  if GAME.battleRoom.match then
    self.state = states.INGAME
    local vsScene = Game2pVs({match = GAME.battleRoom.match})
    local catchUp = GameCatchUp(vsScene)
    -- need to push character select, otherwise the pop on match end will return to lobby
    -- directly add to the stack so it isn't getting displayed
    GAME.navigationStack.scenes[#GAME.navigationStack.scenes+1] = CharacterSelect2p()
    GAME.navigationStack:push(catchUp)
  else
    self.state = states.ROOM
    GAME.navigationStack:push(CharacterSelect2p())
  end
end

local function createListener(self, messageType, callback)
  local listener = MessageListener(messageType)
  listener:subscribe(self, callback)
  return listener
end

local function createListeners(self)
  -- messageListener holds *all* available listeners
  local messageListeners = {}
  messageListeners.create_room = createListener(self, "create_room", start2pVsOnlineMatch)
  messageListeners.players = createListener(self, "players", updateLobbyState)
  messageListeners.game_request = createListener(self, "game_request", processGameRequest)
  messageListeners.menu_state = createListener(self, "menu_state", processMenuStateMessage)
  messageListeners.win_counts = createListener(self, "win_counts", processWinCountsMessage)
  messageListeners.ranked_match_approved = createListener(self, "ranked_match_approved", processRankedStatusMessage)
  messageListeners.ranked_match_denied = createListener(self, "ranked_match_denied", processRankedStatusMessage)
  messageListeners.leave_room = createListener(self, "leave_room", processLeaveRoomMessage)
  messageListeners.match_start = createListener(self, "match_start", processMatchStartMessage)
  messageListeners.taunt = createListener(self, "taunt", processTauntMessage)
  messageListeners.character_select = createListener(self, "character_select", processCharacterSelectMessage)
  messageListeners.spectators = createListener(self, "spectators", processSpectatorListMessage)

  return messageListeners
end

local NetClient = class(function(self)
  self.tcpClient = TcpClient()
  self.leaderboard = nil
  self.pendingResponses = {}
  self.state = states.OFFLINE

  resetLobbyData(self)

  local messageListeners = createListeners(self)

  -- all listeners running while online but not in a room/match
  self.lobbyListeners = {
    players = messageListeners.players,
    create_room = messageListeners.create_room,
    game_request = messageListeners.game_request,
  }

  -- all listeners running while in a room but not in a match
  self.roomListeners = {
    win_counts = messageListeners.win_counts,
    ranked_match_approved = messageListeners.ranked_match_approved,
    ranked_match_denied = messageListeners.ranked_match_denied,
    leave_room = messageListeners.leave_room,
    match_start = messageListeners.match_start,
    spectators = messageListeners.spectators,
    character_select = messageListeners.character_select
  }

  -- all listeners running while in a match
  self.matchListeners = {
    win_counts = messageListeners.win_counts,
    leave_room = messageListeners.leave_room,
    taunt = messageListeners.taunt,
    -- for spectators catching up to an ongoing match, a match_start acts as a cancel
    match_start = messageListeners.match_start,
    spectators = messageListeners.spectators,
    character_select = messageListeners.character_select
  }

  self.messageListeners = messageListeners

  self.room = nil

  Signal.turnIntoEmitter(self)
  self:createSignal("lobbyStateUpdate")
  self:createSignal("leaderboardUpdate")
  -- only fires for unintended disconnects
  self:createSignal("disconnect")
  self:createSignal("loginFinished")
end)

NetClient.STATES = states

function NetClient:leaveRoom()
  if self:isConnected() and self.room then
    self.tcpClient:dropOldInputMessages()
    self.tcpClient:sendRequest(ClientMessages.leaveRoom())

    if self.room:hasLocalPlayer() then
      -- the server sends us back the confirmation that we left the room
      -- so we reenter ONLINE state via processLeaveRoomMessage, not here
    else
      -- but as spectator there is no confirmation
      -- meaning state needs to be reset immediately
      self.room = nil
      self.state = states.ONLINE
    end
  end
end

function NetClient:reportLocalGameResult(winners)
  if #winners == 2 then
    -- we need to translate the result for the server to understand it
    -- two winners means a draw which the server thinks of as 0
    self.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(0))
  elseif #winners == 1 then
    self.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(winners[1].playerNumber))
  end
end

function NetClient:sendTauntUp(index)
  if self:isConnected() then
    self.tcpClient:sendRequest(ClientMessages.sendTaunt("up", index))
  end
end

function NetClient:sendTauntDown(index)
  if self:isConnected() then
    self.tcpClient:sendRequest(ClientMessages.sendTaunt("down", index))
  end
end

function NetClient:sendInput(input)
  if self:isConnected() then
    local message = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.clientMessageTypes.playerInput.prefix, input)
    self.tcpClient:send(message)
  end
end

function NetClient:requestLeaderboard()
  if not self.pendingResponses.leaderboardUpdate then
    self.pendingResponses.leaderboardUpdate = self.tcpClient:sendRequest(ClientMessages.requestLeaderboard())
  end
end

function NetClient:challengePlayer(name)
  if not self.lobbyData.sentRequests[name] then
    self.tcpClient:sendRequest(ClientMessages.challengePlayer(name))
    self.lobbyData.sentRequests[name] = true
    self:emitSignal("lobbyStateUpdate", self.lobbyData)
  end
end

function NetClient:requestSpectate(roomNumber)
  if not self.pendingResponses.spectateResponse then
    self.pendingResponses.spectateResponse = self.tcpClient:sendRequest(ClientMessages.requestSpectate(roomNumber))
  end
end

local function sendMenuState(player)
  GAME.netClient.tcpClient:sendRequest(ClientMessages.sendMenuState(ServerMessages.toServerMenuState(player)))
end

function NetClient:registerPlayerUpdates(room)
  local listener = MessageListener("menu_state")
  for _, player in ipairs(room.players) do
    if player.isLocal then
      -- seems a bit silly to subscribe a player to itself but it works and the player doesn't have to become part of the closure
      player:connectSignal("selectedCharacterIdChanged", player, sendMenuState)
      player:connectSignal("characterIdChanged", player, sendMenuState)
      player:connectSignal("selectedStageIdChanged", player, sendMenuState)
      player:connectSignal("stageIdChanged", player, sendMenuState)
      player:connectSignal("panelIdChanged", player, sendMenuState)
      player:connectSignal("wantsRankedChanged", player, sendMenuState)
      player:connectSignal("wantsReadyChanged", player, sendMenuState)
      player:connectSignal("difficultyChanged", player, sendMenuState)
      player:connectSignal("startingSpeedChanged", player, sendMenuState)
      player:connectSignal("levelChanged", player, sendMenuState)
      player:connectSignal("colorCountChanged", player, sendMenuState)
      player:connectSignal("inputMethodChanged", player, sendMenuState)
      player:connectSignal("hasLoadedChanged", player, sendMenuState)
    else
      listener:subscribe(player, processMenuStateMessage)
    end
  end
  self.messageListeners.menu_state = listener
  self.roomListeners.menu_state = listener
end

function NetClient:sendErrorReport(errorData, server, ip)
  if not self:isConnected() then
    self.tcpClient:connectToServer(server, ip)
  end
  self.tcpClient:sendRequest(ClientMessages.sendErrorReport(errorData))
  self.tcpClient:resetNetwork()
  self.state = states.OFFLINE
end

function NetClient:isConnected()
  return self.tcpClient:isConnected()
end

function NetClient:login(ip, port)
  if not self:isConnected() then
    self.loginRoutine = LoginRoutine(self.tcpClient, ip, port)
    self.state = states.LOGIN
  end
end

function NetClient:logout()
  self.tcpClient:sendRequest(ClientMessages.logout())
  self.tcpClient:resetNetwork()
  self.state = states.OFFLINE
  resetLobbyData(self)
end

function NetClient:update()
  if self.state == states.OFFLINE then
    return
  end

  if self.state == states.LOGIN then
    local done, result = self.loginRoutine:progress()
    if not done then
      self.loginState = result
    else
      if result.loggedIn then
        self.state = states.ONLINE
        self.loginState = result.message
        self.loginTime = love.timer.getTime()
      else
        self.loginState = result.message
        self.state = states.OFFLINE
        end
      self:emitSignal("loginFinished", result)
    end
  end

  if not self.tcpClient:processIncomingMessages() then
    self.state = states.OFFLINE
    self.room = nil
    self.tcpClient:resetNetwork()
    resetLobbyData(self)
    self:emitSignal("disconnect")
    return
  end

  if self.state == states.ONLINE then
    for _, listener in pairs(self.lobbyListeners) do
      listener:listen()
    end
    self.tcpClient:dropOldInputMessages()
    if self.pendingResponses.leaderboardUpdate then
      local status, value = self.pendingResponses.leaderboardUpdate:tryGetValue()
      if status == "timeout" then
        GAME.theme:playCancelSfx()
        self.pendingResponses.leaderboardUpdate = nil
      elseif status == "received" then
        self.leaderboard = value.leaderboard_report
        self:emitSignal("leaderboardUpdate", self.leaderboard)
        self.pendingResponses.leaderboardUpdate = nil
      end
    end
    if self.pendingResponses.spectateResponse then
      local status, value = self.pendingResponses.spectateResponse:tryGetValue()
      if status == "timeout" then
        GAME.theme:playCancelSfx()
        self.pendingResponses.spectateResponse = nil
      elseif status == "received" then
        self.pendingResponses.spectateResponse = nil
        spectate2pVsOnlineMatch(self, value)
      end
    end
  elseif self.state == states.ROOM then
    for _, listener in pairs(self.roomListeners) do
      listener:listen()
    end
  elseif self.state == states.INGAME then
    for _, listener in pairs(self.matchListeners) do
      listener:listen()
    end
    -- we could receive a leaveRoom message and the room could get axed while processing listeners
    -- so always need to check if the room is still there
    if self.room and self.room.match then
      processInputMessages(self)
    end
  end
end

return NetClient
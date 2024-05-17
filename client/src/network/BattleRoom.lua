local MessageListener = require("client.src.network.MessageListener")
local ServerMessages = require("client.src.network.ServerMessages")
local ClientMessages = require("client.src.network.ClientProtocol")
local tableUtils = require("common.lib.tableUtils")
local sceneManager = require("client.src.scenes.sceneManager")
local NetworkProtocol = require("common.network.NetworkProtocol")
local logger = require("common.lib.logger")

-- the entire network part of BattleRoom
-- this tries to hide away most of the "ugly" handling necessary for to the network communication

function BattleRoom:registerNetworkCallbacks()
  local menuStateListener = self:registerPlayerUpdates("menu_state")
  local winCountListener = self:createListener("win_counts", self.processWinCountsMessage)
  local rankedMatchListener1 = self:createListener("ranked_match_approved", self.processRankedStatusMessage)
  local rankedMatchListener2 = self:createListener("ranked_match_denied", self.processRankedStatusMessage)
  local leaveRoomListener = self:createListener("leave_room", self.processLeaveRoomMessage)
  local matchStartListener = self:createListener("match_start", self.processMatchStartMessage)
  local tauntListener = self:createListener("taunt", self.processTauntMessage)
  local characterSelectListener = self:createListener("character_select", self.processCharacterSelectMessage)
  local spectatorListListener = self:createListener("spectators", self.processSpectatorListMessage)

  self.setupListeners = {}

  self.setupListeners["menu_state"] = menuStateListener
  self.setupListeners["win_counts"] = winCountListener
  self.setupListeners["ranked_match_approved"] = rankedMatchListener1
  self.setupListeners["ranked_match_denied"] = rankedMatchListener2
  self.setupListeners["leave_room"] = leaveRoomListener
  self.setupListeners["match_start"] = matchStartListener
  self.setupListeners["taunt"] = tauntListener
  self.setupListeners["spectators"] = spectatorListListener
  self.setupListeners["character_select"] = characterSelectListener

  self.runningMatchListeners = {}

  self.runningMatchListeners["win_counts"] = winCountListener
  self.runningMatchListeners["leave_room"] = leaveRoomListener
  self.runningMatchListeners["taunt"] = tauntListener
  self.runningMatchListeners["match_start"] = matchStartListener
  self.runningMatchListeners["spectators"] = spectatorListListener
  self.runningMatchListeners["character_select"] = characterSelectListener

end

function BattleRoom:createListener(messageType, callback)
  local listener = MessageListener(messageType)
  listener:subscribe(self, callback)
  return listener
end

function BattleRoom:processSpectatorListMessage(message)
  self.spectators = message.spectators
  if self.match then
    self.match:setSpectatorList(self.spectators)
  end
end

function BattleRoom:processCharacterSelectMessage(message)
  -- receiving a character select message means that both players have reported their game results to the server
  -- that means from here on it is expected to receive no further input messages from either player
  -- if we went game over first, the opponent will notice later and keep sending inputs until we went game over on their end too
  -- these extra messages will remain unprocessed in the queue and need to be cleared up so they don't get applied the next match
  GAME.tcpClient:dropOldInputMessages()

  -- character_select and create_room are the same message
  -- except that character_select has an additional character_select = true flag
  message = ServerMessages.sanitizeCreateRoom(message)
  for i = 1, #message.players do
    for j = 1, #self.players do
      if message.players[i].playerNumber == self.players[j].playerNumber then
        if message.players[i].ratingInfo then
          self.players[j]:setRating(message.players[i].ratingInfo.new)
          self.players[j]:setLeague(message.players[i].ratingInfo.league)
        end
        if not self.players[j].isLocal then
          self.players[j]:updateWithMenuState(message.players[i])
        end
      end
    end
  end

  self:updateExpectedWinrates()
end

function BattleRoom:processLeaveRoomMessage(message)
  if self.match then
    -- we're ending the game from battleRoom side via an abort so we don't want to enter the standard onMatchEnd callback
    self.match:disconnectSignal("matchEnded", self)
    -- instead we actively abort the match ourselves
    self.match:abort()
    self.match:deinit()
  end
  -- and then shutdown the room
  self.match = nil
  self:shutdown()
  sceneManager:switchToScene(sceneManager:createScene("Lobby"))
end

function BattleRoom:processTauntMessage(message)
  local characterId = tableUtils.first(self.players, function(player)
    return player.playerNumber == message.player_number
  end).settings.characterId
  characters[characterId]:playTaunt(message.type, message.index)
end

function BattleRoom:processMatchStartMessage(message)
  message = ServerMessages.sanitizeStartMatch(message)

  for i = 1, #message.playerSettings do
    local playerSettings = message.playerSettings[i]
    -- contains level, characterId, panelId
    for j = 1, #self.players do
      local player = self.players[j]
      if playerSettings.playerNumber == player.playerNumber then
        -- verify that settings on server and local match to prevent desync / crash
        if playerSettings.level ~= player.settings.level then
          player:setLevel(playerSettings.level)
        end
        -- generally I don't think it's a good idea to try and rematch the other diverging settings here
        -- everyone is loaded and ready which can only happen after character/panel data was already exchanged
        -- if they diverge it's because the chosen mod is missing on the other client
        -- generally I think server should only send physics relevant data with match_start
        -- if playerSettings.characterId ~= player.settings.characterId then
        -- end
        -- if playerSettings.panelId ~= player.settings.panelId then
        -- end
      end
    end
  end

  if self.state == BattleRoom.states.MatchInProgress then
    -- if there is a match in progress when receiving a match start that means we are in the process of catching up via transition
    -- deinit and nil to cancel the catchup
    self.match:deinit()
    self.match = nil

    -- although the most important thing is replacing the on-going transition but startMatch already does that as a default
  end

  self:startMatch(message.stageId, message.seed)
end

function BattleRoom:processWinCountsMessage(message)
  self:setWinCounts(message.win_counts)
end

function BattleRoom:registerWinCountUpdates(messageType)
  local listener = MessageListener(messageType)
  listener:subscribe(self, self.processWinCountsMessage)
  return listener
end

function BattleRoom:processRankedStatusMessage(message)
  local rankedStatus = message.ranked_match_approved or false
  local comments = ""
  if message.reasons then
    comments = comments .. table.concat(message.reasons, "\n")
  end
  if message.caveats then
    comments = comments .. table.concat(message.caveats, "\n")
  end
  self:updateRankedStatus(rankedStatus, comments)
end

function BattleRoom:registerPlayerUpdates(messageType)
  local listener = MessageListener(messageType)
  for _, player in ipairs(self.players) do
    if player.isLocal then
      -- we want to send updates for every change in settings
      -- at a later point we might care about the value but at the moment, just send everything
      local update = function(player, value)
        GAME.tcpClient:sendRequest(ClientMessages.sendMenuState(ServerMessages.toServerMenuState(player)))
      end
      -- seems a bit silly to subscribe a player to itself but it works and the player doesn't have to become part of the closure
      player:connectSignal("selectedCharacterIdChanged", player, update)
      player:connectSignal("characterIdChanged", player, update)
      player:connectSignal("selectedStageIdChanged", player, update)
      player:connectSignal("stageIdChanged", player, update)
      player:connectSignal("panelIdChanged", player, update)
      player:connectSignal("wantsRankedChanged", player, update)
      player:connectSignal("wantsReadyChanged", player, update)
      player:connectSignal("difficultyChanged", player, update)
      player:connectSignal("startingSpeedChanged", player, update)
      player:connectSignal("levelChanged", player, update)
      player:connectSignal("colorCountChanged", player, update)
      player:connectSignal("inputMethodChanged", player, update)
      player:connectSignal("hasLoadedChanged", player, update)
    else
      local update = function(player, menuStateMsg)
        local menuState = ServerMessages.sanitizeMenuState(menuStateMsg.menu_state)
        if menuStateMsg.player_number then
          -- only update if playernumber matches the player's
          if menuStateMsg.player_number == player.playerNumber then
            player:updateWithMenuState(menuState)
          else
            -- this update is for someone else
          end
        else
          player:updateWithMenuState(menuState)
        end
      end
      listener:subscribe(player, update)
    end
  end

  return listener
end

function BattleRoom:runNetworkTasks()
  if self.state == BattleRoom.states.MatchInProgress then
    -- the game phase of the room
    -- BattleRoom handles all network updates for online games!!!
    -- that means fetching input messages, spectator updates etc.
    for messageType, listener in pairs(self.runningMatchListeners) do
      listener:listen()
    end

    -- Receive game play inputs from the network
    self:processInputMessages()
  elseif self.state == BattleRoom.states.Setup then
    for messageType, listener in pairs(self.setupListeners) do
      listener:listen()
    end
  end
end

function BattleRoom:reportLocalGameResult(winners)
  if #winners == 2 then
    -- we need to translate the result for the server to understand it
    -- two winners means a draw which the server thinks of as 0
    GAME.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(0))
  elseif #winners == 1 then
    GAME.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(winners[1].playerNumber))
  end
end

function BattleRoom:shutdownNetwork()
  if GAME.tcpClient then
    GAME.tcpClient:dropOldInputMessages()
    if self.online and GAME.tcpClient:isConnected() then
      GAME.tcpClient:sendRequest(ClientMessages.leaveRoom())
    end
  end

  self.setupListeners = nil
  self.runningMatchListeners = nil
end

function BattleRoom:processInputMessages()
  local messages = GAME.tcpClient.receivedMessageQueue:pop_all_with(NetworkProtocol.serverMessageTypes.opponentInput.prefix, NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix)
  for _, msg in ipairs(messages) do
    for type, data in pairs(msg) do
      logger.trace("Processing: " .. type .. " with data:" .. data)
      if type == NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix then
        self.match.P1:receiveConfirmedInput(data)
      elseif type == NetworkProtocol.serverMessageTypes.opponentInput.prefix then
        self.match.P2:receiveConfirmedInput(data)
      end
    end
  end
end

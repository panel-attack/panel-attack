require("BattleRoom")
local MessageListener = require("network.MessageListener")
local ServerMessages = require("network.ServerMessages")
local ClientMessages = require("network.ClientProtocol")
local tableUtils = require("tableUtils")
local sceneManager = require("scenes.sceneManager")
-- the entire network part of BattleRoom
-- this tries to hide away most of the "ugly" handling necessary for to the network communication

function BattleRoom:registerNetworkCallbacks()
  local menuStateListener = self:registerPlayerUpdates("menu_state")
  local winCountListener = self:registerWinCountUpdates("win_counts")
  local rankedMatchListener1 = self:registerRankedStatusUpdates("ranked_match_approved")
  local rankedMatchListener2 = self:registerRankedStatusUpdates("ranked_match_denied")
  local leaveRoomListener = self:registerLeaveRoom("leave_room")
  local matchStartListener = self:registerStartMatch("match_start")
  local tauntListener = self:registerTaunts("taunt")
  local characterSelectListener = self:registerCharacterSelect("character_select")

  self.selectionListeners = {}

  self.selectionListeners["menu_state"] = menuStateListener
  self.selectionListeners["win_counts"] = winCountListener
  self.selectionListeners["ranked_match_approved"] = rankedMatchListener1
  self.selectionListeners["ranked_match_denied"] = rankedMatchListener2
  self.selectionListeners["leave_room"] = leaveRoomListener
  self.selectionListeners["match_start"] = matchStartListener
  self.selectionListeners["taunt"] = tauntListener

  self.ingameListeners = {}

  self.selectionListeners["win_counts"] = winCountListener
  self.selectionListeners["leave_room"] = leaveRoomListener
  self.selectionListeners["taunt"] = tauntListener
  self.selectionListeners["character_select"] = characterSelectListener
end

function BattleRoom:registerCharacterSelect(messageType)
  local listener = MessageListener(messageType)
  local update = function(battleRoom, message)
    -- character_select and create_room are the same message
    -- except that character_select has an additional character_select = true flag
    message = ServerMessages.sanitizeCreateRoom(message)
    for i = 1, #message.players do
      for j = 1, #battleRoom.players do
        if message.players[i].playerNumber == battleRoom.players[j].playerNumber then
          battleRoom.players[j]:updateWithMenuState(message.players[i])
          if message.players[i].ratingInfo then
            battleRoom.players[j].rating = message.players[i].ratingInfo
          end
        end
      end
    end
    sceneManager:switchToScene("CharacterSelectOnline", {battleRoom = battleRoom})
  end
  listener:subscribe(self, update)
  return listener
end

function BattleRoom:registerLeaveRoom(messageType)
  local listener = MessageListener(messageType)
  local update = function(battleRoom, message)
    if battleRoom.match then
      --Replay.finalizeAndWriteVsReplay(0, true, battleRoom.match, battleRoom.match.replay)
    end

    -- stable calculates the desync here and displays it
    -- need to figure out where to do that sensibly here
    -- also need to make a call to properly abort the game and close the battleRoom before recovering to lobby
    battleRoom.match = nil
    battleRoom:shutdown()
    sceneManager:switchToScene("Lobby")
  end
  listener:subscribe(self, update)
  return listener
end

-- by registering this one as a general handler, we can now taunt in character select too
function BattleRoom:registerTaunts(messageType)
  local listener = MessageListener(messageType)
  local update = function(battleRoom, message)
    local characterId = tableUtils.first(battleRoom.players, function(player)
      return player.playerNumber == message.player_number
    end)
    characters[characterId]:playTaunt(message.type, message.index)
  end
  listener:subscribe(self, update)
  return listener
end

function BattleRoom:registerStartMatch(messageType)
  local listener = MessageListener(messageType)

  local update = function(battleRoom, message)
    message = ServerMessages.sanitizeStartMatch(message)
    for i = 1, #message.playerSettings do
      local playerSettings = message.playerSettings[i]
      -- contains level, characterId, panelId
      for j = 1, #battleRoom.players do
        local player = battleRoom.players[j]
        if playerSettings.playerNumber == player.playerNumber then
          -- verify that settings on server and local match to prevent desync / crash
          if playerSettings.level ~= player.settings.level then
            player:setLevel(playerSettings.level)
          end
          -- generally I don't think it's a good idea to try and rematch the other diverging settings here
          -- everyone is loaded and ready which can only happen after character/panel data was already exchanged
          -- if they diverge then because the mod is missing on the other side
          -- generally I think server should only send physics relevant data with match_start
          -- if playerSettings.characterId ~= player.settings.characterId then
          -- end
          -- if playerSettings.panelId ~= player.settings.panelId then
          -- end
        end
      end
    end
    battleRoom:startMatch(message.stageId, message.seed)
  end
  listener:subscribe(self, update)
  return listener
end

function BattleRoom:registerWinCountUpdates(messageType)
  local listener = MessageListener(messageType)
  local function update(battleRoom, winCountMessage)
    battleRoom:setWinCounts(winCountMessage.win_counts)
  end
  listener:subscribe(self, update)
  return listener
end

function BattleRoom:registerRankedStatusUpdates(messageType)
  local listener = MessageListener(messageType)
  local update = function(battleRoom, message)
    local rankedStatus = message.ranked_match_approved or false
    local comments = ""
    if message.reasons then
      comments = comments .. table.concat(message.reasons, "\n")
    end
    if message.caveats then
      comments = comments .. table.concat(message.caveats, "\n")
    end
    battleRoom:updateRankedStatus(rankedStatus, comments)
  end

  listener:subscribe(self, update)
  return listener
end

function BattleRoom:registerPlayerUpdates(messageType)
  local listener = MessageListener(messageType)
  for i = 1, #self.players do
    local player = self.players[i]
    if player.isLocal then
      -- we want to send updates for every change in settings
      -- at a later point we might care about the value but at the moment, just send everything
      local update = function(player, value)
        GAME.tcpClient:sendRequest(ClientMessages.sendMenuState(ServerMessages.toServerMenuState(player)))
      end
      -- seems a bit silly to subscribe a player to itself but it works and the player doesn't have to become part of the closure
      player:subscribe(player, "characterId", update)
      player:subscribe(player, "stageId", update)
      player:subscribe(player, "panelId", update)
      player:subscribe(player, "wantsRanked", update)
      player:subscribe(player, "wantsReady", update)
      player:subscribe(player, "hasLoaded", update)
      player:subscribe(player, "difficulty", update)
      player:subscribe(player, "speed", update)
      player:subscribe(player, "level", update)
      player:subscribe(player, "colorCount", update)
      player:subscribe(player, "inputMethod", update)
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
  if self.match then
    -- the game phase of the room
    -- BattleRoom handles all network updates for online games!!!
    -- that means fetching input messages, spectator updates etc.
    for messageType, listener in pairs(self.ingameListeners) do
      listener:listen()
    end

    process_all_data_messages() -- Receive game play inputs from the network

    local outcome = self.match:getOutcome()
    if outcome then
      -- we need to report the outcome to the server, otherwise the game won't end and we won't get a character selection message
      -- this is probably flooding the server with messages every frame now
      if tableUtils.trueForAny(self.match.players, function(p) return p.isLocal end) then
        GAME.tcpClient:sendRequest(ClientMessages.reportLocalGameResult(outcome.outcome_claim))
      end
      sceneManager:switchToScene("CharacterSelectOnline")
    end
  else
    for messageType, listener in pairs(self.selectionListeners) do
      listener:listen()
    end
  end
end

function BattleRoom:shutdownNetwork()
  GAME.tcpClient.receivedMessageQueue:clear()
  if self.online and GAME.tcpClient:isConnected() then
    GAME.tcpClient:sendRequest(ClientMessages.leaveRoom())
  end
  self.selectionListeners = nil
  self.ingameListeners = nil
end

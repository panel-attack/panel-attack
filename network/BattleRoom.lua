require("BattleRoom")
local MessageListener = require("network.MessageListener")
local ServerMessages = require("network.ServerMessages")
local ClientMessages = require("network.ClientProtocol")
-- the entire network part of BattleRoom
-- this tries to hide away most of the "ugly" handling necessary for to the network communication

function BattleRoom:setupSettingsListeners()
  self.listeners = {}
  local menuStateListener = MessageListener("menu_state")
  self.listeners["menu_state"] = menuStateListener
  -- "win_counts", "menu_state", "ranked_match_approved", "leave_room", "match_start", "ranked_match_denied"
  local winCountListener = MessageListener("win_counts")
  self.listeners["win_counts"] = winCountListener
  local rankedMatchListener1 = MessageListener("ranked_match_approved")
  self.listeners["ranked_match_approved"] = rankedMatchListener1
  local rankedMatchListener2 = MessageListener("ranked_match_denied")
  self.listeners["ranked_match_denied"] = rankedMatchListener2
  local leaveRoomListener = MessageListener("leave_room")
  self.listeners["leave_room"] = leaveRoomListener
  local matchStartListener = MessageListener("match_start")
  self.listeners["match_start"] = matchStartListener
end

function BattleRoom:registerCallbacks()
  self:registerPlayerUpdates()
  self:registerWinCountUpdates()
  self:registerRankedStatusUpdates()
  self:registerStartMatch()
end

function BattleRoom:registerStartMatch()
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
    battleRoom:startMatch()
  end
  self.listeners["match_start"]:subscribe(self, update)
end

function BattleRoom:registerWinCountUpdates()
  local function update(battleRoom, winCountMessage)
    battleRoom:setWinCounts(winCountMessage.win_counts)
  end
  self.listeners["win_counts"]:subscribe(self, update)
end

function BattleRoom:registerRankedStatusUpdates()
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

  self.listeners["ranked_match_approved"]:subscribe(self, update)
  self.listeners["ranked_match_denied"]:subscribe(self, update)
end

function BattleRoom:registerPlayerUpdates()
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
      self.listeners["menu_state"]:subscribe(player, update)
    end
  end
end

function BattleRoom:runNetworkTasks()
  for messageType, listener in pairs(self.listeners) do
    listener:listen()
  end
end

function BattleRoom:shutdownOnline()
  for i = 1, #self.players do
    self.players[i]:unsubscribe(self.players[i])
  end
  self.listeners = nil
end
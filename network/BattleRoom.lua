require("BattleRoom")
local MessageListener = require("network.MessageListener")
local ServerMessages = require("network.ServerMessages")
local ClientMessages = require("network.ClientProtocol")
-- the entire network part of BattleRoom

function BattleRoom:setupSettingsListeners()
  self.listeners = {}
  local menuStateListener = MessageListener("menu_state")
  self.listeners["menu_state"] = menuStateListener
end

function BattleRoom:registerCallbacks()
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
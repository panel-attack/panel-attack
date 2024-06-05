local Scene = require("client.src.scenes.Scene")
local Label = require("client.src.ui.Label")
local Menu = require("client.src.ui.Menu")
local MenuItem = require("client.src.ui.MenuItem")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local util = require("common.lib.util")
local NetClient = require("client.src.network.NetClient")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local Leaderboard = require("client.src.ui.Leaderboard")

-- @module Lobby
-- expects a serverIp and serverPort as a param (unless already set in GAME.connected_server_ip & GAME.connected_server_port respectively)
local Lobby = class(function(self, sceneParams)
  self.music = "main"

  -- lobby data from the server
  self.playerData = nil
  self.unpairedPlayers = {} -- list
  self.willingPlayers = {} -- set
  self.spectatableRooms = {}
  -- requests to play a match, not web requests
  self.sentRequests = {}

  -- ui
  self.leaderboard = Leaderboard({isVisible = false, x = 200, hAlign = "center", vAlign = "center"})
  self.backgroundImg = themes[config.theme].images.bg_main
  self.lobbyMenu = nil
  self.lobbyMenuXoffsetMap = {
    [true] = -200,
    [false] = 0
  }
  -- will be used to make room in case the leaderboard should be shown.
  -- currently unused, need to find a new place to draw this later
  self.notice = {[true] = loc("lb_select_player"), [false] = loc("lb_alone")}

  self:load(sceneParams)
end, Scene)

Lobby.name = "Lobby"

----------
-- exit --
----------

local function exitMenu()
  GAME.theme:playCancelSfx()
  GAME.netClient:logout()
  GAME.navigationStack:pop()
end

-------------
-- startup --
-------------

function Lobby:load(sceneParams)
  if not GAME.netClient:isConnected() and sceneParams.serverIp then
    GAME.netClient:login(sceneParams.serverIp, sceneParams.serverPort)
  end

  GAME.netClient:connectSignal("lobbyStateUpdate", self, self.onLobbyStateUpdate)
  GAME.netClient:connectSignal("disconnect", self, self.onDisconnect)
  GAME.netClient:connectSignal("leaderboardUpdate", self.leaderboard, self.leaderboard.updateData)
  GAME.netClient:connectSignal("loginFailed", self, self.onLoginFailure)

  self:initLobbyMenu()
  self.uiRoot:addChild(self.leaderboard)
end

function Lobby:initLobbyMenu()
  local menuItems = {
    MenuItem.createButtonMenuItem("lb_show_board", nil, nil, function()
      self:toggleLeaderboard()
    end),
    MenuItem.createButtonMenuItem("lb_back", nil, nil, exitMenu)
  }
  self.leaderboardToggleLabel = menuItems[1].textButton.children[1]

  self.lobbyMenuStartingUp = true
  self.lobbyMenu = Menu.createCenteredMenu(menuItems)
  self.lobbyMenu.x = self.lobbyMenuXoffsetMap[false]

  self.uiRoot:addChild(self.lobbyMenu)
end

-----------------
-- leaderboard --
-----------------

function Lobby:toggleLeaderboard()
  GAME.theme:playMoveSfx()
  if not self.leaderboard.isVisible then
    self.leaderboardToggleLabel:setText("lb_hide_board")
    GAME.netClient:requestLeaderboard()
    self.lobbyMenu:setFocus(self.leaderboard, function() self:toggleLeaderboard() end)
  else
    self.leaderboardToggleLabel:setText("lb_show_board")
  end
  self.leaderboard:setVisibility(not self.leaderboard.isVisible)
  self.lobbyMenu.x = self.lobbyMenuXoffsetMap[self.leaderboard.isVisible]
end

--------------------------------
-- Processing server messages --
--------------------------------

function Lobby:playerRatingString(playerName)
  local rating = ""
  local playerData = GAME.netClient.lobbyData.players[playerName]
  if playerData and playerData.rating then
    rating = " (" .. playerData.rating .. ")"
  end
  return rating
end

-- challenges the opponent with that name
function Lobby:requestGameFunction(opponentName)
  return function()
    GAME.netClient:challengePlayer(opponentName)
    GAME.theme:playValidationSfx()
  end
end

-- requests to spectate the specified room
function Lobby:requestSpectateFunction(room)
  return function()
    GAME.netClient:requestSpectate(room.roomNumber)
    GAME.theme:playValidationSfx()
  end
end

-- rebuilds the UI based on the new lobby information
function Lobby:onLobbyStateUpdate(lobbyState)
  local previousText = self.lobbyMenu.menuItems[self.lobbyMenu.selectedIndex].textButton.children[1].text
  local desiredIndex = self.lobbyMenu.selectedIndex

  -- cleanup previous lobby menu
  while #self.lobbyMenu.menuItems > 2 do
    self.lobbyMenu:removeMenuItemAtIndex(1)
  end
  self.lobbyMenu:setSelectedIndex(1)

  for _, v in ipairs(lobbyState.unpairedPlayers) do
    if v ~= config.name then
      local unmatchedPlayer = v .. self:playerRatingString(v)
      if lobbyState.sentRequests[v] then
        unmatchedPlayer = unmatchedPlayer .. " " .. loc("lb_request")
      end
      if lobbyState.willingPlayers[v] then
        unmatchedPlayer = unmatchedPlayer .. " " .. loc("lb_received")
      end
      self.lobbyMenu:addMenuItem(1, MenuItem.createButtonMenuItem(unmatchedPlayer, nil, false, self:requestGameFunction(v)))
    end
  end
  for _, room in ipairs(lobbyState.spectatableRooms) do
    if room.name then
      local playerA = room.a .. self:playerRatingString(room.a)
      local playerB = room.b .. self:playerRatingString(room.b)
      local roomName = loc("lb_spectate") .. " " .. playerA .. " vs " .. playerB .. " (" .. room.state .. ")"
      self.lobbyMenu:addMenuItem(1, MenuItem.createButtonMenuItem(roomName, nil, false, self:requestSpectateFunction(room)))
    end
  end

  if self.lobbyMenuStartingUp then
    self.lobbyMenu:setSelectedIndex(1)
    self.lobbyMenuStartingUp = false
  else
    for i = 1, #self.lobbyMenu.menuItems do
      if self.lobbyMenu.menuItems[i].textButton.children[1].text == previousText then
        desiredIndex = i
        break
      end
    end
    self.lobbyMenu:setSelectedIndex(util.bound(1, desiredIndex, #self.lobbyMenu.menuItems))
  end
end

------------------------------
-- scene core functionality --
------------------------------
local loginStateLabel = Label({text = loc("lb_login"), translate = false, x = 500, y = 350})
function Lobby:update(dt)
  self.backgroundImg:update(dt)

  if GAME.netClient.state == NetClient.STATES.LOGIN then
    loginStateLabel:setText(GAME.netClient.loginState or "")
  else
    self.lobbyMenu:receiveInputs()
  end
end

function Lobby:draw()
  self.backgroundImg:draw()
  self:drawCommunityMessage()
  if GAME.netClient.state == NetClient.STATES.LOGIN then
    loginStateLabel:draw()
  else
    self.uiRoot:draw()
  end
end

function Lobby:onDisconnect()
  if not GAME.navigationStack.transition then
    -- automatic reconnect if we're not about to switch scene
    GAME.netClient:login(GAME.connected_server_ip, GAME.connected_server_port)
  end
end

function Lobby:onLoginFailure(message)
  local messageTransition = MessageTransition(love.timer.getTime(), 5, message)
  GAME.navigationStack:pop(messageTransition)
end

return Lobby

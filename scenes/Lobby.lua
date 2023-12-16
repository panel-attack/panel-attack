local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Label = require("ui.Label")
local ButtonGroup = require("ui.ButtonGroup")
local TextButton = require("ui.TextButton")
local Menu = require("ui.Menu")
local class = require("class")
local input = require("inputManager")
local logger = require("logger")
local LoginRoutine = require("network.LoginRoutine")
local MessageListener = require("network.MessageListener")
local ClientMessages = require("network.ClientProtocol")
local UiElement = require("ui.UIElement")

local STATES = {Login = 1, Lobby = 2}

-- @module Lobby
-- expects a serverIp and serverPort as a param (unless already set in GAME.connected_server_ip & GAME.connected_server_port respectively)
local Lobby = class(function(self, sceneParams)
  -- lobby data from the server
  self.playerData = nil
  self.unpairedPlayers = {} -- list
  self.willingPlayers = {} -- set
  self.spectatableRooms = {}
  -- requests to play a match, not web requests
  self.sentRequests = {}

  -- leaderboard data
  self.myRank = nil
  self.leaderboardString = ""
  self.leaderboardResponse = nil

  -- ui
  self.backgroundImg = themes[config.theme].images.bg_main
  self.leaderboardLabel = nil
  self.lobbyMenu = nil
  self.lobbyMenuXoffsetMap = {
    [true] = -200,
    [false] = 0
  }
  -- will be used to make room in case the leaderboard should be shown.
  -- currently unused, need to find a new place to draw this later
  self.notice = {[true] = loc("lb_select_player"), [false] = loc("lb_alone")}

  -- state fields to manage Lobby's update cycle    
  self.state = STATES.Login

  -- network features not yet implemented
  self.spectateRequestResponse = nil
  self.requestedSpectateRoom = nil

  self:load(sceneParams)
end, Scene)

Lobby.name = "Lobby"
sceneManager:addScene(Lobby)

----------
-- exit --
----------

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  GAME.tcpClient:resetNetwork()
  sceneManager:switchToScene("MainMenu")
end

function Lobby:unload()
  self.lobbyMenu:setVisibility(false)
end

-------------
-- startup --
-------------

function Lobby:load(sceneParams)
  if not GAME.tcpClient:isConnected() then
    self.loginRoutine = LoginRoutine(GAME.tcpClient, sceneParams.serverIp, sceneParams.serverPort)
  else
    self.state = STATES.Lobby
  end
  self.messageListeners = {}
  self.messageListeners["create_room"] = MessageListener("create_room")
  self.messageListeners["create_room"]:subscribe(self, self.start2pVsOnlineMatch)
  self.messageListeners["players"] = MessageListener("players")
  self.messageListeners["players"]:subscribe(self, self.updateLobbyState)
  self.messageListeners["game_request"] = MessageListener("game_request")
  self.messageListeners["game_request"]:subscribe(self, self.processGameRequest)

  if next(currently_playing_tracks) == nil then
    stop_the_music()
    if themes[config.theme].musics["main"] then
      find_and_add_music(themes[config.theme].musics, "main")
    end
  end
  reset_filters()

  self:initLobbyMenu()
end

function Lobby:initLobbyMenu()
  self.lobbyScreen = UiElement({x = 0, y = 0, width = canvas_width, height = canvas_height})

  self.leaderboardLabel = Label({text = "", translate = false, hAlign = "center", vAlign = "center", x = 200, isVisible = false})
  self.leaderboardToggleLabel = Label({text = "lb_show_board"})
  self.leaderboardToggleButton = TextButton({
    label = self.leaderboardToggleLabel,
    onClick = function()
      self:toggleLeaderboard()
    end
  })
  local menuItems = {{self.leaderboardToggleButton}, {TextButton({label = Label({text = "lb_back"}), onClick = exitMenu})}}

  self.lobbyMenu = Menu({
    x = self.lobbyMenuXoffsetMap[false],
    y = 0,
    menuItems = menuItems,
    -- this alignment setup does not quite work yet because Menu isn't acting like a proper container
    hAlign = "center",
    vAlign = "center",
  })
  self.lobbyScreen:addChild(self.lobbyMenu)
  self.lobbyScreen:addChild(self.leaderboardLabel)
end

-----------------
-- leaderboard --
-----------------

function Lobby:toggleLeaderboard()
  Menu.playMoveSfx()
  if not self.leaderboardLabel.isVisible then
    self.leaderboardToggleLabel:setText("lb_hide_board")
    self.leaderboardResponse = GAME.tcpClient:sendRequest(ClientMessages.requestLeaderboard())
    self.leaderboardLabel:setVisibility(true)
  else
    self.leaderboardToggleLabel:setText("lb_show_board")
  end
  self.leaderboardLabel:setVisibility(not self.leaderboardLabel.isVisible)
  self.lobbyMenu.x = self.lobbyMenuXoffsetMap[self.leaderboardLabel.isVisible]
end

local function build_viewable_leaderboard_string(report, firstVisibleIndex, lastVisibleIndex)
  str = loc("lb_header_board") .. "\n"
  firstVisibleIndex = math.max(firstVisibleIndex, 1)
  lastVisibleIndex = math.min(lastVisibleIndex, #report)

  for i = firstVisibleIndex, lastVisibleIndex do
    ratingSpacing = "     " .. string.rep("  ", (3 - string.len(i)))
    nameSpacing = "     " .. string.rep("  ", (4 - string.len(report[i].rating)))
    if report[i].is_you then
      str = str .. loc("lb_you") .. "-> "
    else
      str = str .. "      "
    end
    str = str .. i .. ratingSpacing .. report[i].rating .. nameSpacing .. report[i].user_name
    if i < #report then
      str = str .. "\n"
    end
  end
  return str
end

function Lobby:updateLeaderboard(leaderboardReportMessage)
  if leaderboardReportMessage.leaderboard_report then
    local leaderboardReport = leaderboardReportMessage.leaderboard_report
    for rank = #leaderboardReport, 1, -1 do
      local user = leaderboardReport[rank]
      if user.user_name == config.name then
        self.myRank = rank
      end
    end
    local firstVisibleIndex = math.max((self.myRank or 1) - 8, 1)
    local lastVisibleIndex = math.min(firstVisibleIndex + 20, #leaderboardReport)
    self.leaderboardString = build_viewable_leaderboard_string(leaderboardReport, firstVisibleIndex, lastVisibleIndex)
    self.leaderboardLabel:setText(self.leaderboardString)
  end
end

--------------------------------
-- Processing server messages --
--------------------------------

function Lobby:processGameRequest(gameRequestMessage)
  if gameRequestMessage.game_request then
    self.willingPlayers[gameRequestMessage.game_request.sender] = true
    love.window.requestAttention()
    play_optional_sfx(themes[config.theme].sounds.notification)
    -- this might be moot if the server sends a lobby update to everyone after receiving the challenge
    self:onLobbyStateUpdate()
  end
end

-- populates playerData, willingPlayers, sentRequests and unpairedPlayers from the server messages
function Lobby:updateLobbyState(lobbyStateMessage)
  if lobbyStateMessage.players then
    self.playerData = lobbyStateMessage.players
  end
  if lobbyStateMessage.unpaired then
    self.unpairedPlayers = lobbyStateMessage.unpaired
    -- players who leave the unpaired list no longer have standing invitations to us.\
    -- we also no longer have a standing invitation to them, so we'll remove them from sentRequests
    local newWillingPlayers = {}
    local newSentRequests = {}
    for _, player in ipairs(self.unpairedPlayers) do
      newWillingPlayers[player] = self.willingPlayers[player]
      newSentRequests[player] = self.sentRequests[player]
    end
    self.willingPlayers = newWillingPlayers
    self.sentRequests = newSentRequests
    if lobbyStateMessage.spectatable then
      self.spectatableRooms = lobbyStateMessage.spectatable
    end
  end
  self:onLobbyStateUpdate()
end

-- starts a 2p vs online match
function Lobby:start2pVsOnlineMatch(createRoomMessage)
  -- Not yet implemented
  GAME.battleRoom = BattleRoom.createFromServerMessage(createRoomMessage)
  love.window.requestAttention()
  play_optional_sfx(themes[config.theme].sounds.notification)
  sceneManager:switchToScene("CharacterSelectOnline", {battleRoom = GAME.battleRoom})
end

-- starts to spectate a 2p vs online match
function Lobby:spectate2pVsOnlineMatch(spectateRequestGrantedMessage)
  -- Not yet implemented
  local battleRoom = BattleRoom.createFromServerMessage(spectateRequestGrantedMessage)
  sceneManager:switchToScene("CharacterSelectOnline", {battleRoom = GAME.battleRoom})
end

function Lobby:playerRatingString(playerName)
  local rating = ""
  if self.playerData and self.playerData[playerName] and self.playerData[playerName].rating then
    rating = " (" .. self.playerData[playerName].rating .. ")"
  end
  return rating
end

-- challenges the opponent with that name
function Lobby:requestGameFunction(opponentName)
  return function()
    self.sentRequests[opponentName] = true
    GAME.tcpClient:sendRequest(ClientMessages.challengePlayer(opponentName))
    self:onLobbyStateUpdate()
  end
end

-- requests to spectate the specified room
function Lobby:requestSpectateFunction(room)
  return function()
    self.requestedSpectateRoom = room
    self.spectateRequestResponse = GAME.tcpClient:sendRequest(ClientMessages.requestSpectate(room.roomNumber))
  end
end

-- rebuilds the UI based on the new lobby information
function Lobby:onLobbyStateUpdate()
  while #self.lobbyMenu.menuItems > 2 do
    self.lobbyMenu:removeMenuItemAtIndex(1)
  end
  for _, v in ipairs(self.unpairedPlayers) do
    if v ~= config.name then
      local unmatchedPlayer = v .. self:playerRatingString(v)
      if self.sentRequests[v] then
        unmatchedPlayer = unmatchedPlayer .. " " .. loc("lb_request")
      end
      if self.willingPlayers[v] then
        unmatchedPlayer = unmatchedPlayer .. " " .. loc("lb_received")
      end
      self.lobbyMenu:addMenuItem(1, {
        TextButton({label = Label({text = unmatchedPlayer, translate = false}), onClick = self:requestGameFunction(v)})
      })
    end
  end
  for _, room in ipairs(self.spectatableRooms) do
    if room.name then
      local playerA = room.a .. self:playerRatingString(room.a)
      local playerB = room.b .. self:playerRatingString(room.b)
      local roomName = loc("lb_spectate") .. " " .. playerA .. " vs " .. playerB .. " (" .. room.state .. ")"
      self.lobbyMenu:addMenuItem(1, {
        TextButton({label = Label({text = roomName, translate = false}), onClick = self:requestSpectateFunction(room)})
      })
    end
  end
end

----------------------
-- network handling --
----------------------

local loginStateLabel = Label({text = loc("lb_login"), translate = false, x = 500, y = 350})
function Lobby:handleLogin()
  local done, result = self.loginRoutine:progress()
  if not done then
    loginStateLabel:setText(result)
  else
    if result.loggedIn then
      self.state = STATES.Lobby
    else
      loginStateLabel:setText(result.message)
      if not self.loginScreenTimer then
        self.loginScreenTimer = GAME.timer + 5
      end
      if GAME.timer > self.loginScreenTimer then
        self.loginScreenTimer = nil
        sceneManager:switchToScene("MainMenu")
      end
    end
  end
end

function Lobby:processServerMessages()
  for _, listener in pairs(self.messageListeners) do
    listener:listen()
  end

  if self.leaderboardResponse then
    local status, value = self.leaderboardResponse:tryGetValue()
    if status == "timeout" then
      self.leaderboardResponse = GAME.tcpClient:sendRequest(ClientMessages.requestLeaderboard())
    elseif status == "received" then
      self:updateLeaderboard(value)
    end
  end

  if self.spectateRequestResponse then
    local status, value = self.spectateRequestResponse:tryGetValue()
    if status == "timeout" then
      self.spectateRequestResponse = GAME.tcpClient:sendRequest(ClientMessages.requestSpectate(self.requestedSpectateRoom.roomNumber))
    elseif status == "received" then
      -- Not Yet Implemented
      self:spectate2pVsOnlineMatch(value)
    end
  end
end

------------------------------
-- scene core functionality --
------------------------------

function Lobby:update(dt)
  self.backgroundImg:update(dt)

  if self.state == STATES.Login then
    self:handleLogin()
  else
    -- We are in the lobby, we shouldn't have any game data messages
    drop_old_data_messages()

    self:processServerMessages()
    self.lobbyMenu:update()
  end

  if not GAME.tcpClient:processIncomingMessages() then
    if not sceneManager.nextSceneName then
      -- automatic reconnect if we're not about to switch scene
      self.state = STATES.Login
      self.loginRoutine = LoginRoutine(GAME.tcpClient, GAME.connected_server_ip, GAME.connected_server_port)
      GAME.tcpClient:resetNetwork()
    end
  end

  GAME.gfx_q:push({self.draw, {self}})
end

function Lobby:drawBackground()
  self.backgroundImg:draw()
end

function Lobby:draw()
  if self.state == STATES.Lobby then
    self.lobbyScreen:draw()
  elseif self.state == STATES.Login then
    loginStateLabel:draw()
  end
end

return Lobby

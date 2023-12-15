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
local ClientRequests = require("network.ClientProtocol")

local STATES = { Login = 1, Lobby = 2}

--@module Lobby
-- expects a serverIp and serverPort as a param (unless already set in GAME.connected_server_ip & GAME.connected_server_port respectively)
local Lobby = class(
  function (self, sceneParams)
    -- lobby data from the server
    self.playerData = nil
    self.unpairedPlayers = {} -- list
    self.willingPlayers = {} -- set
    self.spectatableRooms = {}
    -- requests to play a match, not web requests
    self.sentRequests = {}

    -- leaderboard data
    self.showingLeaderboard = false
    self.myRank = nil
    self.leaderboardString = ""
    self.leaderboardResponse = nil

    -- ui
    self.backgroundImg = themes[config.theme].images.bg_main
    self.yOffset = themes[config.theme].main_menu_screen_pos[2] + 10
    self.lobbyMenu = nil
    self.lobbyMenuXoffsetMap = {[true] = themes[config.theme].main_menu_screen_pos[1] - 200, [false] = themes[config.theme].main_menu_screen_pos[1]} --will be used to make room in case the leaderboard should be shown.
    -- currently unused, need to find a new place to draw this later
    self.notice = {[true] = loc("lb_select_player"), [false] = loc("lb_alone")}

    -- state fields to manage Lobby's update cycle    
    self.state = STATES.Login

    -- network features not yet implemented
    self.spectateRequestResponse = nil
    self.requestedSpectateRoom = nil

    self:load(sceneParams)
  end,
  Scene
)

Lobby.name = "Lobby"
sceneManager:addScene(Lobby)

----------
-- exit --
----------

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  resetNetwork()
  sceneManager:switchToScene("MainMenu")
end

function Lobby:unload()
  self.lobbyMenu:setVisibility(false)
end

-------------
-- startup --
-------------

function Lobby:load(sceneParams)
  self.loginRoutine = LoginRoutine(sceneParams.serverIp, sceneParams.serverPort)
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
  self.leaderboardToggleLabel = Label({text = "lb_show_board"})
  self.leaderboardToggleButton = TextButton({label = self.leaderboardToggleLabel, onClick = function() self:toggleLeaderboard() end})
  local menuItems = {
    {self.leaderboardToggleButton},
    {TextButton({label = Label({text = "lb_back"}), onClick = exitMenu})},
  }

  self.lobbyMenu = Menu({x = self.lobbyMenuXoffsetMap[self.showingLeaderboard], y = self.yOffset, menuItems = menuItems})
end

-----------------
-- leaderboard --
-----------------

function Lobby:toggleLeaderboard()
  Menu.playMoveSfx()
  if not self.showingLeaderboard then
    self.leaderboardToggleLabel:setText("lb_hide_board")
    self.showingLeaderboard = true
    self.leaderboardResponse = ClientRequests.requestLeaderboard()
  else
    self.leaderboardToggleLabel:setText("lb_show_board")
    self.showingLeaderboard = false
  end
  self.lobbyMenu.x = self.lobbyMenuXoffsetMap[self.showingLeaderboard]
end

local function build_viewable_leaderboard_string(report, first_viewable_idx, last_viewable_idx)
  str = loc("lb_header_board") .. "\n"
  first_viewable_idx = math.max(first_viewable_idx, 1)
  last_viewable_idx = math.min(last_viewable_idx, #report)

  for i = first_viewable_idx, last_viewable_idx do
    rating_spacing = "     " .. string.rep("  ", (3 - string.len(i)))
    name_spacing = "     " .. string.rep("  ", (4 - string.len(report[i].rating)))
    if report[i].is_you then
      str = str .. loc("lb_you") .. "-> "
    else
      str = str .. "      "
    end
    str = str .. i .. rating_spacing .. report[i].rating .. name_spacing .. report[i].user_name
    if i < #report then
      str = str .. "\n"
    end
  end
  return str
end

function Lobby:updateLeaderboard(leaderboardReport)
  if leaderboardReport.leaderboard_report then
    local leaderboard_report = leaderboardReport.leaderboard_report
    for rank = #leaderboard_report, 1, -1 do
      local user = leaderboard_report[rank]
      if user.user_name == config.name then
        self.myRank = rank
      end
    end
    local leaderboard_first_idx_to_show = math.max((self.myRank or 1) - 8, 1)
    local leaderboard_last_idx_to_show = math.min(leaderboard_first_idx_to_show + 20, #leaderboard_report)
    self.leaderboardString = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
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
    local new_willing = {}
    local new_sent_requests = {}
    for _, player in ipairs(self.unpairedPlayers) do
      new_willing[player] = self.willingPlayers[player]
      new_sent_requests[player] = self.sentRequests[player]
    end
    self.willingPlayers = new_willing
    self.sentRequests = new_sent_requests
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
  sceneManager:switchToScene("CharacterSelectOnline", {roomInitializationMessage = createRoomMessage})
end

-- starts to spectate a 2p vs online match
function Lobby:spectate2pVsOnlineMatch(spectateRequestGrantedMessage)
  -- Not yet implemented
  GAME.battleRoom = BattleRoom.createFromServerMessage(spectateRequestGrantedMessage)
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
    ClientRequests.challengePlayer(opponentName)
    self:onLobbyStateUpdate()
  end
end

-- requests to spectate the specified room
function Lobby:requestSpectateFunction(room)
  return function()
    self.requestedSpectateRoom = room
    self.spectateRequestResponse = ClientRequests.requestSpectate(room.roomNumber)
  end
end

-- rebuilds the UI based on the new lobby information
function Lobby:onLobbyStateUpdate()
  if self.updated then
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
        self.lobbyMenu:addMenuItem(1, {TextButton({label = Label({text = unmatchedPlayer, translate = false}), onClick = self:requestGameFunction(v)})})
      end
    end
    for _, room in ipairs(self.spectatableRooms) do
      if room.name then
        local playerA = room.a .. self:playerRatingString(room.a)
        local playerB = room.b .. self:playerRatingString(room.b)
        local roomName = loc("lb_spectate") .. " " .. playerA .. " vs " .. playerB .. " (" .. room.state .. ")"
        self.lobbyMenu:addMenuItem(1, {TextButton({label = Label({text = roomName, translate = false}), onClick = self:requestSpectateFunction(room)})})
      end
    end
  end

  self.updated = false
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
      self.leaderboardResponse = ClientRequests.requestLeaderboard()
    elseif status == "received" then
      self:updateLeaderboard(value)
    end
  end

  if self.spectateRequestResponse then
    local status, value = self.spectateRequestResponse:tryGetValue()
    if status == "timeout" then
      self.spectateRequestResponse = ClientRequests.requestSpectate(self.requestedSpectateRoom.roomNumber)
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

  if not do_messages() then
    -- automatic reconnect
    self.state = STATES.Login
    self.loginRoutine = LoginRoutine(GAME.connected_server_ip, GAME.connected_server_port)
    resetNetwork()
  end

  GAME.gfx_q:push({self.draw, {self}})
end

function Lobby:drawBackground()
  self.backgroundImg:draw()
end

function Lobby:draw()
  if self.state == STATES.Lobby then
    self.lobbyMenu:draw()
    if self.showingLeaderboard and self.leaderboardString and self.leaderboardString ~= "" then
      gprint(self.leaderboardString, self.lobbyMenuXoffsetMap[true] + 400, self.yOffset)
    end
  elseif self.state == STATES.Login then
    loginStateLabel:draw()
  end
end

return Lobby
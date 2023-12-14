local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Label = require("ui.Label")
local ButtonGroup = require("ui.ButtonGroup")
local TextButton = require("ui.TextButton")
local Menu = require("ui.Menu")
local class = require("class")
local consts = require("consts")
local input = require("inputManager")
local logger = require("logger")
local GameModes = require("GameModes")
local LoginRoutine = require("network.LoginRoutine")
local MessageListener = require("network.MessageListener")

local STATES = { Login = 1, Lobby = 2}

--@module Lobby
-- expects a serverIp and serverPort as a param (unless already set in GAME.connected_server_ip & GAME.connected_server_port respectively)
local Lobby = class(
  function (self, sceneParams)
    self.backgroundImg = themes[config.theme].images.bg_main
    
    self.unpaired_players = {} -- list
    self.willing_players = {} -- set
    self.spectatable_rooms = {}

    -- reset player ids and match type
    -- this is necessary because the player ids are only supplied on initial joining and then assumed to stay the same for consecutive games in the same room
    self.notice = {[true] = loc("lb_select_player"), [false] = loc("lb_alone")}
    self.leaderboard_string = ""
    self.my_rank = nil

    self.login_status_message = "   " .. loc("lb_login")
    self.noticeTextObject = nil
    self.noticeLastText = nil
    self.login_status_message_duration = 2
    self.login_denied = false
    self.showing_leaderboard = false
    self.lobby_menu_x = {[true] = themes[config.theme].main_menu_screen_pos[1] - 200, [false] = themes[config.theme].main_menu_screen_pos[1]} --will be used to make room in case the leaderboard should be shown.
    self.lobby_menu_y = themes[config.theme].main_menu_screen_pos[2] + 10
    self.sent_requests = {}

    self.lobby_menu = nil
    self.lastPlayerIndex = 0
    self.updated = true -- need update when first entering
    self.ret = nil
    self.requestedSpectateRoom = nil
    self.playerData = nil
    
    self.transitioning = false
    self.switchSceneLabel = nil
    
    -- set if needed in DefautUpdate
    self.serverNoticeLabel = nil
    self.loginDeniedMsg = nil
    
    --set in load
    self.state = nil
    self.stateParams = {
      startTime = nil,
      maxDisplayTime = nil, 
      minDisplayTime = nil,
      sceneName = nil,
      sceneParams = nil
    }
    self.lobbyMenu = nil
    
    self:load(sceneParams)
  end,
  Scene
)

Lobby.name = "Lobby"
sceneManager:addScene(Lobby)

local states = {SWITCH_SCENE = 1, SET_NAME = 2, DEFAULT = 3, SHOW_SERVER_NOTICE = 4}
local SERVER_NOTICE_DISPLAY_TIME = 3

local serverIp = nil
local serverPort = nil

function Lobby:toggleLeaderboard()
  self.updated = true
  if not self.showing_leaderboard then
    --lobby_menu:set_button_text(#lobby_menu.buttons - 1, loc("lb_hide_board"))
    self.showing_leaderboard = true
    json_send({leaderboard_request = true})
  else
    --lobby_menu:set_button_text(#lobby_menu.buttons - 1, loc("lb_show_board"))
    self.showing_leaderboard = false
    self.lobby_menu.x = self.lobby_menu_x[self.showing_leaderboard]
  end
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("MainMenu")
end

function Lobby:start2pVsOnlineMatch(createRoomMessage)
  GAME.battleRoom = BattleRoom.createFromServerMessage(createRoomMessage)
  love.window.requestAttention()
  play_optional_sfx(themes[config.theme].sounds.notification)
  sceneManager:switchToScene("CharacterSelectOnline", {roomInitializationMessage = createRoomMessage})
end

function Lobby:spectate2pVsOnlineMatch(spectateRequestGrantedMessage)
  GAME.battleRoom = BattleRoom.createFromServerMessage(spectateRequestGrantedMessage)
  sceneManager:switchToScene("CharacterSelectOnline", {battleRoom = GAME.battleRoom})
end

function Lobby:updateLobbyState(lobbyStateMessage)
  if lobbyStateMessage.players then
    self.playerData = lobbyStateMessage.players
  end
  if lobbyStateMessage.unpaired then
    self.unpaired_players = lobbyStateMessage.unpaired
    -- players who leave the unpaired list no longer have standing invitations to us.\
    -- we also no longer have a standing invitation to them, so we'll remove them from sent_requests
    local new_willing = {}
    local new_sent_requests = {}
    for _, player in ipairs(self.unpaired_players) do
      new_willing[player] = self.willing_players[player]
      new_sent_requests[player] = self.sent_requests[player]
    end
    self.willing_players = new_willing
    self.sent_requests = new_sent_requests
    if lobbyStateMessage.spectatable then
      self.spectatable_rooms = lobbyStateMessage.spectatable
    end
  end
  self.updated = true
end

function Lobby:processGameRequest(gameRequestMessage)
  if gameRequestMessage.game_request then
    self.updated = true
    self.willing_players[gameRequestMessage.game_request.sender] = true
    love.window.requestAttention()
    play_optional_sfx(themes[config.theme].sounds.notification)
  end
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
    self.updated = true
    leaderboard_report = leaderboardReport.leaderboard_report
    for rank = #leaderboard_report, 1, -1 do
      local user = leaderboard_report[rank]
      if user.user_name == config.name then
        self.my_rank = rank
      end
    end
    leaderboard_first_idx_to_show = math.max((self.my_rank or 1) - 8, 1)
    leaderboard_last_idx_to_show = math.min(leaderboard_first_idx_to_show + 20, #leaderboard_report)
    leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
  end
end

function Lobby:initLobbyMenu()
  local showLeaderboardButtonGroup = ButtonGroup(
    {
      buttons = {
        TextButton({width = 60, label = Label({text = "op_off"})}),
        TextButton({width = 60, label = Label({text = "op_on"})}),
      },
      values = {false, true},
      selectedIndex = 1,
      onChange = function(value) 
        Menu.playMoveSfx()
        -- enable leaderboard
      end
    }
  )
  
  local menuItems = {
    {Label({text = "Leaderboard", translate = false}), showLeaderboardButtonGroup},
    {TextButton({label = Label({text = "lb_back"}), onClick = exitMenu})},
  }

  self.lobbyMenu = Menu({x = self.lobby_menu_x[showLeaderboardButtonGroup.value], y = self.lobby_menu_y, menuItems = menuItems})
end

function Lobby:load(sceneParams)
  self.loginRoutine = LoginRoutine(sceneParams.serverIp, sceneParams.serverPort)
  self.messageListeners = {}
  self.messageListeners["create_room"] = MessageListener("create_room")
  self.messageListeners["create_room"]:subscribe(self, self.start2pVsOnlineMatch)
  self.messageListeners["unpaired"] = MessageListener("unpaired")
  self.messageListeners["unpaired"]:subscribe(self, self.updateLobbyState)
  self.messageListeners["game_request"] = MessageListener("game_request")
  self.messageListeners["game_request"]:subscribe(self, self.processGameRequest)

  --main_net_vs_lobby
  if next(currently_playing_tracks) == nil then
    stop_the_music()
    if themes[config.theme].musics["main"] then
      find_and_add_music(themes[config.theme].musics, "main")
    end
  end
  reset_filters()

  -- reset match type
  match_type = ""
  match_type_message = ""

  self:initLobbyMenu()

  self.state = states.DEFAULT
end

function Lobby:drawBackground()
  self.backgroundImg:draw()
end

function Lobby:processServerMessages()
  for _, listener in pairs(self.messageListeners) do
    listener:listen()
  end
end

function Lobby:playerRatingString(playerName)
  local rating = ""
  if self.playerData and self.playerData[playerName] and self.playerData[playerName].rating then
    rating = " (" .. self.playerData[playerName].rating .. ")"
  end
  return rating
end

function Lobby:requestGameFunction(opponentName)
  return function()
    self.sent_requests[opponentName] = true
    request_game(opponentName)
    self.updated = true
  end
end

function Lobby:requestSpectateFunction(room)
  return function()
    self.requestedSpectateRoom = room
    request_spectate(room.roomNumber)
  end
end

function Lobby:defaultUpdate(dt)
  if not do_messages() then
    self.state = states.DISCONNECTED
    return
  end
  drop_old_data_messages() -- We are in the lobby, we shouldn't have any game data messages
    
  self:processServerMessages()

  -- If we got an update to the lobby, refresh the menu
  if self.updated then
    while #self.lobbyMenu.menuItems > 2 do
      self.lobbyMenu:removeMenuItemAtIndex(1)
    end
    for _, v in ipairs(self.unpaired_players) do
      if v ~= config.name then
        local unmatchedPlayer = v .. self:playerRatingString(v) .. (self.sent_requests[v] and " " .. loc("lb_request") or "") .. (self.willing_players[v] and " " .. loc("lb_received") or "")
        self.lobbyMenu:addMenuItem(1, {TextButton({label = Label({text = unmatchedPlayer, translate = false}), onClick = self:requestGameFunction(v)})})
      end
    end
    for _, room in ipairs(self.spectatable_rooms) do
      if room.name then
        local roomName = loc("lb_spectate") .. " " .. room.a .. self:playerRatingString(room.a) .. " vs " .. room.b .. self:playerRatingString(room.b) .. " (" .. room.state .. ")"
        --local roomName = loc("lb_spectate") .. " " .. room.name .. " (" .. room.state .. ")" --printing room names
        self.lobbyMenu:addMenuItem(1, {TextButton({label = Label({text = roomName, translate = false}), onClick = self:requestSpectateFunction(room)})})
      end
    end
  end

  self.updated = false
end

function Lobby:update(dt)
  self.backgroundImg:update(dt)

  if self.state == states.SWITCH_SCENE then
    local stateDuration = love.timer.getTime() - self.stateParams.startTime
    if stateDuration >= self.stateParams.maxDisplayTime or 
       (stateDuration <= self.stateParams.minDisplayTime and (input.isDown["MenuEsc"] or input.isDown["MenuPause"])) then
      sceneManager:switchToScene(self.stateParams.sceneName, self.stateParams.sceneParams)
    end
  elseif self.state == states.SET_NAME then
      sceneManager:switchToScene("SetNameMenu", {prevScene = "Lobby"})
  elseif self.state == states.DEFAULT then
    self:defaultUpdate(dt)
    self.lobbyMenu:update()
  elseif self.state == states.SHOW_SERVER_NOTICE then
    if love.timer.getTime() - self.stateParams.startTime >= SERVER_NOTICE_DISPLAY_TIME or input.isDown["MenuEsc"] or input.isDown["MenuPause"] then
      self.state = states.DEFAULT
    end
  end

  GAME.gfx_q:push({self.draw, {self}})
end

function Lobby:draw()
  if self.state ==states.SHOW_SERVER_NOTICE then
    self.serverNoticeLabel:draw()
  elseif self.state == states.DEFAULT then
    self.lobbyMenu:draw()
  elseif self.state == states.SWITCH_SCENE then
    self.switchSceneLabel:draw()
  end
end

function Lobby:unload()
  self.lobbyMenu:setVisibility(false)
end

return Lobby
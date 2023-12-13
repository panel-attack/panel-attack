local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Label = require("ui.Label")
local ButtonGroup = require("ui.ButtonGroup")
local TextButton = require("ui.TextButton")
local Menu = require("ui.Menu")
local class = require("class")
local consts = require("consts")
local select_screen = require("select_screen.select_screen")
local input = require("inputManager")
local uiUtils = require("ui.uiUtils")
local logger = require("logger")

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
    self.items = {}
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
  print("lobby")
  --main_net_vs_setup
  if not config.name or config.name == "defaultname" then
    self.state = states.SET_NAME
    return
  end
  if GAME.match then
    print("nil-ing P1 & P2")
    GAME.match.P1 = nil
    GAME.match.P2 = nil
  end
  server_queue = ServerQueue()
  --gprint(loc("lb_set_connect"), unpack(themes[config.theme].main_menu_screen_pos))

  print("lobby1")
  if sceneParams.serverIp then
    GAME.connected_server_ip = sceneParams.serverIp
  end
  if sceneParams.serverPort then
    GAME.connected_server_ip = sceneParams.serverPort
  end
  if not network_init(GAME.connected_server_ip, GAME.connected_network_port) then
    print("lobby1b")
    self.state = states.SWITCH_SCENE
    self.switchSceneLabel = uiUtils.createCenteredLabel(loc("ss_could_not_connect") .. "\n\n" .. loc("ss_return"))
    self.stateParams = {
      startTime = love.timer.getTime(),
      maxDisplayTime = 5, 
      minDisplayTime = 1,
      sceneName = "MainMenu",
      sceneParams = nil
    }
    print("lobby2b")
    return
  end
print("lobby2")
  local timeout_counter = 0
  while not connection_is_ready() do
    --gprint(loc("lb_connecting"), unpack(themes[config.theme].main_menu_screen_pos))
    if not do_messages() then
      self.state = states.SWITCH_SCENE
      self.switchSceneLabel = uiUtils.createCenteredLabel(loc("ss_disconnect") .. "\n\n" .. loc("ss_return"))
      self.stateParams = {
        startTime = love.timer.getTime(),
        maxDisplayTime = 5, 
        minDisplayTime = 1,
        sceneName = "MainMenu",
        sceneParams = nil
      }
      return
    end
  end
  print("lobby3")
  logged_in = false
  
  --main_net_vs_lobby
  if next(currently_playing_tracks) == nil then
    stop_the_music()
    if themes[config.theme].musics["main"] then
      find_and_add_music(themes[config.theme].musics, "main")
    end
  end
  print("lobby4")
  GAME.battleRoom = nil
  reset_filters()
  CharacterLoader.clear()
  StageLoader.clear()
  
  -- reset player ids and match type
  -- this is necessary because the player ids are only supplied on initial joining and then assumed to stay the same for consecutive games in the same room
  select_screen.my_player_number = nil
  select_screen.op_player_number = nil
  match_type = ""
  match_type_message = ""
  --attempt login
  read_user_id_file(GAME.connected_server_ip)
  if not my_user_id then
    my_user_id = "need a new user id"
  end

print("lobby5")
  if connection_up_time <= self.login_status_message_duration then
    json_send({login_request = true, user_id = my_user_id})
  end
  
  self:initLobbyMenu()
  
  self.state = states.DEFAULT
  print("lobbyEnd")
end

function Lobby:drawBackground()
  self.backgroundImg:draw()
end

function Lobby:processServerMessages()
  if connection_up_time <= self.login_status_message_duration then
    local messages = server_queue:pop_all_with("login_successful", "login_denied")
    for _, msg in ipairs(messages) do
      print(msg)
      if msg.login_successful then
        current_server_supports_ranking = true
        logged_in = true
        if msg.new_user_id then
          my_user_id = msg.new_user_id
          logger.trace("about to write user id file")
          write_user_id_file(my_user_id, GAME.connected_server_ip)
          self.login_status_message = loc("lb_user_new", config.name)
        elseif msg.name_changed then
          self.login_status_message = loc("lb_user_update", msg.old_name, msg.new_name)
          self.login_status_message_duration = 5
        else
          self.login_status_message = loc("lb_welcome_back", config.name)
        end
        if msg.server_notice then
          local serverNotice = msg.server_notice:gsub("\\n", "\n")
          self.serverNoticeLabel = uiUtils.createCenteredLabel(serverNotice)
          
          self.stateParams.startTime = love.timer.getTime()

          self.state = states.SHOW_SERVER_NOTICE
        end
      elseif msg.login_denied then
        current_server_supports_ranking = true
        self.login_denied = true
        --TODO: create a menu here to let the user choose "continue unranked" or "get a new user_id"
        --login_status_message = "Login for ranked matches failed.\n"..msg.reason.."\n\nYou may continue unranked,\nor delete your invalid user_id file to have a new one assigned."
        login_status_message_duration = 10
        self.state = states.SWITCH_SCENE
        self.switchSceneLabel = uiUtils.createCenteredLabel(loc("lb_error_msg") .. "\n\n" .. json.encode(msg))
        self.stateParams = {
          startTime = love.timer.getTime(),
          maxDisplayTime = 10, 
          minDisplayTime = 1,
          sceneName = "MainMenu",
          sceneParams = nil
        }
        return
      end
      
    end
    if connection_up_time == 2 and not current_server_supports_ranking then
      self.login_status_message = loc("lb_login_timeout")
      self.login_status_message_duration = 7
    end
  end

  local messages = server_queue:pop_all_with("choose_another_name", "create_room", "unpaired", "game_request", "leaderboard_report", "spectate_request_granted")
  for _, msg in ipairs(messages) do
    self.updated = true
    self.items = {}
    if msg.choose_another_name and msg.choose_another_name.used_names then
      self.state = states.SWITCH_SCENE
      self.switchSceneLabel = uiUtils.createCenteredLabel(loc("lb_used_name"))
      self.stateParams = {
        startTime = love.timer.getTime(),
        maxDisplayTime = 10, 
        minDisplayTime = 1,
        sceneName = "MainMenu",
        sceneParams = nil
      }
      return
    elseif msg.choose_another_name and msg.choose_another_name.reason then
      self.state = states.SWITCH_SCENE
      self.switchSceneLabel = uiUtils.createCenteredLabel("Error: " .. msg.choose_another_name.reason)
      self.stateParams = {
        startTime = love.timer.getTime(),
        maxDisplayTime = 5, 
        minDisplayTime = 1,
        sceneName = "MainMenu",
        sceneParams = nil
      }
      return
    end
    if msg.create_room or msg.spectate_request_granted then
      GAME.battleRoom = BattleRoom()
      if msg.spectate_request_granted then
        if not self.requestedSpectateRoom then
          error("expected requested room")
        end
        GAME.battleRoom.spectating = true
        GAME.battleRoom.playerNames[1] = self.requestedSpectateRoom.a
        GAME.battleRoom.playerNames[2] = self.requestedSpectateRoom.b
      else
        GAME.battleRoom.playerNames[1] = config.name
        GAME.battleRoom.playerNames[2] = msg.opponent
        love.window.requestAttention()
        play_optional_sfx(themes[config.theme].sounds.notification)
      end
      sceneManager:switchToScene("CharacterSelectOnline", {roomInitializationMessage = msg})
      --return select_screen.main, {select_screen, "2p_net_vs", msg}
    end
    if msg.players then
      self.playerData = msg.players
    end
    if msg.unpaired then
      self.unpaired_players = msg.unpaired
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
      if msg.spectatable then
        self.spectatable_rooms = msg.spectatable
      end
    end

    if msg.game_request then
      self.willing_players[msg.game_request.sender] = true
      love.window.requestAttention()
      play_optional_sfx(themes[config.theme].sounds.notification)
    end
    if msg.leaderboard_report then
      --if self.lobby_menu then
      --  self.lobby_menu:show_controls(true)
      --end
      leaderboard_report = msg.leaderboard_report
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
    if not self.transitioning and
       stateDuration >= self.stateParams.maxDisplayTime or 
       (stateDuration <= self.stateParams.minDisplayTime and (input.isDown["MenuEsc"] or input.isDown["MenuPause"])) then
      sceneManager:switchToScene(self.stateParams.sceneName, self.stateParams.sceneParams)
      self.transitioning = true
    end
    self.switchSceneLabel:draw()
  elseif self.state == states.SET_NAME then
    if not self.transitioning then
      sceneManager:switchToScene("SetNameMenu", {prevScene = "Lobby"})
      self.transitioning = true
    end
  elseif self.state == states.DEFAULT then
    self:defaultUpdate(dt)
    self.lobbyMenu:update()
    self.lobbyMenu:draw()
  elseif self.state == states.SHOW_SERVER_NOTICE then
    if love.timer.getTime() - self.stateParams.startTime >= SERVER_NOTICE_DISPLAY_TIME or input.isDown["MenuEsc"] or input.isDown["MenuPause"] then
      self.state = states.DEFAULT
    end
    self.serverNoticeLabel:draw()
  end
end

function Lobby:unload()
  self.lobbyMenu:setVisibility(false)
end

return Lobby
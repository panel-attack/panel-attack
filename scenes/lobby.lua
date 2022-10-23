local Scene = require("scenes.Scene")
local replay_browser = require("replay_browser")
local logger = require("logger")
local options = require("options")
local utf8 = require("utf8")
local analytics = require("analytics")
local main_config_input = require("config_inputs")
local ServerQueue = require("ServerQueue")
local Button = require("ui.Button")
local Menu = require("ui.Menu")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local ClickMenu = require("ClickMenu")

--@module MainMenu
local lobby = Scene("lobby")

local login_status_message_duration = 2

local unpaired_players = {} -- list
local willing_players = {} -- set
local spectatable_rooms = {}
local sent_requests = {}

local lobby_menu_x = {[true] = themes[config.theme].main_menu_screen_pos[1] - 200, [false] = themes[config.theme].main_menu_screen_pos[1]} --will be used to make room in case the leaderboard should be shown.
local lobby_menu_y = themes[config.theme].main_menu_screen_pos[2] + 10

local showing_leaderboard = false

local notice = {[true] = loc("lb_select_player"), [false] = loc("lb_alone")}

local leaderboard_string = ""
local my_rank

local login_status_message = "   " .. loc("lb_login")

local noticeTextObject = nil
local noticeLastText = nil

local login_denied = false

local lobby_menu = nil
local items = {}
local lastPlayerIndex = 0
local updated = true -- need update when first entering
local ret = nil
local requestedSpectateRoom = nil
local playerData = nil

local exit = false

local function toggleLeaderboard()
  updated = true
  if not showing_leaderboard then
    lobby_menu:set_button_text(#lobby_menu.buttons - 1, loc("lb_hide_board"))
    showing_leaderboard = true
    json_send({leaderboard_request = true})
  else
    lobby_menu:set_button_text(#lobby_menu.buttons - 1, loc("lb_show_board"))
    showing_leaderboard = false
    lobby_menu.x = lobby_menu_x[showing_leaderboard]
  end
end

local function commonSelectLobby()
  updated = true
  spectator_list = {}
  spectators_string = ""
  lobby_menu:remove_self()
end

local function goEscape()
  lobby_menu:set_active_idx(#lobby_menu.buttons)
end

local function exitLobby()
  exit = true
  commonSelectLobby()
  sceneManager:switchToScene("mainMenu")
  json_send({logout = true})
  --ret = {main_select_mode}
end

local function requestGameFunction(opponentName)
  return function()
    sent_requests[opponentName] = true
    request_game(opponentName)
    updated = true
  end
end

local function requestSpectateFunction(room)
  return function()
    requestedSpectateRoom = room
    request_spectate(room.roomNumber)
  end
end

local function playerRatingString(playerName)
  local rating = ""
  if playerData and playerData[playerName] and playerData[playerName].rating then
    rating = " (" .. playerData[playerName].rating .. ")"
  end
  return rating
end

function lobby:init()
  sceneManager:addScene(lobby)
end

function lobby:load(sceneParams)
  exit = false
  
  if not config.name then
    sceneManager:switchToScene("set_name_menu", {prevScene = "lobby"})
  end
  
  --GAME.match.P1 = nil
  --GAME.match.P2 = {}
  server_queue = ServerQueue()
  gprint(loc("lb_set_connect"), unpack(themes[config.theme].main_menu_screen_pos))

  if not network_init(sceneParams.ip, sceneParams.network_port) then
    sceneManager:switchToScene("mainMenu")
    return
    --return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
  end

  --local timeout_counter = 0
  while not connection_is_ready() do
    gprint(loc("lb_connecting"), unpack(themes[config.theme].main_menu_screen_pos))
    if not do_messages() then
      sceneManager:switchToScene("mainMenu")
      return
      --return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
    end
  end

  connected_server_ip = sceneParams.ip
  logged_in = false
  
  if next(currently_playing_tracks) == nil then
    stop_the_music()
    if themes[config.theme].musics["main"] then
      find_and_add_music(themes[config.theme].musics, "main")
    end
  end
  GAME.backgroundImage = themes[config.theme].images.bg_main
  GAME.battleRoom = nil
  
  undo_stonermode()
  reset_filters()
  character_loader_clear()
  stage_loader_clear()
  
  -- reset player ids and match type
  -- this is necessary because the player ids are only supplied on initial joining and then assumed to stay the same for consecutive games in the same room
  --select_screen.my_player_number = nil
  --select_screen.op_player_number = nil
  match_type = ""
  match_type_message = ""
  
  --attempt login
  read_user_id_file()
  if not my_user_id then
    my_user_id = "need a new user id"
  end
  
  
  
  if connection_up_time <= login_status_message_duration then
    json_send({login_request = true, user_id = my_user_id})
  end
  
  GAME.rich_presence:setPresence(nil, "In Lobby", true)
end

function lobby:update()
  if exit then
    return
  end

  if connection_up_time <= login_status_message_duration then
    local messages = server_queue:pop_all_with("login_successful", "login_denied")
    for _, msg in ipairs(messages) do
      if msg.login_successful then
        current_server_supports_ranking = true
        logged_in = true
        if msg.new_user_id then
          my_user_id = msg.new_user_id
          logger.trace("about to write user id file")
          write_user_id_file()
          login_status_message = loc("lb_user_new", config.name)
        elseif msg.name_changed then
          login_status_message = loc("lb_user_update", msg.old_name, msg.new_name)
          login_status_message_duration = 5
        else
          login_status_message = loc("lb_welcome_back", config.name)
        end
      elseif msg.login_denied then
        current_server_supports_ranking = true
        login_denied = true
        --TODO: create a menu here to let the user choose "continue unranked" or "get a new user_id"
        --login_status_message = "Login for ranked matches failed.\n"..msg.reason.."\n\nYou may continue unranked,\nor delete your invalid user_id file to have a new one assigned."
        login_status_message_duration = 10
        sceneManager:switchToScene("mainMenu")
        return
        --return main_dumb_transition, {main_select_mode, loc("lb_error_msg") .. "\n\n" .. json.encode(msg), 60, 600}
      end
    end
    if connection_up_time == 2 and not current_server_supports_ranking then
      login_status_message = loc("lb_login_timeout")
      login_status_message_duration = 7
    end
  end
  local messages = server_queue:pop_all_with("choose_another_name", "create_room", "unpaired", "game_request", "leaderboard_report", "spectate_request_granted")
  for _, msg in ipairs(messages) do
    updated = true
    items = {}
    if msg.choose_another_name and msg.choose_another_name.used_names then
      sceneManager:switchToScene("mainMenu")
      return
      --return main_dumb_transition, {main_select_mode, loc("lb_used_name"), 60, 600}
    elseif msg.choose_another_name and msg.choose_another_name.reason then
      sceneManager:switchToScene("mainMenu")
      return
      --return main_dumb_transition, {main_select_mode, "Error: " .. msg.choose_another_name.reason, 60, 300}
    end
    if msg.create_room or msg.spectate_request_granted then
      GAME.battleRoom = BattleRoom()
      if msg.spectate_request_granted then
        if not requestedSpectateRoom then
          error("expected requested room")
        end
        GAME.battleRoom.spectating = true
        GAME.battleRoom.playerNames[1] = requestedSpectateRoom.a
        GAME.battleRoom.playerNames[2] = requestedSpectateRoom.b
      else
        GAME.battleRoom.playerNames[1] = config.name
        GAME.battleRoom.playerNames[2] = msg.opponent
      end
      love.window.requestAttention()
      play_optional_sfx(themes[config.theme].sounds.notification)
      lobby_menu:remove_self()
      
      -- UPDATE THIS!!!
      sceneManager:switchToScene("vs_self_menu", {message = msg})
      return
      --return select_screen.main, {select_screen, "2p_net_vs", msg}
    end
    if msg.players then
      playerData = msg.players
    end
    if msg.unpaired then
      unpaired_players = msg.unpaired
      -- players who leave the unpaired list no longer have standing invitations to us.\
      -- we also no longer have a standing invitation to them, so we'll remove them from sent_requests
      local new_willing = {}
      local new_sent_requests = {}
      for _, player in ipairs(unpaired_players) do
        new_willing[player] = willing_players[player]
        new_sent_requests[player] = sent_requests[player]
      end
      willing_players = new_willing
      sent_requests = new_sent_requests
      if msg.spectatable then
        spectatable_rooms = msg.spectatable
      end
    end
    if msg.game_request then
      willing_players[msg.game_request.sender] = true
      love.window.requestAttention()
      play_optional_sfx(themes[config.theme].sounds.notification)
    end
    if msg.leaderboard_report then
      if lobby_menu then
        lobby_menu:show_controls(true)
      end
      leaderboard_report = msg.leaderboard_report
      for rank = #leaderboard_report, 1, -1 do
        local user = leaderboard_report[rank]
        if user.user_name == config.name then
          my_rank = rank
        end
      end
      leaderboard_first_idx_to_show = math.max((my_rank or 1) - 8, 1)
      leaderboard_last_idx_to_show = math.min(leaderboard_first_idx_to_show + 20, #leaderboard_report)
      leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
    end
  end

  -- If we got an update to the lobby, refresh the menu
  if updated then
    spectator_list = {}
    spectators_string = ""
    local oldLobbyMenu = nil
    if lobby_menu then
      oldLobbyMenu = lobby_menu
      lobby_menu:remove_self()
      lobby_menu = nil
    end

    local menuHeight = (themes[config.theme].main_menu_y_max - lobby_menu_y)
    lobby_menu = ClickMenu(lobby_menu_x[showing_leaderboard], lobby_menu_y, nil, menuHeight, 1)
    for _, v in ipairs(unpaired_players) do
      if v ~= config.name then
        local unmatchedPlayer = v .. playerRatingString(v) .. (sent_requests[v] and " " .. loc("lb_request") or "") .. (willing_players[v] and " " .. loc("lb_received") or "")
        lobby_menu:add_button(unmatchedPlayer, requestGameFunction(v), goEscape)
      end
    end
    for _, room in ipairs(spectatable_rooms) do
      if room.name then
        local roomName = loc("lb_spectate") .. " " .. room.a .. playerRatingString(room.a) .. " vs " .. room.b .. playerRatingString(room.b) .. " (" .. room.state .. ")"
        --local roomName = loc("lb_spectate") .. " " .. room.name .. " (" .. room.state .. ")" --printing room names
        lobby_menu:add_button(roomName, requestSpectateFunction(room), goEscape)
      end
    end
    if showing_leaderboard then
      lobby_menu:add_button(loc("lb_hide_board"), toggleLeaderboard, toggleLeaderboard)
    else
      lobby_menu:add_button(loc("lb_show_board"), toggleLeaderboard, goEscape)
    end
    lobby_menu:add_button(loc("lb_back"), exitLobby, exitLobby)

    -- Restore the lobby selection
    -- (If the lobby only had 2 buttons it was before we got lobby info so don't restore the selection)
    if oldLobbyMenu and #oldLobbyMenu.buttons > 2 then
      if oldLobbyMenu.active_idx == #oldLobbyMenu.buttons then
        lobby_menu:set_active_idx(#lobby_menu.buttons)
      elseif oldLobbyMenu.active_idx == #oldLobbyMenu.buttons - 1 and #lobby_menu.buttons >= 2 then
        lobby_menu:set_active_idx(#lobby_menu.buttons - 1) --the position of the "hide leaderboard" menu item
      else
        local desiredIndex = bound(1, oldLobbyMenu.active_idx, #lobby_menu.buttons)
        local previousText = oldLobbyMenu.buttons[oldLobbyMenu.active_idx].stringText
        for i = 1, #lobby_menu.buttons do
          if #oldLobbyMenu.buttons >= i then
            if lobby_menu.buttons[i].stringText == previousText then
              desiredIndex = i
              break
            end
          end
        end
        lobby_menu:set_active_idx(desiredIndex)
      end

      oldLobbyMenu = nil
    end
  end

  if lobby_menu then
    local noticeText = notice[#lobby_menu.buttons > 2]
    if connection_up_time <= login_status_message_duration then
      noticeText = login_status_message
    end

    local noticeHeight = 0
    local button_padding = 4
    if noticeText ~= noticeLastText then
      noticeTextObject = love.graphics.newText(get_global_font(), noticeText)
      noticeHeight = noticeTextObject:getHeight() + (button_padding * 2)
      lobby_menu.yMin = lobby_menu_y + noticeHeight
      local menuHeight = (themes[config.theme].main_menu_y_max - lobby_menu.yMin)
      lobby_menu:setHeight(menuHeight)
    end
    if noticeTextObject then
      local noticeX = lobby_menu_x[showing_leaderboard] + 2
      local noticeY = lobby_menu.y - noticeHeight - 10
      local noticeWidth = noticeTextObject:getWidth() + (button_padding * 2)
      local grey = 0.0
      local alpha = 0.6
      grectangle_color("fill", noticeX / GFX_SCALE, noticeY / GFX_SCALE, noticeWidth / GFX_SCALE, noticeHeight / GFX_SCALE, grey, grey, grey, alpha)
      --grectangle_color("line", noticeX / GFX_SCALE, noticeY / GFX_SCALE, noticeWidth / GFX_SCALE, noticeHeight / GFX_SCALE, grey, grey, grey, alpha)

      menu_drawf(noticeTextObject, noticeX + button_padding, noticeY + button_padding)
    end

    if showing_leaderboard then
      gprint(leaderboard_string, lobby_menu_x[showing_leaderboard] + 400, lobby_menu_y)
    end
    gprint(join_community_msg, themes[config.theme].main_menu_screen_pos[1] + 30, canvas_height - 50)
    lobby_menu:draw()
  end
  
  updated = false
  variable_step(
    function()
      if showing_leaderboard then
        if menu_up() and leaderboard_report then
          if showing_leaderboard then
            if leaderboard_first_idx_to_show > 1 then
              leaderboard_first_idx_to_show = leaderboard_first_idx_to_show - 1
              leaderboard_last_idx_to_show = leaderboard_last_idx_to_show - 1
              leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
            end
          end
        elseif menu_down() and leaderboard_report then
          if showing_leaderboard then
            if leaderboard_last_idx_to_show < #leaderboard_report then
              leaderboard_first_idx_to_show = leaderboard_first_idx_to_show + 1
              leaderboard_last_idx_to_show = leaderboard_last_idx_to_show + 1
              leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
            end
          end
        elseif menu_escape() or menu_enter() then
          toggleLeaderboard()
        end
      elseif lobby_menu then
        lobby_menu:update()
      end
    end
  )
  --if ret then
  --  json_send({logout = true})
  --  return unpack(ret)
  --end
  if not do_messages() then
    sceneManager:switchToScene("mainMenu")
    return
    --return main_dumb_transition, {main_select_mode, loc("ss_disconnect") .. "\n\n" .. loc("ss_return"), 60, 300}
  end
  drop_old_data_messages() -- We are in the lobby, we shouldn't have any game data messages
end

function lobby:unload()
  
end

return lobby
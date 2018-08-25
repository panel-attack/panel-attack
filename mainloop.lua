local wait, resume = coroutine.yield, coroutine.resume

local main_select_mode, main_endless, make_main_puzzle, main_net_vs_setup,
  main_replay_endless, main_replay_puzzle, main_net_vs,
  main_config_input, main_dumb_transition, main_select_puzz,
  menu_up, menu_down, menu_left, menu_right, menu_enter, menu_escape,
  main_replay_vs, main_local_vs_setup, main_local_vs, menu_key_func,
  multi_func, normal_key, main_set_name, main_character_select, main_net_vs_lobby,
  main_local_vs_yourself_setup, main_local_vs_yourself,
  main_options, exit_options_menu

VERSION = "024"
local PLAYING = "playing"  -- room states
local CHARACTERSELECT = "character select" --room states
local currently_spectating = false
connection_up_time = 0
logged_in = 0
connected_server_ip = nil
my_user_id = nil
leaderboard_report = nil
replay_of_match_so_far = nil
spectator_list = nil
spectators_string = ""
debug_mode_text = {[true]="On", [false]="Off"} 
ready_countdown_1P_text = {[true]="On", [false]="Off"}

function fmainloop()
  local func, arg = main_select_mode, nil
  replay = {}
  config = {character="lip", level=5, name="defaultname", master_volume=100, SFX_volume=100, music_volume=100, debug_mode=false, ready_countdown_1P = true, save_replays_publicly = "with my name", assets_dir=default_assets_dir, sounds_dir=default_sounds_dir}
  gprint("Reading config file", 300, 280)
  wait()
  read_conf_file() -- TODO: stop making new config files
  gprint("Reading replay file", 300, 280)
  wait()
  read_replay_file()
  gprint("Loading graphics...", 300, 280)
  wait()
  graphics_init() -- load images and set up stuff
  gprint("Loading sounds... (this takes a few seconds)", 300, 280)
  wait()
  sound_init()
  while true do
    leftover_time = 1/120
    consuming_timesteps = false
    func,arg = func(unpack(arg or {}))
    collectgarbage("collect")
  end
end

-- Wrapper for doing something at 60hz
-- The rest of the stuff happens at whatever rate is convenient
function variable_step(f)
  for i=1,4 do
    if leftover_time >= 1/60 then
      f()
      key_counts()
      this_frame_keys = {}
      leftover_time = leftover_time - 1/60
    end
  end
end

-- Changes the behavior of menu_foo functions.
-- In a menu that doesn't specifically pertain to multiple players,
-- up, down, left, right should always work.  But in a multiplayer
-- menu, those keys should definitely not move many cursors each.
local multi = false
function multi_func(func)
  return function(...)
    multi = true
    local res = {func(...)}
    multi = false
    return unpack(res)
  end
end

-- Keys that have a fixed function in menus can be bound to other
-- meanings, but should continue working the same way in menus.
local menu_reserved_keys = {}

function repeating_key(key)
  local key_time = keys[key]
  return this_frame_keys[key] or
    (key_time and key_time > 25 and key_time % 3 ~= 0)
end

function normal_key(key) return this_frame_keys[key] end

function menu_key_func(fixed, configurable, rept)
  local query = normal_key
  if rept then
    query = repeating_key
  end
  for i=1,#fixed do
    menu_reserved_keys[#menu_reserved_keys+1] = fixed[i]
  end
  return function(k)
    local res = false
    if multi then
      for i=1,#configurable do
        res = res or query(k[configurable[i]])
      end
    else
      for i=1,#fixed do
        res = res or query(fixed[i])
      end
      for i=1,#configurable do
        local keyname = k[configurable[i]]
        res = res or query(keyname) and
            not menu_reserved_keys[keyname]
      end
    end
    return res
  end
end

menu_up = menu_key_func({"up"}, {"up"}, true)
menu_down = menu_key_func({"down"}, {"down"}, true)
menu_left = menu_key_func({"left"}, {"left"}, true)
menu_right = menu_key_func({"right"}, {"right"}, true)
menu_enter = menu_key_func({"return","kenter","z"}, {"swap1"}, false)
menu_escape = menu_key_func({"escape","x"}, {"swap2"}, false)

do
  local active_idx = 1
  function main_select_mode()
    love.audio.stop()
    close_socket()
    logged_in = 0
    connection_up_time = 0
    connected_server_ip = ""
    current_server_supports_ranking = false
    match_type = ""
    match_type_message = ""
    local items = {{"1P endless", main_select_speed_99, {main_endless}},
        {"1P puzzle", main_select_puzz},
        {"1P time attack", main_select_speed_99, {main_time_attack}},
        {"1P vs yourself", main_local_vs_yourself_setup},
        --{"2P vs online at burke.ro", main_net_vs_setup, {"burke.ro"}},
        {"2P vs online at Jon's server", main_net_vs_setup, {"18.188.43.50"}},
        --{"2P vs online (USE ONLY WITH OTHER CLIENTS ON THIS TEST BUILD 025beta)", main_net_vs_setup, {"18.188.43.50"}},
        --{"This test build is for offline-use only"--[["2P vs online at Jon's server"]], main_select_mode},
        --{"2P vs online at domi1819.xyz (Europe, beta for spectating and ranking)", main_net_vs_setup, {"domi1819.xyz"}},
        --{"2P vs online at localhost (development-use only)", main_net_vs_setup, {"localhost"}},
        {"2P vs local game", main_local_vs_setup},
        {"Replay of 1P endless", main_replay_endless},
        {"Replay of 1P puzzle", main_replay_puzzle},
        {"Replay of 2P vs", main_replay_vs},
        {"Configure input", main_config_input},
        {"Set name", main_set_name},
        {"Options", main_options},
        {"Fullscreen (LAlt+Enter)", fullscreen},
        {"Quit", os.exit}}
    local k = K[1]
    while true do
      local to_print = ""
      local arrow = ""
      for i=1,#items do
        if active_idx == i then
          arrow = arrow .. ">"
        else
          arrow = arrow .. "\n"
        end
        to_print = to_print .. "   " .. items[i][1] .. "\n"
      end
      gprint(arrow, 300, 280)
      gprint(to_print, 300, 280)
      wait()
      if menu_up(k) then
        active_idx = wrap(1, active_idx-1, #items)
      elseif menu_down(k) then
        active_idx = wrap(1, active_idx+1, #items)
      elseif menu_enter(k) then
        return items[active_idx][2], items[active_idx][3]
      elseif menu_escape(k) then
        if active_idx == #items then
          return items[active_idx][2], items[active_idx][3]
        else
          active_idx = #items
        end
      end
    end
  end
end

function main_select_speed_99(next_func, ...)
  local difficulties = {"Easy", "Normal", "Hard"}
  local items = {{"Speed"},
                {"Difficulty"},
                {"Go!", next_func},
                {"Back", main_select_mode}}
  speed = config.endless_speed or 1
  difficulty = config.endless_difficulty or 1
  active_idx = 1
  local k = K[1]
  while true do
    local to_print, to_print2, arrow = "", "", ""
    for i=1,#items do
      if active_idx == i then
        arrow = arrow .. ">"
      else
        arrow = arrow .. "\n"
      end
      to_print = to_print .. "   " .. items[i][1] .. "\n"
    end
    to_print2 = "                  " .. speed .. "\n                  "
      .. difficulties[difficulty]
    gprint(arrow, 300, 280)
    gprint(to_print, 300, 280)
    gprint(to_print2, 300, 280)
    wait()
    if menu_up(k) then
      active_idx = wrap(1, active_idx-1, #items)
    elseif menu_down(k) then
      active_idx = wrap(1, active_idx+1, #items)
    elseif menu_right(k) then
      if active_idx==1 then speed = bound(1,speed+1,99)
      elseif active_idx==2 then difficulty = bound(1,difficulty+1,3) end
    elseif menu_left(k) then
      if active_idx==1 then speed = bound(1,speed-1,99)
      elseif active_idx==2 then difficulty = bound(1,difficulty-1,3) end
    elseif menu_enter(k) then
      if active_idx == 3 then
        if config.endless_speed ~= speed or config.endless_difficulty ~= difficulty then
          config.endless_speed = speed
          config.endless_difficulty = difficulty
          gprint("saving settings...", 300,280)
          wait()
          write_conf_file()
        end
        return items[active_idx][2], {speed, difficulty, ...}
      elseif active_idx == 4 then
        return items[active_idx][2], items[active_idx][3]
      else
        active_idx = wrap(1, active_idx + 1, #items)
      end
    elseif menu_escape(k) then
      if active_idx == #items then
        return items[active_idx][2], items[active_idx][3]
      else
        active_idx = #items
      end
    end
  end
end

function main_endless(...)
  consuming_timesteps = true
  replay.endless = {}
  local replay=replay.endless
  replay.pan_buf = ""
  replay.in_buf = ""
  replay.gpan_buf = ""
  replay.mode = "endless"
  P1 = Stack(1, "endless", ...)
  P1.do_countdown = config.ready_countdown_1P or false
  replay.do_countdown = P1.do_countdown or false
  replay.speed = P1.speed
  replay.difficulty = P1.difficulty
  make_local_panels(P1, "000000")
  make_local_gpanels(P1, "000000")
  P1:starting_state()
  while true do
    P1:render()
    wait()
    if P1.game_over then
    -- TODO: proper game over.
      write_replay_file()
      local end_text = "You scored "..P1.score.."\nin "..frames_to_time_string(P1.game_stopwatch, true)
        return main_dumb_transition, {main_select_mode, end_text, 60}
    end
    variable_step(function() P1:local_run() end)
    --groundhogday mode
    --[[if P1.CLOCK == 1001 then
      local prev_states = P1.prev_states
      P1 = prev_states[600]
      P1.prev_states = prev_states
    end--]]
  end
end

function main_time_attack(...)
  consuming_timesteps = true
  P1 = Stack(1, "time", ...)
  make_local_panels(P1, "000000")
  while true do
    P1:render()
    wait()
    if P1.game_over or (P1.game_stopwatch and P1.game_stopwatch == 120*60) then
    -- TODO: proper game over.
      local end_text = "You scored "..P1.score.."\nin "..frames_to_time_string(P1.game_stopwatch)
        return main_dumb_transition, {main_select_mode, end_text, 30}
    end
    variable_step(function()
      if (not P1.game_over)  and P1.game_stopwatch and P1.game_stopwatch < 120 * 60 then
        P1:local_run() end end)
  end
end

function main_net_vs_room()
  character_select_mode = "2p_net_vs"
  return main_character_select()
end

function main_character_select()
  love.audio.stop()
  local map = {}
  if character_select_mode == "2p_net_vs" then
    local opponent_connected = false
    local retries, retry_limit = 0, 500
    while not global_initialize_room_msg and retries < retry_limit do
      for _,msg in ipairs(this_frame_messages) do
        if msg.create_room or msg.character_select or msg.spectate_request_granted then
          global_initialize_room_msg = msg
        end
      end
      gprint("Waiting for room initialization...", 300, 280)
      wait()
      do_messages()
      retries = retries + 1
    end
    if room_number_last_spectated and retries >= retry_limit and currently_spectating then
      request_spectate(room_number_last_spectated)
      retries = 0
      while not global_initialize_room_msg and retries < retry_limit do
        for _,msg in ipairs(this_frame_messages) do
          if msg.create_room or msg.character_select or msg.spectate_request_granted then
            global_initialize_room_msg = msg
          end
        end
        gprint("Lost connection.  Trying to rejoin...", 300, 280)
        wait()
        do_messages()
        retries = retries + 1
      end
    end
    if not global_initialize_room_msg then
      return main_dumb_transition, {main_select_mode, "Failed to connect.\n\nReturning to main menu", 60, 300}
    end
    msg = global_initialize_room_msg
    global_initialize_room_msg = nil
    if msg.ratings then
        global_current_room_ratings = msg.ratings
    end
    global_my_state = msg.a_menu_state
    global_op_state = msg.b_menu_state
    if msg.your_player_number then
      my_player_number = msg.your_player_number
    elseif currently_spectating then
      my_player_number = 1
    elseif my_player_number and my_player_number ~= 0 then
      print("We assumed our player number is still "..my_player_number)
    else
      error("We never heard from the server as to what player number we are")
      print("Error: The server never told us our player number.  Assuming it is 1")
      my_player_number = 1
    end
    if msg.op_player_number then
      op_player_number = msg.op_player_number or op_player_number
    elseif currently_spectating then
      op_player_number = 2
    elseif op_player_number and op_player_number ~= 0 then
      print("We assumed op player number is still "..op_player_number)
    else
      error("We never heard from the server as to what player number we are")
      print("Error: The server never told us our player number.  Assuming it is 2")
      op_player_number = 2
    end
    if msg.win_counts then
      update_win_counts(msg.win_counts)
    end
    if msg.replay_of_match_so_far then
      replay_of_match_so_far = msg.replay_of_match_so_far
    end
    if msg.ranked then
      match_type = "Ranked"
      match_type_message = ""
    else 
      match_type = "Casual"
    end
    if currently_spectating then
      P1 = {panel_buffer="", gpanel_buffer=""}
      print("we reset P1 buffers at start of main_character_select()")
    end
    P2 = {panel_buffer="", gpanel_buffer=""}
    print("we reset P2 buffers at start of main_character_select()")
    print("current_server_supports_ranking: "..tostring(current_server_supports_ranking))
    local cursor,op_cursor,X,Y
    if current_server_supports_ranking then
      map = {{"match type desired", "match type desired", "match type desired", "match type desired", "level", "level", "ready"},
             {"random", "windy", "sherbet", "thiana", "ruby", "lip", "elias"},
             {"flare", "neris", "seren", "phoenix", "dragon", "thanatos", "cordelia"},
             {"lakitu", "bumpty", "poochy", "wiggler", "froggy", "blargg", "lungefish"},
             {"raphael", "yoshi", "hookbill", "navalpiranha", "kamek", "bowser", "leave"}}
    else
      map = {{"level", "level", "level", "level", "level", "level", "ready"},
             {"random", "windy", "sherbet", "thiana", "ruby", "lip", "elias"},
             {"flare", "neris", "seren", "phoenix", "dragon", "thanatos", "cordelia"},
             {"lakitu", "bumpty", "poochy", "wiggler", "froggy", "blargg", "lungefish"},
             {"raphael", "yoshi", "hookbill", "navalpiranha", "kamek", "bowser", "leave"}}
    end       
  end
  if character_select_mode == "1p_vs_yourself" then
    map = {{"level", "level", "level", "level", "level", "level", "ready"},
           {"random", "windy", "sherbet", "thiana", "ruby", "lip", "elias"},
           {"flare", "neris", "seren", "phoenix", "dragon", "thanatos", "cordelia"},
           {"lakitu", "bumpty", "poochy", "wiggler", "froggy", "blargg", "lungefish"},
           {"raphael", "yoshi", "hookbill", "navalpiranha", "kamek", "bowser", "leave"}}
  end
  local op_state = global_op_state or {character="lip", level=5, cursor="level", ready=false}
  global_op_state = nil
  cursor,op_cursor,X,Y = {1,1},{1,1},5,7
  local k = K[1]
  local up,down,left,right = {-1,0}, {1,0}, {0,-1}, {0,1}
  my_state = global_my_state or {character=config.character, level=config.level, cursor="level", ready=false}
  global_my_state = nil
  my_win_count = my_win_count or 0
  local prev_state = shallowcpy(my_state)
  op_win_count = op_win_count or 0
  if character_select_mode == "2p_net_vs" then
    global_current_room_ratings = global_current_room_ratings or {{new=0,old=0,difference=0},{new=0,old=0,difference=0}}
    my_expected_win_ratio = (100*round(1/(1+10^
          ((global_current_room_ratings[op_player_number].new
              -global_current_room_ratings[my_player_number].new)
            /rating_spread_modifier))
          ,2))
    op_expected_win_ratio = (100*round(1/(1+10^
          ((global_current_room_ratings[my_player_number].new
              -global_current_room_ratings[op_player_number].new)
            /rating_spread_modifier))
          ,2))
  end
  if character_select_mode == "2p_net_vs" then
    match_type = match_type or "Casual"
    if match_type == "" then match_type = "Casual" end
  end
  match_type_message = match_type_message or ""
  local selected = false
  local active_str = "level"
  local selectable = {level=true, ready=true}
  local function move_cursor(direction)
    local dx,dy = unpack(direction)
    local can_x,can_y = wrap(1, cursor[1]+dx, X), wrap(1, cursor[2]+dy, Y)
    while can_x ~= cursor[1] or can_y ~= cursor[2] do
      if map[can_x][can_y] and map[can_x][can_y] ~= map[cursor[1]][cursor[2]] then
        break
      end
      can_x,can_y = wrap(1, can_x+dx, X), wrap(1, can_y+dy, Y)
    end
    cursor[1],cursor[2] = can_x,can_y
  end
  local function do_leave()
    my_win_count = 0
    op_win_count = 0
    write_char_sel_settings_to_file()
    json_send({leave_room=true})
  end
  local name_to_xy = {}
  print("character_select_mode = "..(character_select_mode or "nil"))
  print("map[1][1] = "..(map[1][1] or "nil"))
  for i=1,X do
    for j=1,Y do
      if map[i][j] then
        name_to_xy[map[i][j]] = {i,j}
      end
    end
  end
  local function draw_button(x,y,w,h,str)
    local menu_width = Y*100
    local menu_height = X*80
    local spacing = 8
    local x_padding = math.floor((819-menu_width)/2)
    local y_padding = math.floor((612-menu_height)/2)
    set_color(unpack(colors.white))
    render_x = x_padding+(y-1)*100+spacing
    render_y = y_padding+(x-1)*100+spacing
    button_width = w*100-2*spacing
    button_height = h*100-2*spacing
    grectangle("line", render_x, render_y, button_width, button_height)
    if IMG_character_icons[character_display_names_to_original_names[str]] then
      local orig_w, orig_h = IMG_character_icons[character_display_names_to_original_names[str]]:getDimensions()
      menu_draw(IMG_character_icons[character_display_names_to_original_names[str]], render_x, render_y, 0, button_width/orig_w, button_height/orig_h )
    end
    local y_add,x_add = 10,30
    local pstr = str
    if str == "level" then
      if selected and active_str == "level" then
        pstr = pstr .. "\n"..my_name.."'s level: < "..my_state.level.." >"
      else
        pstr = pstr .. "\n"..my_name.."'s level: "..my_state.level
      end
      if character_select_mode == "2p_net_vs" then
        pstr = pstr .. "\n"..op_name.."'s level: "..op_state.level
      end
      y_add,x_add = 9,180
    end
    if str == "match type desired" then
      local my_type_selection, op_type_selection = "[casual]  ranked", "[casual]  ranked"
      if my_state.ranked then
        my_type_selection = " casual  [ranked]"
      end
      if op_state.ranked then
        op_type_selection = " casual  [ranked]"
      end
      pstr = pstr .. "\n"..my_name..": "..my_type_selection.."\n"..op_name..": "..op_type_selection
      y_add,x_add = 9,180
    end
    if my_state.cursor == str then pstr = pstr.."\n"..my_name end
    if op_state and op_name and op_state.cursor == str then pstr = pstr.."\n"..op_name end
    local cur_blink_frequency = 4
    local cur_pos_change_frequency = 8
    local player_num
    local draw_cur_this_frame = false
    local cursor_frame = 1
    if (character_select_mode == "2p_net_vs" or character_select_mode == "2p_local_vs")
    and op_state and op_state.cursor and (op_state.cursor == str or op_state.cursor == character_display_names_to_original_names[str]) then
      player_num = 2
      if op_state.ready then
        if (math.floor(menu_clock/cur_blink_frequency)+player_num)%2+1 == player_num then
          draw_cur_this_frame = true
          cursor_frame = 1
        else
          draw_cur_this_frame = false
        end
      else
        draw_cur_this_frame = true
        cursor_frame = (math.floor(menu_clock/cur_pos_change_frequency)+player_num)%2+1
        cur_img = IMG_char_sel_cursors[player_num][cursor_frame]
      end
      if draw_cur_this_frame then
        cur_img = IMG_char_sel_cursors[player_num][cursor_frame]
        cur_img_left = IMG_char_sel_cursor_halves.left[player_num][cursor_frame]
        cur_img_right = IMG_char_sel_cursor_halves.right[player_num][cursor_frame]
        local cur_img_w, cur_img_h = cur_img:getDimensions()
        local cursor_scale = (button_height+(spacing*2))/cur_img_h
        menu_drawq(cur_img, cur_img_left, render_x-spacing, render_y-spacing, 0, cursor_scale , cursor_scale)
        menu_drawq(cur_img, cur_img_right, render_x+button_width+spacing-cur_img_w*cursor_scale/2, render_y-spacing, 0, cursor_scale, cursor_scale)
      end
    end
    if my_state and my_state.cursor and (my_state.cursor == str or my_state.cursor == character_display_names_to_original_names[str]) then
      player_num = 1
      if my_state.ready then
        if (math.floor(menu_clock/cur_blink_frequency)+player_num)%2+1 == player_num then
          draw_cur_this_frame = true
          cursor_frame = 1
        else
          draw_cur_this_frame = false
        end
      else
        draw_cur_this_frame = true
        cursor_frame = (math.floor(menu_clock/cur_pos_change_frequency)+player_num)%2+1
        cur_img = IMG_char_sel_cursors[player_num][cursor_frame]
      end
      if draw_cur_this_frame then
        cur_img = IMG_char_sel_cursors[player_num][cursor_frame]
        cur_img_left = IMG_char_sel_cursor_halves.left[player_num][cursor_frame]
        cur_img_right = IMG_char_sel_cursor_halves.right[player_num][cursor_frame]
        local cur_img_w, cur_img_h = cur_img:getDimensions()
        local cursor_scale = (button_height+(spacing*2))/cur_img_h
        menu_drawq(cur_img, cur_img_left, render_x-spacing, render_y-spacing, 0, cursor_scale , cursor_scale)
        menu_drawq(cur_img, cur_img_right, render_x+button_width+spacing-cur_img_w*cursor_scale/2, render_y-spacing, 0, cursor_scale, cursor_scale)
      end
    end
    gprint(pstr, render_x+6, render_y+y_add)
  end
  print("got to LOC before net_vs_room character select loop")
  menu_clock = 0
  while true do
    menu_clock = menu_clock + 1
    if character_select_mode == "2p_net_vs" then
      for _,msg in ipairs(this_frame_messages) do
        if msg.win_counts then
          update_win_counts(msg.win_counts)
        end
        if msg.menu_state then
          if currently_spectating then
            if msg.player_number == 2 then
              op_state = msg.menu_state
            elseif msg.player_number == 1 then
              my_state = msg.menu_state
            end
          else
            op_state = msg.menu_state
          end
        end
        if msg.ranked_match_approved then
          match_type = "Ranked"
          match_type_message = ""
        elseif msg.ranked_match_denied then
          match_type = "Casual"
          match_type_message = "Not ranked. "
          if msg.reasons then
            match_type_message = match_type_message..(msg.reasons[1] or "Reason unknown")
          end
        end
        if msg.leave_room then
          my_win_count = 0
          op_win_count = 0
          write_char_sel_settings_to_file()
          return main_net_vs_lobby
        end
        if msg.match_start or replay_of_match_so_far then
          local fake_P1 = P1
          print("currently_spectating: "..tostring(currently_spectating))
          local fake_P2 = P2
          P1 = Stack(1, "vs", msg.player_settings.level, msg.player_settings.character, msg.player_settings.player_number)
          P2 = Stack(2, "vs", msg.opponent_settings.level, msg.opponent_settings.character, msg.opponent_settings.player_number)
          if currently_spectating then
            P1.panel_buffer = fake_P1.panel_buffer
            P1.gpanel_buffer = fake_P1.gpanel_buffer
          end
          P2.panel_buffer = fake_P2.panel_buffer
          P2.gpanel_buffer = fake_P2.gpanel_buffer
          P1.garbage_target = P2
          P2.garbage_target = P1
          P2.pos_x = 172
          P2.score_x = 410
          replay.vs = {P="",O="",I="",Q="",R="",in_buf="",
                      P1_level=P1.level,P2_level=P2.level,
                      P1_name=my_name, P2_name=op_name,
                      P1_char=P1.character,P2_char=P2.character,
                      ranked=msg.ranked}
          if currently_spectating and replay_of_match_so_far then --we joined a match in progress
            replay.vs = replay_of_match_so_far.vs
            P1.input_buffer = replay_of_match_so_far.vs.in_buf
            P1.panel_buffer = replay_of_match_so_far.vs.P
            P1.gpanel_buffer = replay_of_match_so_far.vs.Q
            P2.input_buffer = replay_of_match_so_far.vs.I
            P2.panel_buffer = replay_of_match_so_far.vs.O
            P2.gpanel_buffer = replay_of_match_so_far.vs.R
            if replay.vs.ranked then
              match_type = "Ranked"
              match_type_message = ""
            else 
              match_type = "Casual"
            end
            replay_of_match_so_far = nil
            P1.play_to_end = true  --this makes foreign_run run until caught up
            P2.play_to_end = true
          end
          if not currently_spectating then
              ask_for_gpanels("000000")
              ask_for_panels("000000")
          end
          to_print = "Game is starting!\n".."Level: "..P1.level.."\nOpponent's level: "..P2.level
          if P1.play_to_end or P2.play_to_end then
            to_print = "Joined a match in progress.\nCatching up..."
          end
          for i=1,30 do
            gprint(to_print,300, 280)
            do_messages()
            wait()
          end
          local game_start_timeout = 0
          while P1.panel_buffer == "" or P2.panel_buffer == ""
            or P1.gpanel_buffer == "" or P2.gpanel_buffer == "" do
            --testing getting stuck here at "Game is starting"
            game_start_timeout = game_start_timeout + 1
            print("game_start_timeout = "..game_start_timeout)
            print("P1.panel_buffer = "..P1.panel_buffer)
            print("P2.panel_buffer = "..P2.panel_buffer)
            print("P1.gpanel_buffer = "..P1.gpanel_buffer)
            print("P2.gpanel_buffer = "..P2.gpanel_buffer)
            gprint(to_print,300, 280)
            do_messages()
            wait()
            if game_start_timeout > 500 then
              return main_dumb_transition, {main_select_mode, 
                              "game-is-starting bug diagnostic version 2\n\ngame start timed out.\n Please screenshot this and\npost it in #panel-attack-bugs-features"
                              .."\n".."msg.match_start = "..(tostring(msg.match_start) or "nil")
                              .."\n".."replay_of_match_so_far = "..(tostring(replay_of_match_so_far) or "nil")
                              .."\n".."P1.panel_buffer = "..P1.panel_buffer
                              .."\n".."P2.panel_buffer = "..P2.panel_buffer
                              .."\n".."P1.gpanel_buffer = "..P1.gpanel_buffer
                              .."\n".."P2.gpanel_buffer = "..P2.gpanel_buffer,
                              600}
            end
          end
          P1:starting_state()
          P2:starting_state()
          return main_net_vs
        end
      end
    end
    if current_server_supports_ranking then
      draw_button(1,1,4,1,"match type desired")
      draw_button(1,5,2,1,"level")
    else
      draw_button(1,1,6,1,"level")
    end
    
    draw_button(1,7,1,1,"ready")
    for i=2,X do
      for j=1,Y do
        draw_button(i,j,1,1,character_display_names[map[i][j]] or map[i][j])
      end
    end
    local my_rating_difference = ""
    local op_rating_difference = ""
    if current_server_supports_ranking then
      if global_current_room_ratings[my_player_number].difference >= 0 then
        my_rating_difference = "(+"..global_current_room_ratings[my_player_number].difference..") "
      else
        my_rating_difference = "("..global_current_room_ratings[my_player_number].difference..") "
      end
      if global_current_room_ratings[op_player_number].difference >= 0 then
        op_rating_difference = "(+"..global_current_room_ratings[op_player_number].difference..") "
      else
        op_rating_difference = "("..global_current_room_ratings[op_player_number].difference..") "
      end
    end
    local state = ""
    --my state - add to be displayed
    state = state..my_name
    if current_server_supports_ranking then
        state = state..":  Rating: "..my_rating_difference..global_current_room_ratings[my_player_number].new
    end
    if character_select_mode == "2p_net_vs" or character_select_mode == "2p_local_vs" then
      state = state.."  Wins: "..my_win_count
    end
    if current_server_supports_ranking or my_win_count + op_win_count > 0 then
      state = state.."  Win Ratio:"
    end
    if my_win_count + op_win_count > 0 then
      state = state.."  actual: "..(100*round(my_win_count/(op_win_count+my_win_count),2)).."%"
    end
    if current_server_supports_ranking then
      state = state.."  expected: "
        ..my_expected_win_ratio.."%"
    end
    state = state.."  Char: "..character_display_names[my_state.character].."  Ready: "..tostring(my_state.ready or false)
    --state = state.." "..json.encode(my_state).."\n"
    if op_state and op_name then
      state = state.."\n"
      --op state - add to be displayed
      state = state..op_name
      if current_server_supports_ranking then
          state = state..":  Rating: "..op_rating_difference..global_current_room_ratings[op_player_number].new
      end
      state = state.."  Wins: "..op_win_count 
      if current_server_supports_ranking or my_win_count + op_win_count > 0 then
        state = state.."  Win Ratio:"
      end
      if my_win_count + op_win_count > 0 then
        state = state.."  actual: "..(100*round(op_win_count/(op_win_count+my_win_count),2)).."%"
      end
      if current_server_supports_ranking then
        state = state.."  expected: "
          ..op_expected_win_ratio.."%"
      end
      state = state.."  Char: "..character_display_names[op_state.character].."  Ready: "..tostring(op_state.ready or false)
      --state = state.." "..json.encode(op_state)
    end
    gprint(state, 50, 50)
    if character_select_mode == "2p_net_vs" then
      if not my_state.ranked and not op_state.ranked then
        match_type_message = ""
      end
      gprint(match_type, 375, 15)
      gprint(match_type_message,100,85)
    end
    wait()
    if not currently_spectating then
        if menu_up(k) then
          if not selected then move_cursor(up) end
        elseif menu_down(k) then
          if not selected then move_cursor(down) end
        elseif menu_left(k) then
          if selected and active_str == "level" then
            config.level = bound(1, config.level-1, 10)
          end
          if not selected then move_cursor(left) end
        elseif menu_right(k) then
          if selected and active_str == "level" then
            config.level = bound(1, config.level+1, 10)
          end
          if not selected then move_cursor(right) end
        elseif menu_enter(k) then
          if selectable[active_str] then
            selected = not selected
          elseif active_str == "leave" then
            if character_select_mode == "2p_net_vs" then
              do_leave()
            else
              return main_select_mode
            end
          elseif active_str == "random" then
            config.character = uniformly(characters)
          elseif active_str == "match type desired" then
            config.ranked = not config.ranked
          else
            config.character = active_str
            --When we select a character, move cursor to "ready"
            active_str = "ready"
            cursor = shallowcpy(name_to_xy["ready"])
          end
        elseif menu_escape(k) then
          if active_str == "leave" then
            if character_select_mode == "2p_net_vs" then
              do_leave()
            else
              return main_select_mode
            end
          end
          selected = false
          cursor = shallowcpy(name_to_xy["leave"])
        end
        active_str = map[cursor[1]][cursor[2]]
        my_state = {character=config.character, level=config.level, cursor=active_str, ranked=config.ranked,
                    ready=(selected and active_str=="ready")}
        if character_select_mode == "2p_net_vs" and not content_equal(my_state, prev_state) and not currently_spectating then
          json_send({menu_state=my_state})
        end
        prev_state = my_state
    else -- (we are are spectating)
        if menu_escape(k) then
          do_leave()
          return main_net_vs_lobby
        end
    end
    if my_state.ready and character_select_mode == "1p_vs_yourself" then
      P1 = Stack(1, "vs", my_state.level, my_state.character)
      P1.garbage_target = P1
      make_local_panels(P1, "000000")
      make_local_gpanels(P1, "000000")
      P1:starting_state()
      return main_dumb_transition, {main_local_vs_yourself, "Game is starting...", 30, 30}
    end
    if character_select_mode == "2p_net_vs" then 
      do_messages()
    end
  end
end

function main_net_vs_lobby()
  local active_name, active_idx, active_back = "", 1
  local items
  local unpaired_players = {} -- list
  local willing_players = {} -- set
  local spectatable_rooms = {}
  local k = K[1]
  my_player_number = nil
  op_player_number = nil
  local notice = {[true]="Select a player name to ask for a match.", [false]="You are all alone in the lobby :("}  
  local leaderboard_string = ""
  local my_rank
  love.audio.stop()
  match_type = ""
  match_type_message = ""
  --attempt login
  read_user_id_file()
  if not my_user_id then
    my_user_id = "need a new user id"
  end
  json_send({login_request=true, user_id=my_user_id}) 
  local login_status_message = "   Logging in..."
  local login_status_message_duration = 2
  local login_denied = false
  local prev_act_idx = active_idx
  local showing_leaderboard = false
  local lobby_menu_x = {[true]=100, [false]=300} --will be used to make room in case the leaderboard should be shown.
  while true do
      if connection_up_time <= login_status_message_duration then
        gprint(login_status_message, lobby_menu_x[showing_leaderboard], 160)
        for _,msg in ipairs(this_frame_messages) do
            if msg.login_successful then
              current_server_supports_ranking = true
              logged_in = true
              if msg.new_user_id then
                my_user_id = msg.new_user_id
                print("about to write user id file")
                write_user_id_file()
                login_status_message = "Welcome, new user: "..my_name
              elseif msg.name_changed then
                login_status_message = "Welcome, your username has been updated. \n\nOld name:  \""..msg.old_name.."\"\n\nNew name:  \""..msg.new_name.."\""
                login_status_message_duration = 5
              else
                login_status_message = "Welcome back, "..my_name
              end
            elseif msg.login_denied then
                current_server_supports_ranking = true
                login_denied = true
                --TODO: create a menu here to let the user choose "continue unranked" or "get a new user_id"
                --login_status_message = "Login for ranked matches failed.\n"..msg.reason.."\n\nYou may continue unranked,\nor delete your invalid user_id file to have a new one assigned."
                login_status_message_duration = 10
                return main_dumb_transition, {main_select_mode, "Error message received from the server:\n\n"..json.encode(msg),60,600}
            end
        end
        if connection_up_time == 2 and not current_server_supports_ranking then
                login_status_message = "Login for ranked matches timed out.\nThis server probably doesn't support ranking.\n\nYou may continue unranked."
                login_status_message_duration = 7
        end
      end
    for _,msg in ipairs(this_frame_messages) do
      if msg.choose_another_name and msg.choose_another_name.used_names then
        return main_dumb_transition, {main_select_mode, "Error: name is taken :<\n\nIf you had just left the server,\nit may not have realized it yet, try joining again.\n\nThis can also happen if you have two\ninstances of Panel Attack open.\n\nPress Swap or Back to continue.", 60, 600}
      elseif msg.choose_another_name and msg.choose_another_name.reason then
        return main_dumb_transition, {main_select_mode, "Error: ".. msg.choose_another_name.reason, 60}
      end
      if msg.create_room or msg.spectate_request_granted then
        global_initialize_room_msg = msg
        character_select_mode = "2p_net_vs"
        return main_character_select
      end
      if msg.unpaired then
        unpaired_players = msg.unpaired
        -- players who leave the unpaired list no longer have standing invitations to us.
        local new_willing = {}
        for _,player in ipairs(unpaired_players) do
          new_willing[player] = willing_players[player]
        end
        willing_players = new_willing
      end
      if msg.spectatable then
        spectatable_rooms = msg.spectatable
      end
      if msg.game_request then
        willing_players[msg.game_request.sender] = true
      end
      if msg.leaderboard_report then
        showing_leaderboard = true
        leaderboard_report = msg.leaderboard_report
        for k,v in ipairs(leaderboard_report) do
          if v.is_you then
            my_rank = k
          end
        end
        leaderboard_first_idx_to_show = math.max((my_rank or 1)-8,1)
        leaderboard_last_idx_to_show = math.min(leaderboard_first_idx_to_show + 20,#leaderboard_report)
        leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
      end
    end
    local to_print = ""
    local arrow = ""
    items = {}
    for _,v in ipairs(unpaired_players) do
      if v ~= config.name then
        items[#items+1] = v
      end
    end
    local lastPlayerIndex = #items --the rest of the items will be spectatable rooms, except the last two items (leaderboard and back to main menu)
    for _,v in ipairs(spectatable_rooms) do
      items[#items+1] = v
    end
    if showing_leaderboard then
      items[#items+1] = "Hide Leaderboard"
    else
      items[#items+1] = "Show Leaderboard"  -- the second to last item is "Leaderboard"
    end
    items[#items+1] = "Back to main menu" -- the last item is "Back to the main menu"
    if active_back then
      active_idx = #items
    elseif showing_leaderboard then
      active_idx = #items - 1 --the position of the "hide leaderboard" menu item
    else
      while active_idx > #items do
        print("active_idx > #items.  Decrementing active_idx")
        active_idx = active_idx - 1
      end
      active_name = items[active_idx]
    end
    for i=1,#items do
      if active_idx == i then
        arrow = arrow .. ">"
      else
        arrow = arrow .. "\n"
      end
      if i <= lastPlayerIndex then
        to_print = to_print .. "   " .. items[i] .. (willing_players[items[i]] and " (Wants to play with you :o)" or "") .. "\n"
      elseif i < #items - 1 and items[i].name then
        to_print = to_print .. "   spectate " .. items[i].name .. " (".. items[i].state .. ")\n" --printing room names 
      elseif i < #items then
        to_print = to_print .. "   " .. items[i] .. "\n"
      else
        to_print = to_print .. "   " .. items[i]
      end
    end
    gprint(notice[#items > 2], lobby_menu_x[showing_leaderboard], 250)
    gprint(arrow, lobby_menu_x[showing_leaderboard], 280)
    gprint(to_print, lobby_menu_x[showing_leaderboard], 280)
    if showing_leaderboard then
      gprint(leaderboard_string, 500, 160)
    end
    
    wait()
    if menu_up(k) then
      if showing_leaderboard then
        if leaderboard_first_idx_to_show>1 then
          leaderboard_first_idx_to_show = leaderboard_first_idx_to_show - 1
          leaderboard_last_idx_to_show = leaderboard_last_idx_to_show - 1    
          leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
        end
      else
        active_idx = wrap(1, active_idx-1, #items)
      end
    elseif menu_down(k) then
      if showing_leaderboard then
        if leaderboard_last_idx_to_show < #leaderboard_report then
          leaderboard_first_idx_to_show = leaderboard_first_idx_to_show + 1
          leaderboard_last_idx_to_show = leaderboard_last_idx_to_show + 1
          leaderboard_string = build_viewable_leaderboard_string(leaderboard_report, leaderboard_first_idx_to_show, leaderboard_last_idx_to_show)
        end
      else
        active_idx = wrap(1, active_idx+1, #items)
      end
    elseif menu_enter(k) then
      spectator_list = {}
      spectators_string = ""
      if active_idx == #items then
        return main_select_mode
      end
      if active_idx == #items - 1 then
        if not showing_leaderboard then
          json_send({leaderboard_request=true})
        else
          showing_leaderboard = false --toggle it off
        end
      elseif active_idx <= lastPlayerIndex then
        my_name = config.name
        op_name = items[active_idx]
        currently_spectating = false
        request_game(items[active_idx])
      else
        my_name = items[active_idx].a
        op_name = items[active_idx].b
        currently_spectating = true
        room_number_last_spectated = items[active_idx].roomNumber
        request_spectate(items[active_idx].roomNumber)
      end
    elseif menu_escape(k) then
      if active_idx == #items then
        return main_select_mode
      elseif showing_leaderboard then
        showing_leaderboard = false
      else
        active_idx = #items
      end
    end
    active_back = active_idx == #items
    if active_idx ~= prev_act_idx then
      print("#items: "..#items.."  idx_old: "..prev_act_idx.."  idx_new: "..active_idx.."  active_back: "..tostring(active_back))
      prev_act_idx = active_idx
    end
    do_messages()
  end
end

function update_win_counts(win_counts)
  if (P1 and P1.player_number == 1) or currently_spectating then
    my_win_count = win_counts[1] or 0
    op_win_count = win_counts[2] or 0
  elseif P1.player_number == 2 then
    my_win_count = win_counts[2] or 0
    op_win_count = win_counts[1] or 0
  end
end

function spectator_list_string(list)
  local str = ""
  for k,v in ipairs(list) do
    str = str..v
    if k<#list then
      str = str.."\n"
    end
  end
  if str ~= "" then
    str = "Spectator(s):\n"..str
  end
  return str
end

function build_viewable_leaderboard_string(report, first_viewable_idx, last_viewable_idx)
  str = "        Leaderboard\n      Rank    Rating   Player\n"
  first_viewable_idx = math.max(first_viewable_idx,1)
  last_viewable_idx = math.min(last_viewable_idx, #report)
  for i=first_viewable_idx,last_viewable_idx do
    if report[i].is_you then
      str = str.."You-> "
    else
      str = str.."      "
    end
    str = str..i.."    "..report[i].rating.."    "..report[i].user_name
    if i < #report then
      str = str.."\n"
    end
  end
  return str
end

function main_net_vs_setup(ip)
  if not config.name then
    return main_set_name
    else my_name = config.name
  end
  P1, P1_level, P2_level, got_opponent = nil
  P2 = {panel_buffer="", gpanel_buffer=""}
  gprint("Setting up connection...", 300, 280)
  wait()
  network_init(ip)
  local timeout_counter = 0
  while not connection_is_ready() do
    gprint("Connecting...", 300, 280)
    wait()
    do_messages()
  end
  connected_server_ip = ip
  logged_in = false
  if true then return main_net_vs_lobby end
  local my_level, to_print, fake_P2 = 5, nil, P2
  local k = K[1]
  while got_opponent == nil do
    gprint("Waiting for opponent...", 300, 280)
    wait()
    do_messages()
  end
  while P1_level == nil or P2_level == nil do
    to_print = (P1_level and "L" or"Choose l") .. "evel: "..my_level..
        "\nOpponent's level: "..(P2_level or "???")
    gprint(to_print, 300, 280)
    wait()
    do_messages()
    if P1_level then
    elseif menu_enter(k) then
      P1_level = my_level
      net_send("L"..(({[10]=0})[my_level] or my_level))
    elseif menu_up(k) or menu_right(k) then
      my_level = bound(1,my_level+1,10)
    elseif menu_down(k) or menu_left(k) then
      my_level = bound(1,my_level-1,10)
    end
  end
  P1 = Stack(1, "vs", P1_level)
  P2 = Stack(2, "vs", P2_level)
  if currently_spectating then
    P1.panel_buffer = fake_P1.panel_buffer
    P1.gpanel_buffer = fake_P1.gpanel_buffer
  end
  P2.panel_buffer = fake_P2.panel_buffer
  P2.gpanel_buffer = fake_P2.gpanel_buffer
  P1.garbage_target = P2
  P2.garbage_target = P1
  P2.pos_x = 172
  P2.score_x = 410
  replay.vs = {P="",O="",I="",Q="",R="",in_buf="",
              P1_level=P1_level,P2_level=P2_level,
              ranked=false, P1_name=my_name, P2_name=op_name,
              P1_char=P1.character, P2_char=P2.character,
              do_countdown = true}
  ask_for_gpanels("000000")
  ask_for_panels("000000")
  if not currently_spectating then
    to_print = "Level: "..my_level.."\nOpponent's level: "..(P2_level or "???")
  else
    to_print = "P1 Level: "..my_level.."\nP2 level: "..(P2_level or "???")
  end
  for i=1,30 do
    gprint(to_print,300, 280)
    do_messages()
    wait()
  end
  while P1.panel_buffer == "" or P2.panel_buffer == ""
    or P1.gpanel_buffer == "" or P2.gpanel_buffer == "" do
    gprint(to_print,300, 280)
    do_messages()
    wait()
  end
  P1:starting_state()
  P2:starting_state()
  return main_net_vs
end

function main_net_vs()
  --STONER_MODE = true
  local k = K[1]  --may help with spectators leaving games in progress
  local end_text = nil
  consuming_timesteps = true
  local op_name_y = 40
  if string.len(my_name) > 12 then
        op_name_y = 55
  end
  while true do
    -- Uncomment this to cripple your game :D
    -- love.timer.sleep(0.030)
    for _,msg in ipairs(this_frame_messages) do
      if msg.leave_room then
        write_char_sel_settings_to_file()
        return main_net_vs_lobby
      end
    end
    gprint(my_name or "", 315, 40)
    gprint(op_name or "", 410, op_name_y)
    gprint("Wins: "..my_win_count, 315, 70)
    gprint("Wins: "..op_win_count, 410, 70)
    if not config.debug_mode then --this is printed in the same space as the debug details
      gprint(spectators_string, 315, 265)
    end
    if match_type == "Ranked" then
      if global_current_room_ratings[my_player_number] 
      and global_current_room_ratings[my_player_number].new then
        gprint("Rating: "..global_current_room_ratings[my_player_number].new, 315, 85)
      end
      if global_current_room_ratings[op_player_number] 
      and global_current_room_ratings[op_player_number].new then
        gprint("Rating: "..global_current_room_ratings[op_player_number].new, 410, 85)
      end
    end
    if not (P1 and P1.play_to_end) and not (P2 and P2.play_to_end) then
      P1:render()
      P2:render()
      wait()
      if currently_spectating and this_frame_keys["escape"] then
        print("spectator pressed escape during a game")
        my_win_count = 0
        op_win_count = 0
        json_send({leave_room=true})
        return main_net_vs_lobby
      end
      do_messages()
    end
    
    print(P1.CLOCK, P2.CLOCK)
    if (P1 and P1.play_to_end) or (P2 and P2.play_to_end) then
      if not P1.game_over then
        if currently_spectating then
          P1:foreign_run()
        else
          P1:local_run() 
        end
      end
    else
      variable_step(function()
        if not P1.game_over then
          if currently_spectating then
              P1:foreign_run()
          else
            P1:local_run() 
          end
        end
      end)
    end
    if not P2.game_over then
      P2:foreign_run()
    end
    local outcome_claim = nil
    if P1.game_over and P2.game_over and P1.CLOCK == P2.CLOCK then
      end_text = "Draw"
      outcome_claim = 0
    elseif P1.game_over and P1.CLOCK <= P2.CLOCK then
      end_text = op_name.." Wins :("
      op_win_count = op_win_count + 1 -- leaving these in just in case used with an old server that doesn't keep score.  win_counts will get overwritten after this by the server anyway.
      outcome_claim = P2.player_number
    elseif P2.game_over and P2.CLOCK <= P1.CLOCK then
      end_text = my_name.." Wins ^^"
      my_win_count = my_win_count + 1 -- leave this in
      outcome_claim = P1.player_number
      
    end
    if end_text then
      undo_stonermode()
      json_send({game_over=true, outcome=outcome_claim})
      local now = os.date("*t",to_UTC(os.time()))
      local sep = "/"
      local path = "replays"..sep.."v"..VERSION..sep..string.format("%04d"..sep.."%02d"..sep.."%02d", now.year, now.month, now.day)
      local rep_a_name, rep_b_name = my_name, op_name
      --sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
      if rep_b_name <  rep_a_name then
        path = path..sep..rep_b_name.."-vs-"..rep_a_name
      else
        path = path..sep..rep_a_name.."-vs-"..rep_b_name
      end
      local filename = "v"..VERSION.."-"..string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec).."-"..rep_a_name.."-L"..P1.level.."-vs-"..rep_b_name.."-L"..P2.level
      if match_type and match_type ~= "" then
        filename = filename.."-"..match_type
      end
      if outcome_claim == 1 or outcome_claim == 2 then
        filename = filename.."-P"..outcome_claim.."wins"
      elseif outcome_claim == 0 then
        filename = filename.."-draw"
      end
      filename = filename..".txt"
      print("saving replay as "..path..sep..filename)
      write_replay_file(path, filename)
      print("also saving replay as replay.txt")
      write_replay_file()
      character_select_mode = "2p_net_vs"
      if currently_spectating then
        return main_dumb_transition, {main_character_select, end_text, 45, 45}
      else
        return main_dumb_transition, {main_character_select, end_text, 45, 180}
      end
    end
  end
end

main_local_vs_setup = multi_func(function()
  local K = K
  local chosen, maybe = {}, {5,5}
  local P1_level, P2_level = nil, nil
  while chosen[1] == nil or chosen[2] == nil do
    to_print = (chosen[1] and "" or "Choose ") .. "P1 level: "..maybe[1].."\n"
        ..(chosen[2] and "" or "Choose ") .. "P2 level: "..(maybe[2])
    gprint(to_print, 300, 280)
    wait()
    for i=1,2 do
      local k=K[i]
      if menu_escape(k) then
        if chosen[i] then
          chosen[i] = nil
        else
          return main_select_mode
        end
      elseif menu_enter(k) then
        chosen[i] = maybe[i]
      elseif menu_up(k) or menu_right(k) then
        if not chosen[i] then
          maybe[i] = bound(1,maybe[i]+1,10)
        end
      elseif menu_down(k) or menu_left(k) then
        if not chosen[i] then
          maybe[i] = bound(1,maybe[i]-1,10)
        end
      end
    end
  end
  to_print = "P1 level: "..maybe[1].."\nP2 level: "..(maybe[2])
  P1 = Stack(1, "vs", chosen[1])
  P2 = Stack(2, "vs", chosen[2])
  P1.garbage_target = P2
  P2.garbage_target = P1
  P2.pos_x = 172
  P2.score_x = 410
  -- TODO: this does not correctly implement starting configurations.
  -- Starting configurations should be identical for visible blocks, and
  -- they should not be completely flat.
  --
  -- In general the block-generation logic should be the same as the server's, so
  -- maybe there should be only one implementation.
  make_local_panels(P1, "000000")
  make_local_gpanels(P1, "000000")
  make_local_panels(P2, "000000")
  make_local_gpanels(P2, "000000")
  for i=1,30 do
    gprint(to_print,300, 280)
    wait()
  end
  P1:starting_state()
  P2:starting_state()
  return main_local_vs
end)

function main_local_vs()
  -- TODO: replay!
  consuming_timesteps = true
  local end_text = nil
  while true do
    P1:render()
    P2:render()
    wait()
    variable_step(function()
        if not P1.game_over and not P2.game_over then
          P1:local_run()
          P2:local_run()
        end
      end)
    if P1.game_over and P2.game_over and P1.CLOCK == P2.CLOCK then
      end_text = "Draw"
    elseif P1.game_over and P1.CLOCK <= P2.CLOCK then
      end_text = "P2 wins ^^"
    elseif P2.game_over and P2.CLOCK <= P1.CLOCK then
      end_text = "P1 wins ^^"
    end
    if end_text then
      return main_dumb_transition, {main_select_mode, end_text, 45}
    end
  end
end

function main_local_vs_yourself_setup()
  my_name = config.name or "Player 1"
  op_name = nil
  op_state = nil
  character_select_mode = "1p_vs_yourself"
  return main_character_select
end

function main_local_vs_yourself()
  -- TODO: replay!
  consuming_timesteps = true
  local end_text = nil
  while true do
    P1:render()
    wait()
    variable_step(function()
        if not P1.game_over then
          P1:local_run()
        else 
          end_text = "Game Over"
        end
      end)
    if end_text then
      return main_dumb_transition, {main_character_select, end_text, 45}
    end
  end
end

function main_replay_vs()
  local replay = replay.vs
  P1 = Stack(1, "vs", replay.P1_level or 5)
  P2 = Stack(2, "vs", replay.P2_level or 5)
  P1.do_countdown = replay.do_countdown or false
  P2.do_countdown = replay.do_countdown or false
  P1.ice = true
  P1.garbage_target = P2
  P2.garbage_target = P1
  P2.pos_x = 172
  P2.score_x = 410
  P1.input_buffer = replay.in_buf
  P1.panel_buffer = replay.P
  P1.gpanel_buffer = replay.Q
  P2.input_buffer = replay.I
  P2.panel_buffer = replay.O
  P2.gpanel_buffer = replay.R
  P1.max_runs_per_frame = 1
  P2.max_runs_per_frame = 1
  P1.character = replay.P1_char
  P2.character = replay.P2_char
  my_name = replay.P1_name or "Player 1"
  op_name = replay.P2_name or "Player 2"
  if character_select_mode == "2p_net_vs" then
    if replay.ranked then
      match_type = "Ranked"
    else
      match_type = "Casual"
    end
  end

  P1:starting_state()
  P2:starting_state()
  local end_text = nil
  local run = true
  local op_name_y = 40
  if string.len(my_name) > 12 then
    op_name_y = 55
  end
  while true do
    mouse_panel = nil
    gprint(my_name or "", 315, 40)
    gprint(op_name or "", 410, op_name_y)
    P1:render()
    P2:render()
    if mouse_panel then
      local str = "Panel info:\nrow: "..mouse_panel[1].."\ncol: "..mouse_panel[2]
      for k,v in spairs(mouse_panel[3]) do
        str = str .. "\n".. k .. ": "..tostring(v)
      end
      gprint(str, 350, 400)
    end
    wait()
    if this_frame_keys["escape"] then
      return main_select_mode
    end
    if this_frame_keys["return"] then
      run = not run
    end
    if this_frame_keys["\\"] then
      run = false
    end
    if run or this_frame_keys["\\"] then
      if not P1.game_over then
        P1:foreign_run()
      end
      if not P2.game_over then
        P2:foreign_run()
      end
    end
    if P1.game_over and P2.game_over and P1.CLOCK == P2.CLOCK then
      end_text = "Draw"
    elseif P1.game_over and P1.CLOCK <= P2.CLOCK then
      if replay.P2_name and replay.P2_name ~= "anonymous" then
        end_text = replay.P2_name.." wins"
      else
        end_text = "P2 wins"
      end
    elseif P2.game_over and P2.CLOCK <= P1.CLOCK then
      if replay.P1_name and replay.P1_name ~= "anonymous" then
        end_text = replay.P1_name.." wins"
      else
        end_text = "P1 wins"
      end
    end
    if end_text then
      return main_dumb_transition, {main_select_mode, end_text}
    end
  end
end

function main_replay_endless()
  local replay = replay.endless
  if replay == nil or replay.speed == nil then
    return main_dumb_transition,
      {main_select_mode, "I don't have an endless replay :("}
  end
  P1 = Stack(1, "endless", replay.speed, replay.difficulty)
  P1.do_countdown = replay.do_countdown or false
  P1.max_runs_per_frame = 1
  P1.input_buffer = table.concat({replay.in_buf})
  P1.panel_buffer = replay.pan_buf
  P1.gpanel_buffer = replay.gpan_buf
  P1.speed = replay.speed
  P1.difficulty = replay.difficulty
  local run = true
  while true do
    P1:render()
    wait()
    if this_frame_keys["escape"] then
      return main_select_mode
    end
    if this_frame_keys["return"] then
      run = not run
    end
    if this_frame_keys["\\"] then
      run = false
    end
    if run or this_frame_keys["\\"] then
      if P1.game_over then
      -- TODO: proper game over.
        local end_text = "You scored "..P1.score.."\nin "..frames_to_time_string(P1.game_stopwatch, true)
        return main_dumb_transition, {main_select_mode, end_text, 30}
      end
      P1:foreign_run()
    end
  end
end

function main_replay_puzzle()
  local replay = replay.puzzle
  if replay.in_buf == nil or replay.in_buf == "" then
    return main_dumb_transition,
      {main_select_mode, "I don't have a puzzle replay :("}
  end
  P1 = Stack(1, "puzzle")
  P1.do_countdown = replay.do_countdown or false
  P1.max_runs_per_frame = 1
  P1.input_buffer = replay.in_buf
  P1:set_puzzle_state(unpack(replay.puzzle))
  local run = true
  while true do
    mouse_panel = nil
    P1:render()
    if mouse_panel then
      local str = "Panel info:\nrow: "..mouse_panel[1].."\ncol: "..mouse_panel[2]
      for k,v in spairs(mouse_panel[3]) do
        str = str .. "\n".. k .. ": "..tostring(v)
      end
      gprint(str, 350, 400)
    end
    wait()
    if this_frame_keys["escape"] then
      return main_select_mode
    end
    if this_frame_keys["return"] then
      run = not run
    end
    if this_frame_keys["\\"] then
      run = false
    end
    if run or this_frame_keys["\\"] then
      if P1.n_active_panels == 0 and
          P1.prev_active_panels == 0 then
        if P1:puzzle_done() then
          return main_dumb_transition, {main_select_mode, "You win!"}
        elseif P1.puzzle_moves == 0 then
          return main_dumb_transition, {main_select_mode, "You lose :("}
        end
      end
      P1:foreign_run()
    end
  end
end

function make_main_puzzle(puzzles)
  local awesome_idx, ret = 1, nil
  function ret()
    consuming_timesteps = true
    replay.puzzle = {}
    local replay = replay.puzzle
    P1 = Stack(1, "puzzle")
    P1.do_countdown = config.ready_countdown_1P or false
    local start_delay = 0
    if awesome_idx == nil then
      awesome_idx = math.random(#puzzles)
    end
    P1:set_puzzle_state(unpack(puzzles[awesome_idx]))
    replay.puzzle = puzzles[awesome_idx]
    replay.in_buf = ""
    while true do
      P1:render()
      wait()
      if P1.n_active_panels == 0 and
          P1.prev_active_panels == 0 then
        if P1:puzzle_done() then
          awesome_idx = (awesome_idx % #puzzles) + 1
          write_replay_file()
          if awesome_idx == 1 then
            return main_dumb_transition, {main_select_puzz, "You win!", 30}
          else
            return main_dumb_transition, {ret, "You win!", 30}
          end
        elseif P1.puzzle_moves == 0 then
          write_replay_file()
          return main_dumb_transition, {main_select_puzz, "You lose :(", 30}
        end
      end
      variable_step(function() 
        if P1.n_active_panels ~= 0 or P1.prev_active_panels ~= 0 or
          P1.puzzle_moves ~= 0 then P1:local_run() end end)
    end
  end
  return ret
end

do
  local items = {}
  for key,val in spairs(puzzle_sets) do
    items[#items+1] = {key, make_main_puzzle(val)}
  end
  items[#items+1] = {"Back", main_select_mode}
  function main_select_puzz()
    local active_idx = 1
    local k = K[1]
    while true do
      local to_print = ""
      local arrow = ""
      for i=1,#items do
        if active_idx == i then
          arrow = arrow .. ">"
        else
          arrow = arrow .. "\n"
        end
        to_print = to_print .. "   " .. items[i][1] .. "\n"
      end
      gprint(arrow, 300, 280)
      gprint(to_print, 300, 280)
      wait()
      if menu_up(k) then
        active_idx = wrap(1, active_idx-1, #items)
      elseif menu_down(k) then
        active_idx = wrap(1, active_idx+1, #items)
      elseif menu_enter(k) then
        return items[active_idx][2], items[active_idx][3]
      elseif menu_escape(k) then
        if active_idx == #items then
          return items[active_idx][2], items[active_idx][3]
        else
          active_idx = #items
        end
      end
    end
  end
end

function main_config_input()
  local pretty_names = {"Up", "Down", "Left", "Right", "A", "B", "L", "R"}
  local items, active_idx = {}, 1
  local k = K[1]
  local active_player = 1
  local function get_items()
    items = {[0]={"Player ", ""..active_player}}
    for i=1,#key_names do
      items[#items+1] = {pretty_names[i], k[key_names[i]] or "none"}
    end
    items[#items+1] = {"Set all keys", ""}
    items[#items+1] = {"Back", "", main_select_mode}
  end
  local function print_stuff()
    local to_print, to_print2, arrow = "", "", ""
    for i=0,#items do
      if active_idx == i then
        arrow = arrow .. ">"
      else
        arrow = arrow .. "\n"
      end
      to_print = to_print .. "   " .. items[i][1] .. "\n"
      to_print2 = to_print2 .. "                  " .. items[i][2] .. "\n"
    end
    gprint(arrow, 300, 280)
    gprint(to_print, 300, 280)
    gprint(to_print2, 300, 280)
  end
  local function set_key(idx)
    local brk = false
    while not brk do
      get_items()
      items[idx][2] = "___"
      print_stuff()
      wait()
      for key,val in pairs(this_frame_keys) do
        if val then
          k[key_names[idx]] = key
          brk = true
        end
      end
    end
  end
  while true do
    get_items()
    print_stuff()
    wait()
    if menu_up(K[1]) then
      active_idx = wrap(1, active_idx-1, #items)
    elseif menu_down(K[1]) then
      active_idx = wrap(1, active_idx+1, #items)
    elseif menu_left(K[1]) then
      active_player = wrap(1, active_player-1, 2)
      k=K[active_player]
    elseif menu_right(K[1]) then
      active_player = wrap(1, active_player+1, 2)
      k=K[active_player]
    elseif menu_enter(K[1]) then
      if active_idx <= #key_names then
        set_key(active_idx)
        write_key_file()
      elseif active_idx == #key_names + 1 then
        for i=1,8 do
          set_key(i)
          write_key_file()
        end
      else
        return items[active_idx][3], items[active_idx][4]
      end
    elseif menu_escape(K[1]) then
      if active_idx == #items then
        return items[active_idx][3], items[active_idx][4]
      else
        active_idx = #items
      end
    end
  end
end

function main_options()
  local items, active_idx = {}, 1
  local k = K[1]
  local selected, deselected_this_frame, adjust_active_value = false, false, false
  local function get_items()
  local save_replays_publicly_choices = {"with my name", "anonymously", "not at all"}
  assets_dir_before_options_menu = config.assets_dir or default_assets_dir
  sounds_dir_before_options_menu = config.sounds_dir or default_sounds_dir
  --make so we can get "anonymously" from save_replays_publicly_choices["anonymously"]
  for k,v in ipairs(save_replays_publicly_choices) do
    save_replays_publicly_choices[v] = v
  end
  local raw_assets_dir_list = love.filesystem.getDirectoryItems("assets")
  local asset_sets = {}
  for k,v in ipairs(raw_assets_dir_list) do
    if love.filesystem.isDirectory("assets/"..v) and v ~= "Example folder structure" then
      asset_sets[#asset_sets+1] = v
    end
  end
  local raw_sounds_dir_list = love.filesystem.getDirectoryItems("sounds")
  local sound_sets = {}
  for k,v in ipairs(raw_sounds_dir_list) do
    if love.filesystem.isDirectory("sounds/"..v) and v ~= "Example folder structure" then
      sound_sets[#sound_sets+1] = v
    end
  end
  print("asset_sets:")
  for k,v in ipairs(asset_sets) do
    print(v)
  end
    items = {
    --options menu table reference:
    --{[1]"Option Name", [2]current or default value, [3]type, [4]min or bool value or choices_table,
    -- [5]max, [6]sound_source, [7]selectable, [8]next_func, [9]play_while selected}
      {"Master Volume", config.master_volume or 100, "numeric", 0, 100, sounds.music.characters["lip"].normal_music, true, nil, true},
      {"SFX Volume", config.SFX_volume or 100, "numeric", 0, 100, sounds.SFX.cur_move, true},
      {"Music Volume", config.music_volume or 100, "numeric", 0, 100, sounds.music.characters["lip"].normal_music, true, nil, true},
      {"Debug Mode", debug_mode_text[config.debug_mode or false], "bool", false, nil, nil,false},
      {"Save replays publicly", 
        save_replays_publicly_choices[config.save_replays_publicly]
          or save_replays_publicly_choices["with my name"],
        "multiple choice", save_replays_publicly_choices},
      {"Graphics set", config.assets_dir or default_assets_dir, "multiple choice", asset_sets},
      {"About custom graphics", "", "function", nil, nil, nil, nil, show_custom_graphics_readme},
      {"Sounds set", config.sounds_dir or default_sounds_dir, "multiple choice", sound_sets},
      {"About custom sounds", "", "function", nil, nil, nil, nil, show_custom_sounds_readme},
      {"Ready countdown", ready_countdown_1P_text[config.ready_countdown_1P or false], "bool", true, nil, nil,false},
      {"Back", "", nil, nil, nil, nil, false, main_select_mode}
    }
  end
  local function print_stuff()
    local to_print, to_print2, arrow = "", "", ""
    for i=1,#items do
      if active_idx == i then
        arrow = arrow .. ">"
      else
        arrow = arrow .. "\n"
      end
      to_print = to_print .. "   " .. items[i][1] .. "\n"
      to_print2 = to_print2 .. "                  " 
      if active_idx == i and selected then  
        to_print2 = to_print2 .. "                < "
      else
        to_print2 = to_print2 .. "                  "
      end
      to_print2 = to_print2.. items[i][2] 
      if active_idx == i and selected then
        to_print2 = to_print2 .. " >"
      end
      to_print2 = to_print2 .. "\n"
    end
    gprint(arrow, 300, 280)
    gprint(to_print, 300, 280)
    gprint(to_print2, 300, 280)
  end
  local function adjust_left()
    if items[active_idx][3] == "numeric" then
      if items[active_idx][2] > items[active_idx][4] then --value > minimum
        items[active_idx][2] = items[active_idx][2] - 1
      end
    elseif items[active_idx][3] == "multiple choice" then
      adjust_backwards = true
      adjust_active_value = true
    end
    --the following is enough for "bool"
    adjust_active_value = true
    if items[active_idx][6] and not items[active_idx][9] then
    --sound_source for this menu item exists and not play_while_selected
      items[active_idx][6]:stop()
      items[active_idx][6]:play()
    end
  end
  local function adjust_right()
    if items[active_idx][3] == "numeric" then
      if items[active_idx][2] < items[active_idx][5] then --value < maximum
        items[active_idx][2] = items[active_idx][2] + 1
      end
    elseif items[active_idx][3] == "multiple choice" then
      adjust_active_value = true
    end
    --the following is enough for "bool"
    adjust_active_value = true
    if items[active_idx][6] and not items[active_idx][9] then 
    --sound_source for this menu item exists and not play_while_selected
      items[active_idx][6]:stop()
      items[active_idx][6]:play()
    end
  end
  get_items()
  local do_menu_function = false
  while true do
    --get_items()
    print_stuff()
    wait()
    if menu_up(K[1]) and not selected then
      active_idx = wrap(1, active_idx-1, #items)
    elseif menu_down(K[1]) and not selected then
      active_idx = wrap(1, active_idx+1, #items)
    elseif menu_left(K[1]) and (selected or not items[active_idx][7]) then --or not selectable
      adjust_left()
    elseif menu_right(K[1]) and (selected or not items[active_idx][7]) then --or not selectable
      adjust_right()
    elseif menu_enter(K[1]) then
      if items[active_idx][7] then --is selectable
        selected = not selected
        if not selected then
          deselected_this_frame = true
          adjust_active_value = true
        end
      elseif items[active_idx][3] == "bool" or items[active_idx][3] == "multiple choice" then
        adjust_active_value = true
      elseif items[active_idx][3] == "function" then
        do_menu_function = true
      elseif active_idx == #items then
        return exit_options_menu
      end
    elseif menu_escape(K[1]) then
      if selected then
        selected = not selected
        deselected_this_frame = true
      elseif active_idx == #items then
        return exit_options_menu
      else
        active_idx = #items
      end
    end
    if adjust_active_value then
      if items[active_idx][3] == "bool" then
        if active_idx == 4 then
          config.debug_mode = not config.debug_mode
          items[active_idx][2] = debug_mode_text[config.debug_mode or false]
        end
        if items[active_idx][1] == "Ready countdown" then
          config.ready_countdown_1P = not config.ready_countdown_1P
          items[active_idx][2] = ready_countdown_1P_text[config.ready_countdown_1P]
        end
        --add any other bool config updates here
      elseif items[active_idx][3] == "numeric" then
        if config.master_volume ~= items[1][2] then
          config.master_volume = items[1][2]
          love.audio.setVolume(config.master_volume/100)
        end
        if config.SFX_volume ~= items[2][2] then --SFX volume should be updated
          config.SFX_volume = items[2][2]
          items[2][6]:setVolume(config.SFX_volume/100) --do just the one sound effect until we deselect
        end
        if active_idx == 2 and deselected_this_frame then --SFX Volume
          set_volume(sounds.SFX, config.SFX_volume/100)
        end
        if config.music_volume ~= items[3][2] then --music volume should be updated
          config.music_volume = items[3][2]
          items[3][6]:setVolume(config.music_volume/100) --do just the one music source until we deselect
        end
        if active_idx == 3 and deselected_this_frame then --Music Volume
          set_volume(sounds.music, config.music_volume/100) 
        end
        --add any other numeric config updates here
      elseif items[active_idx][3] == "multiple choice" then
        local active_choice_num = 1
        --find the key for the currently selected choice
        for k,v in ipairs(items[active_idx][4]) do
          if v == items[active_idx][2] then
            active_choice_num = k
          end
        end
        -- the next line of code means
        -- current_choice_num = choices[wrap(1, next_choice_num, last_choice_num)]
        if adjust_backwards then
          items[active_idx][2] = items[active_idx][4][wrap(1,active_choice_num - 1, #items[active_idx][4])]
          adjust_backwards = nil
        else
          items[active_idx][2] = items[active_idx][4][wrap(1,active_choice_num + 1, #items[active_idx][4])]
        end
        if active_idx == 5 then
          config.save_replays_publicly = items[active_idx][2]
        elseif active_idx == 6 then
          config.assets_dir = items[active_idx][2]
        elseif active_idx == 8 then
          config.sounds_dir = items[active_idx][2]
        end
        --add any other multiple choice config updates here
      end
      adjust_active_value = false
    end
    if items[active_idx][3] == "function" and do_menu_function then
      if items[active_idx][1] == "About custom graphics" then
        if not love.filesystem.isDirectory("assets/Example folder structure")then
          print("Hold on.  Copying an example folder to make this easier...\n This make take a few seconds.")
          gprint("Hold on.  Copying an example folder to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
          wait()
          recursive_copy("assets/"..default_assets_dir, "assets/Example folder structure")
        end
        local custom_graphics_readme = read_txt_file("Custom Graphics Readme.txt")
        while true do
          gprint(custom_graphics_readme, 100, 150)      
          do_menu_function = false
          wait()
          if menu_escape(K[1]) or menu_enter(K[1]) then
            break;
          end
        end
      end
      if items[active_idx][1] == "About custom sounds" then
        if not love.filesystem.isDirectory("sounds/Example folder structure")then
          print("Hold on.  Copying an example folder to make this easier...\n This make take a few seconds.")
          gprint("Hold on.  Copying an example folder to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
          wait()
          recursive_copy("sounds/"..default_sounds_dir, "sounds/Example folder structure")
        end
        local custom_sounds_readme = read_txt_file("Custom Sounds Readme.txt")
        while true do
          gprint(custom_sounds_readme, 30, 150)      
          do_menu_function = false
          wait()
          if menu_escape(K[1]) or menu_enter(K[1]) then
            break;
          end
        end
      end
    end
    if selected and items[active_idx][9] and items[active_idx][6] and not items[active_idx][6]:isPlaying() then
    --if selected and play_while_selected and sound source exists and it isn't playing
      items[active_idx][6]:play()
    end
    if deselected_this_frame then
      if items[active_idx][6] then --sound_source for this menu item exists 
        items[active_idx][6]:stop()
        love.audio.stop()
      end
      deselected_this_frame = false
    end
  end
end

function exit_options_menu()
  gprint("writing config to file...", 300,280)
  wait()
  write_conf_file()
  if config.assets_dir ~= assets_dir_before_options_menu then
    gprint("reloading graphics...", 300, 305)
    wait()
    graphics_init()
  end
  assets_dir_before_options_menu = nil
  if config.sounds_dir ~= sounds_dir_before_options_menu then
    gprint("reloading sounds...", 300, 305)
    wait()
    sound_init()
  end
  sounds_dir_before_options_menu = nil
  return main_select_mode
end

function main_set_name()
  local name = ""
  while true do
    local to_print = "Enter your name:\n"..name
    gprint(to_print, 300, 280)
    wait()
    if this_frame_keys["escape"] then
      return main_select_mode
    end
    if this_frame_keys["return"] or this_frame_keys["kenter"] then
      config.name = name
      write_conf_file()
      return main_select_mode
    end
    for _,v in ipairs(this_frame_unicodes) do
      name = name .. v
    end
  end
end

function fullscreen()
  love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
  return main_select_mode
end

function main_dumb_transition(next_func, text, timemin, timemax)
  if P1 and P1.character then 
    stop_character_sounds(P1.character)
  end
  if P2 and P2.character then 
    stop_character_sounds(P2.character)
  end
  love.audio.stop()
  if not SFX_mute and SFX_GameOver_Play == 1 then
    sounds.SFX.game_over:play()
  end
  SFX_GameOver_Play = 0

  text = text or ""
  timemin = timemin or 0
  timemax = timemax or 3600
  local t = 0
  local k = K[1]
  while true do
    -- for _,msg in ipairs(this_frame_messages) do
      -- if next_func == main_character_select then
        -- if msg.menu_state then
          -- if currently_spectating then
            -- if msg.menu_state.player_number == 1 then
              -- global_my_state = msg.menu_state
            -- elseif msg.menu_state.player_number == 2 then
              -- global_op_state = msg.menu_state
            -- end
          -- else
            -- global_op_state = msg.menu_state
          -- end
        -- end
        -- if msg.win_counts then
          -- update_win_counts(msg.win_counts)
        -- end
        -- if msg.rating_updates then
          -- global_current_room_ratings = msg.ratings
        -- end
      -- end
      -- --TODO: anything else we should be listening for during main_dumb_transition?
    -- end
    gprint(text, 300, 280)
    wait()
    if t >= timemin and (t >=timemax or (menu_enter(k) or menu_escape(k))) then
      return next_func
    end
    t = t + 1
    if TCP_sock then
    --  do_messages()
    end
  end
end

function write_char_sel_settings_to_file()
  if not currently_spectating and my_state then
    gprint("saving character select settings...")
    if not closing then
      wait()
    end
    config.character = my_state.character
    config.level = my_state.level
    config.ranked = my_state.ranked
    write_conf_file()
  end
end

function love.quit()
  closing = true
  write_char_sel_settings_to_file()
end

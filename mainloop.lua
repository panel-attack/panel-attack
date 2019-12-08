local utf8 = require("utf8")

local wait, resume = coroutine.yield, coroutine.resume

local main_select_mode, main_endless, make_main_puzzle, main_net_vs_setup,
  main_replay_endless, main_replay_puzzle, main_net_vs,
  main_config_input, main_dumb_transition, main_select_puzz,
  menu_up, menu_down, menu_left, menu_right, menu_enter, menu_escape, menu_backspace,
  main_replay_vs, main_local_vs_setup, main_local_vs, menu_key_func,
  multi_func, normal_key, main_set_name, main_character_select, main_net_vs_lobby,
  main_local_vs_yourself_setup, main_local_vs_yourself,
  main_options, exit_options_menu, main_music_test, exit_game

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
leftover_time = 0

local main_menu_screen_pos = { 300 + (canvas_width-legacy_canvas_width)/2, 280 + (canvas_height-legacy_canvas_height)/2 }

function fmainloop()
  local func, arg = main_select_mode, nil
  replay = {}
  -- Default configuration values
  config = {
             -- The lastly used version
             version                       = VERSION,
             -- Player character
             character                     = "lip",
             -- Vsync
             vsync                         = true,
             -- Level (2P modes / 1P vs yourself mode)
             level                         = 5,
             endless_speed                 = 1,
             endless_difficulty            = 1,
             -- Player name
             name                          = "defaultname",
             -- Volume settings
             master_volume                 = 100,
             SFX_volume                    = 100,
             music_volume                  = 100,
             -- Debug mode flag
             debug_mode                    = false,
             -- Show FPS in the top-left corner of the screen
             show_fps                      = false,
             -- Enable ready countdown flag
             ready_countdown_1P            = true,
             -- Change danger music back later flag
             danger_music_changeback_delay = false,
             -- analytics
             enable_analytics              = false,
             -- Save replays setting
             save_replays_publicly         = "with my name",
             -- Default directories for graphics/panels/sounds
             assets_dir                    = default_assets_dir,
             sounds_dir                    = default_sounds_dir,

             panels_dir                    = default_assets_dir,
             -- Retrocompatibility, please remove whenever possible, it's so ugly!
             panels_dir_when_not_using_set_from_assets_folder = default_panels_dir,
             use_panels_from_assets_folder = true,

             -- Retrocompatibility
             use_default_characters        = false,
           }
  gprint("Reading config file", unpack(main_menu_screen_pos))
  wait()
  read_conf_file() -- TODO: stop making new config files
  local x,y, display = love.window.getPosition()
  love.window.setPosition(
    config.window_x or x,
    config.window_y or y,
    config.display or display)
  gprint("Copying Puzzles Readme")
  wait()
  copy_file("Custom Puzzles Readme.txt", "puzzles/README.txt")
  gprint("Reading replay file", unpack(main_menu_screen_pos))
  wait()
  read_replay_file()
  gprint("Preloading characters...", unpack(main_menu_screen_pos))
  wait()
  characters_init() -- load images and set up stuff
  gprint("Loading graphics...", unpack(main_menu_screen_pos))
  wait()
  graphics_init() -- load images and set up stuff
  gprint("Loading panels...", unpack(main_menu_screen_pos))
  wait()
  panels_init() -- load panels
  gprint("Loading sounds...", unpack(main_menu_screen_pos))
  wait()
  sound_init()
  gprint("Loading analytics...", unpack(main_menu_screen_pos))
  wait()
  analytics_init()
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
      joystick_ax()
      f()
      key_counts()
      this_frame_keys = {}
      this_frame_unicodes = {}
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

function menu_key_func(fixed, configurable, rept, sound)
  sound = sound or nil
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
    if res and sound ~= nil then
      play_optional_sfx(sound())
    end
    return res
  end
end

menu_up = menu_key_func({"up"}, {"up"}, true, function() return sounds.SFX.menu_move end )
menu_down = menu_key_func({"down"}, {"down"}, true, function() return sounds.SFX.menu_move end)
menu_left = menu_key_func({"left"}, {"left"}, true, function() return sounds.SFX.menu_move end)
menu_right = menu_key_func({"right"}, {"right"}, true, function() return sounds.SFX.menu_move end)
menu_enter = menu_key_func({"return","kenter","z"}, {"swap1"}, false, function() return sounds.SFX.menu_validate end)
menu_escape = menu_key_func({"escape","x"}, {"swap2"}, false, function() return sounds.SFX.menu_cancel end)
menu_prev_page = menu_key_func({"pageup"}, {"raise1"}, true, function() return sounds.SFX.menu_move end)
menu_next_page = menu_key_func({"pagedown"}, {"raise2"}, true, function() return sounds.SFX.menu_move end)
menu_backspace = menu_key_func({"backspace"}, {"backspace"}, true)

do
  local active_idx = 1
  function main_select_mode()
    love.audio.stop()
    currently_spectating = false
    stop_the_music()
    character_loader_clear()
    close_socket()
    bg = title
    logged_in = 0
    connection_up_time = 0
    connected_server_ip = ""
    current_server_supports_ranking = false
    match_type = ""
    match_type_message = ""
    local items = {
        {"1P endless", main_select_speed_99, {main_endless}},
        {"1P puzzle", main_select_puzz},
        {"1P time attack", main_select_speed_99, {main_time_attack}},
        {"1P vs yourself", main_local_vs_yourself_setup},
        --{"2P vs online at burke.ro", main_net_vs_setup, {"burke.ro"}},
        {"2P vs online at Jon's server", main_net_vs_setup, {"18.188.43.50"}},
        --{"2P vs online at betaserver.panelattack.com", main_net_vs_setup, {"betaserver.panelattack.com"}},
        --{"2P vs online (USE ONLY WITH OTHER CLIENTS ON THIS TEST BUILD 025beta)", main_net_vs_setup, {"18.188.43.50"}},
        --{"This test build is for offline-use only"--[["2P vs online at Jon's server"]], main_select_mode},
        --{"2P vs online at domi1819.xyz (Europe, beta for spectating and ranking)", main_net_vs_setup, {"domi1819.xyz"}},
        --{"2P vs online at localhost (development-use only)", main_net_vs_setup, {"localhost"}},
        --{"2P vs online at LittleEndu's server", main_net_vs_setup, {"51.15.207.223"}},
        {"2P vs local game", main_local_vs_setup},
        {"Replay of 1P endless", main_replay_endless},
        {"Replay of 1P puzzle", main_replay_puzzle},
        {"Replay of 2P vs", main_replay_vs},
        {"Configure input", main_config_input},
        {"Set name", main_set_name},
        {"Options", main_options},
        {"Music test", main_music_test}
    }
    if love.graphics.getSupported("canvas") then
      items[#items+1] = {"Fullscreen (LAlt+Enter)", fullscreen}
    else
      items[#items+1] = {"Your graphics card doesn't support canvases for fullscreen", main_select_mode}
    end
    items[#items+1] = {"Quit", exit_game }
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
      gprint(arrow, unpack(main_menu_screen_pos))
      gprint(to_print, unpack(main_menu_screen_pos))
      wait()
      local ret = nil
      variable_step(function()
        if menu_up(k) then
          active_idx = wrap(1, active_idx-1, #items)
        elseif menu_down(k) then
          active_idx = wrap(1, active_idx+1, #items)
        elseif menu_enter(k) then
          ret = {items[active_idx][2], items[active_idx][3]}
        elseif menu_escape(k) then
          if active_idx == #items then
            ret = {items[active_idx][2], items[active_idx][3]}
          else
            active_idx = #items
          end
        end
      end)
      if ret then
        return unpack(ret)
      end
    end
  end
end

function main_select_speed_99(next_func, ...)
  local difficulties = {"Easy", "Normal", "Hard", "EX Mode"}
  local items = {{"Speed"},
                {"Difficulty"},
                {"Go!", next_func},
                {"Back", main_select_mode}}
  local speed = config.endless_speed or 1
  local difficulty = config.endless_difficulty or 1
  local active_idx = 1
  local k = K[1]
  local ret = nil
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
    gprint(arrow, unpack(main_menu_screen_pos))
    gprint(to_print, unpack(main_menu_screen_pos))
    gprint(to_print2, unpack(main_menu_screen_pos))
    wait()
    variable_step(function()
      if menu_up(k) then
        active_idx = wrap(1, active_idx-1, #items)
      elseif menu_down(k) then
        active_idx = wrap(1, active_idx+1, #items)
      elseif menu_right(k) then
        if active_idx==1 then speed = bound(1,speed+1,99)
        elseif active_idx==2 then difficulty = bound(1,difficulty+1,4) end
      elseif menu_left(k) then
        if active_idx==1 then speed = bound(1,speed-1,99)
        elseif active_idx==2 then difficulty = bound(1,difficulty-1,4) end
      elseif menu_enter(k) then
        if active_idx == 3 then
          if config.endless_speed ~= speed or config.endless_difficulty ~= difficulty then
            config.endless_speed = speed
            config.endless_difficulty = difficulty
            gprint("saving settings...", unpack(main_menu_screen_pos))
            wait()
            write_conf_file()
          end
          ret = {items[active_idx][2], {speed, difficulty}}
        elseif active_idx == 4 then
          ret = {items[active_idx][2], items[active_idx][3]}
        else
          active_idx = wrap(1, active_idx + 1, #items)
        end
      elseif menu_escape(k) then
        if active_idx == #items then
          ret = {items[active_idx][2], items[active_idx][3]}
        else
          active_idx = #items
        end
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function main_endless(...)
  bg = IMG_stages[math.random(#IMG_stages)]
  consuming_timesteps = true
  replay.endless = {}
  local replay=replay.endless
  replay.pan_buf = ""
  replay.in_buf = ""
  replay.gpan_buf = ""
  replay.mode = "endless"
  P1 = Stack(1, "endless", config.panels_dir, ...)
  P1.do_countdown = config.ready_countdown_1P or false
  P1.enable_analytics = true
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
      analytics_game_ends()
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
  bg = IMG_stages[math.random(#IMG_stages)]
  consuming_timesteps = true
  P1 = Stack(1, "time", config.panels_dir, ...)
  P1.enable_analytics = true
  make_local_panels(P1, "000000")
  P1:starting_state()
  while true do
    P1:render()
    wait()
    if P1.game_over or (P1.game_stopwatch and P1.game_stopwatch == 120*60) then
    -- TODO: proper game over.
      local end_text = "You scored "..P1.score.."\nin "..frames_to_time_string(P1.game_stopwatch)
      analytics_game_ends()
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

-- fills the provided map based on the provided template and return the amount of pages. __Empty values will be replaced by character_ids
local function fill_map(template_map,map)
  local X,Y = 5,7
  local pages_amount = 0
  local character_id_index = 1
  while true do
    -- new page handling
    pages_amount = pages_amount+1
    map[pages_amount] = deepcpy(template_map)

    -- go through the page and replace __Empty with characters_ids_for_current_theme
    for i=1,X do
      for j=1,Y do
        if map[pages_amount][i][j] == "__Empty" then
          map[pages_amount][i][j] = characters_ids_for_current_theme[character_id_index]
          character_id_index = character_id_index+1
          -- end case: no more characters_ids_for_current_theme to add
          if character_id_index == #characters_ids_for_current_theme+1 then
            print("filled "..#characters_ids_for_current_theme.." characters across "..pages_amount.." page(s)")
            return pages_amount
          end
        end
      end
    end
  end
end

local fallback_when_missing = nil

local function refresh_based_on_own_mods(refreshed,ask_change_fallback)
  ask_change_fallback = ask_change_fallback or false
  if refreshed ~= nil then
    if refreshed.panels_dir == nil or IMG_panels[refreshed.panels_dir] == nil then
      refreshed.panels_dir = config.panels_dir
    end
    if characters[refreshed.character] == nil then
      if refreshed.character_display_name and characters_ids_by_display_names[refreshed.character_display_name] then
        refreshed.character = characters_ids_by_display_names[refreshed.character_display_name][1]
      else
        if not fallback_when_missing or ask_change_fallback then
          fallback_when_missing = uniformly(characters_ids_for_current_theme)
        end
        refreshed.character = fallback_when_missing
      end
    end
  end
end

local current_page = 1

function main_character_select()
  love.audio.stop()
  stop_the_music()
  bg = charselect
  fallback_when_missing = nil

  local function add_client_data(state)
    state.loaded = characters[state.character] and characters[state.character].fully_loaded
    state.wants_ready = state.ready
  end

  local function refresh_loaded_and_ready(state_1,state_2)
    state_1.loaded = characters[state_1.character] and characters[state_1.character].fully_loaded
    state_2.loaded = characters[state_2.character] and characters[state_2.character].fully_loaded
    
    if character_select_mode == "2p_net_vs" then
      state_1.ready = state_1.wants_ready and state_1.loaded and state_2.loaded
    else
      state_1.ready = state_1.wants_ready and state_1.loaded
      state_2.ready = state_2.wants_ready and state_2.loaded
    end
  end

  print("character_select_mode = "..(character_select_mode or "nil"))


  -- map is composed of special values prefixed by __ and character ids
  local template_map = {}
  local map = {}
  if character_select_mode == "2p_net_vs" then
    local opponent_connected = false
    local retries, retry_limit = 0, 250
    while not global_initialize_room_msg and retries < retry_limit do
      for _,msg in ipairs(this_frame_messages) do
        if msg.create_room or msg.character_select or msg.spectate_request_granted then
          global_initialize_room_msg = msg
        end
      end
      gprint("Waiting for room initialization...", unpack(main_menu_screen_pos))
      wait()
      if not do_messages() then
        return main_dumb_transition, {main_select_mode, "Disconnected from server.\n\nReturning to main menu...", 60, 300}
      end
      retries = retries + 1
    end
    -- if room_number_last_spectated and retries >= retry_limit and currently_spectating then
      -- request_spectate(room_number_last_spectated)
      -- retries = 0
      -- while not global_initialize_room_msg and retries < retry_limit do
        -- for _,msg in ipairs(this_frame_messages) do
          -- if msg.create_room or msg.character_select or msg.spectate_request_granted then
            -- global_initialize_room_msg = msg
          -- end
        -- end
        -- gprint("Lost connection.  Trying to rejoin...", unpack(main_menu_screen_pos))
        -- wait()
        -- if not do_messages() then
        --   return main_dumb_transition, {main_select_mode, "Disconnected from server.\n\nReturning to main menu...", 60, 300}
        -- end
        -- retries = retries + 1
      -- end
    -- end
    if not global_initialize_room_msg then
      return main_dumb_transition, {main_select_mode, "Room initialization failed.\n\nReturning to main menu...", 60, 300}
    end
    msg = global_initialize_room_msg
    global_initialize_room_msg = nil
    if msg.ratings then
        global_current_room_ratings = msg.ratings
    end

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

    if my_player_number == 2 and msg.a_menu_state ~= nil and msg.b_menu_state ~= nil then
      print("inverting the states to match player number!")
      msg.a_menu_state, msg.b_menu_state = msg.b_menu_state, msg.a_menu_state
    end

    global_my_state = msg.a_menu_state
    refresh_based_on_own_mods(global_my_state)
    global_op_state = msg.b_menu_state
    refresh_based_on_own_mods(global_op_state)

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

    if current_server_supports_ranking then
      template_map = {{"__Mode", "__Mode", "__Level", "__Level", "__Panels", "__Panels", "__Ready"},
             {"__Random", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Leave"}}
    else
      template_map = {{"__Level", "__Level", "__Level", "__Panels", "__Panels", "__Panels", "__Ready"},
             {"__Random", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Leave"}}
    end
  end
  if character_select_mode == "2p_local_vs" or character_select_mode == "1p_vs_yourself" then
    template_map = {{"__Level", "__Level", "__Level", "__Panels", "__Panels", "__Panels", "__Ready"},
             {"__Random", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty"},
             {"__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Empty", "__Leave"}}
  end

  local pages_amount = fill_map(template_map, map)
  if current_page > pages_amount then
    current_page = 1
  end

  op_win_count = op_win_count or 0

  if character_select_mode == "2p_net_vs" then
    global_current_room_ratings = global_current_room_ratings or {{new=0,old=0,difference=0},{new=0,old=0,difference=0}}
    my_expected_win_ratio = nil
    op_expected_win_ratio = nil
    print("my_player_number = "..my_player_number)
    print("op_player_number = "..op_player_number)
    if global_current_room_ratings[my_player_number].new
    and global_current_room_ratings[my_player_number].new ~= 0
    and global_current_room_ratings[op_player_number]
    and global_current_room_ratings[op_player_number].new ~= 0 then
      my_expected_win_ratio = (100*round(1/(1+10^
            ((global_current_room_ratings[op_player_number].new
                -global_current_room_ratings[my_player_number].new)
              /RATING_SPREAD_MODIFIER))
            ,2))
      op_expected_win_ratio = (100*round(1/(1+10^
            ((global_current_room_ratings[my_player_number].new
                -global_current_room_ratings[op_player_number].new)
              /RATING_SPREAD_MODIFIER))
            ,2))
    end
    match_type = match_type or "Casual"
    if match_type == "" then match_type = "Casual" end
  end

  match_type_message = match_type_message or ""

  local function do_leave()
    my_win_count = 0
    op_win_count = 0
    return json_send({leave_room=true})
  end

  -- be wary: name_to_xy_per_page is kinda buggy for larger blocks as they span multiple positions (we retain the last one), and is completely broken with __Empty
  local name_to_xy_per_page = {}
  local X,Y = 5,7
  for p=1,pages_amount do
    name_to_xy_per_page[p] = {}
    for i=1,X do
      for j=1,Y do
        if map[p][i][j] then
          name_to_xy_per_page[p][map[p][i][j]] = {i,j}
        end
      end
    end
  end

  my_win_count = my_win_count or 0

  local cursor_data = {{position=shallowcpy(name_to_xy_per_page[current_page]["__Ready"]),selected=false},{position=shallowcpy(name_to_xy_per_page[current_page]["__Ready"]),selected=false}}
  if global_my_state ~= nil then
    cursor_data[1].state = shallowcpy(global_my_state)
    global_my_state = nil
  else
    cursor_data[1].state = {character=config.character, character_display_name=characters[config.character].display_name, level=config.level, panels_dir=config.panels_dir, cursor="__Ready", ready=false, ranked=config.ranked}
  end
  if global_op_state ~= nil then
    cursor_data[2].state = shallowcpy(global_op_state)
    if character_select_mode ~= "2p_local_vs" then
      global_op_state = nil -- retains state of the second player, also: don't unload its character when going back and forth
    end
  else
    cursor_data[2].state = {character=config.character, character_display_name=characters[config.character].display_name, level=config.level, panels_dir=config.panels_dir, cursor="__Ready", ready=false, ranked=false}
  end
  add_client_data(cursor_data[1].state)
  add_client_data(cursor_data[2].state)
  refresh_loaded_and_ready(cursor_data[1].state, cursor_data[2].state)

  local prev_state = shallowcpy(cursor_data[1].state)

  local function draw_button(x,y,w,h,str,halign,valign,no_rect)
    no_rect = no_rect or str == "__Empty"
    halign = halign or "center"
    valign = valign or "top"
    local menu_width = Y*100
    local menu_height = X*80
    local spacing = 8
    local text_height = 13
    local x_padding = math.floor((canvas_width-menu_width)/2)
    local y_padding = math.floor((canvas_height-menu_height)/2)
    set_color(unpack(colors.white))
    render_x = x_padding+(y-1)*100+spacing
    render_y = y_padding+(x-1)*100+spacing
    button_width = w*100-2*spacing
    button_height = h*100-2*spacing
    if no_rect == false then
      grectangle("line", render_x, render_y, button_width, button_height)
    end
    local character = characters[str]
    if str == "P1" then
      character = characters[cursor_data[1].state.character]
    elseif str == "P2" then
      character = characters[cursor_data[2].state.character]
    end
    local width_for_alignment = button_width
    local x_add,y_add = 0,0
    if valign == "center" then
      y_add = math.floor(0.5*button_height-0.5*text_height)-3
    elseif valign == "bottom" then
      y_add = math.floor(button_height-text_height)
    end
    if character and character.images["icon"] then
      x_add = 0.025*button_width
      width_for_alignment = 0.95*button_width
      local orig_w, orig_h = character.images["icon"]:getDimensions()
      local scale = button_width/math.max(orig_w,orig_h) -- keep image ratio
      menu_drawf(character.images["icon"], render_x+0.5*button_width, render_y+0.5*button_height,"center","center", 0, scale, scale )
    end

    local function draw_cursor(button_height, spacing, player_num,ready)
      local cur_blink_frequency = 4
      local cur_pos_change_frequency = 8
      local draw_cur_this_frame = false
      local cursor_frame = 1
      if ready then
        if (math.floor(menu_clock/cur_blink_frequency)+player_num)%2+1 == player_num then
          draw_cur_this_frame = true
        end
      else
        draw_cur_this_frame = true
        cursor_frame = (math.floor(menu_clock/cur_pos_change_frequency)+player_num)%2+1
      end
      if draw_cur_this_frame then
        local cur_img = IMG_char_sel_cursors[player_num][cursor_frame]
        local cur_img_left = IMG_char_sel_cursor_halves.left[player_num][cursor_frame]
        local cur_img_right = IMG_char_sel_cursor_halves.right[player_num][cursor_frame]
        local cur_img_w, cur_img_h = cur_img:getDimensions()
        local cursor_scale = (button_height+(spacing*2))/cur_img_h
        menu_drawq(cur_img, cur_img_left, render_x-spacing, render_y-spacing, 0, cursor_scale , cursor_scale)
        menu_drawq(cur_img, cur_img_right, render_x+button_width+spacing-cur_img_w*cursor_scale/2, render_y-spacing, 0, cursor_scale, cursor_scale)
      end
    end

    local function draw_player_state(cursor_data,player_number)
      if characters[cursor_data.state.character] and not characters[cursor_data.state.character].fully_loaded then
        menu_drawf(IMG_loading, render_x+button_width*0.5, render_y+button_height*0.5, "center", "center" )
      elseif cursor_data.state.wants_ready then
        menu_drawf(IMG_ready, render_x+button_width*0.5, render_y+button_height*0.5, "center", "center" )
      end
      local scale = 0.25*button_width/math.max(IMG_players[player_number]:getWidth(),IMG_players[player_number]:getHeight()) -- keep image ratio
      menu_drawf(IMG_players[player_number], render_x+1, render_y+button_height-1, "left", "bottom", 0, scale, scale )
      scale = 0.25*button_width/math.max(IMG_levels[cursor_data.state.level]:getWidth(),IMG_levels[cursor_data.state.level]:getHeight()) -- keep image ratio
      menu_drawf(IMG_levels[cursor_data.state.level], render_x+button_width-1, render_y+button_height-1, "right", "bottom", 0, scale, scale )
    end

    local function draw_panels(cursor_data,player_number,y_padding)
      local panels_max_width = 0.25*button_height
      local panels_width = math.min(panels_max_width,IMG_panels[cursor_data.state.panels_dir][1][1]:getWidth())
      local padding_x = 0.5*button_width-3*panels_width -- center them, not 3.5 mysteriously?
      if cursor_data.state.level >= 9 then
        padding_x = padding_x-0.5*panels_width
      end
      local is_selected = cursor_data.selected and cursor_data.state.cursor == "__Panels"
      if is_selected then
        padding_x = padding_x-panels_width
      end
      local panels_scale = panels_width/IMG_panels[cursor_data.state.panels_dir][1][1]:getWidth()
      menu_drawf(IMG_players[player_number], render_x+padding_x, render_y+y_padding, "center", "center" )
      padding_x = padding_x + panels_width
      if is_selected then
        gprintf("<", render_x+padding_x-0.5*panels_width, render_y+y_padding-0.5*text_height,panels_width,"center")
        padding_x = padding_x + panels_width
      end
      for i=1,8 do
        if i ~= 7 and (i ~= 6 or cursor_data.state.level >= 9) then
          menu_drawf(IMG_panels[cursor_data.state.panels_dir][i][1], render_x+padding_x, render_y+y_padding, "center", "center", 0, panels_scale, panels_scale )
          padding_x = padding_x + panels_width
        end
      end
      if is_selected then
        gprintf(">", render_x+padding_x-0.5*panels_width, render_y+y_padding-0.5*text_height,panels_width,"center")
      end
    end

    local function draw_levels(cursor_data,player_number,y_padding)
      local level_max_width = 0.2*button_height
      local level_width = math.min(level_max_width,IMG_levels[1]:getWidth())
      local padding_x = 0.5*button_width-6*level_width
      local is_selected = cursor_data.selected and cursor_data.state.cursor == "__Level"
      if is_selected then
        padding_x = padding_x-level_width
      end
      local level_scale = level_width/IMG_levels[1]:getWidth()
      menu_drawf(IMG_players[player_number], render_x+padding_x, render_y+y_padding, "center", "center" )
	    local ex_scaling = level_width/IMG_levels[11]:getWidth()
      menu_drawf(IMG_players[player_number], render_x+padding_x, render_y+y_padding, "center", "center")
      padding_x = padding_x + level_width + 1 -- [[Thank you Eole!]]
      if is_selected then
        gprintf("<", render_x+padding_x-0.5*level_width, render_y+y_padding-0.5*text_height,level_width,"center")
        padding_x = padding_x + level_width
      end
      for i=1,11 do
        local use_unfocus = cursor_data.state.level < i
        if use_unfocus then
          menu_drawf(IMG_levels_unfocus[i], render_x+padding_x, render_y+y_padding, "center", "center", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale))
            --[[if i >= 11 then
	      menu_drawf(IMG_levels_unfocus[i], render_x+padding_x, render_y+y_padding, "center", "center", 0, ex_scaling, ex_scaling)
           end]]	  
        else
          menu_drawf(IMG_levels[i], render_x+padding_x, render_y+y_padding, "center", "center", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale))
            --[[if i >= 11 then
	      menu_drawf(IMG_levels[i], render_x+padding_x, render_y+y_padding, "center", "center", 0, ex_scaling, ex_scaling)	  
	    end]]
        end 
        padding_x = padding_x + level_width + 1
          --[[if i == 11 then
	     padding_x = padding_x + 16
         end]]	
      end
      if is_selected then
        gprintf(">", render_x+padding_x-0.5*level_width, render_y+y_padding-0.5*text_height,level_width,"center")
      end
    end

    local function draw_match_type(cursor_data,player_number,y_padding)
      local padding_x = math.floor(0.5*button_width - IMG_players[player_number]:getWidth()*0.5 - 46)  -- ty GIMP; no way to know the size of the text?
      menu_drawf(IMG_players[player_number], render_x+padding_x, render_y+y_padding, "center", "center" )
      padding_x = padding_x+IMG_players[player_number]:getWidth()
      local to_print
      if cursor_data.state.ranked then
        to_print = "casual [ranked]"
      else
        to_print = "[casual] ranked"
      end
      if cursor_data.state.level >= 11 then
        to_print = "[EX Mode]"
      end
      gprint(to_print, render_x+padding_x, render_y+y_padding-0.5*text_height-1)
    end

    local pstr
    if string.sub(str, 1, 2) == "__" then
      pstr = string.sub(str, 3)
    end
    if str == "__Mode" then
      if (character_select_mode == "2p_net_vs" or character_select_mode == "2p_local_vs") then
        draw_match_type(cursor_data[1],1,0.4*button_height)
        draw_match_type(cursor_data[2],2,0.7*button_height)
      else
        draw_match_type(cursor_data[1],1,0.5*button_height)
      end
    elseif str == "__Panels" then
      if (character_select_mode == "2p_net_vs" or character_select_mode == "2p_local_vs") then
        draw_panels(cursor_data[1],1,0.4*button_height)
        draw_panels(cursor_data[2],2,0.7*button_height)
      else
        draw_panels(cursor_data[1],1,0.5*button_height)
      end
    elseif str == "__Level" then
      if (character_select_mode == "2p_net_vs" or character_select_mode == "2p_local_vs") then
        draw_levels(cursor_data[1],1,0.4*button_height)
        draw_levels(cursor_data[2],2,0.7*button_height)
      else
        draw_levels(cursor_data[1],1,0.5*button_height)
      end
    elseif str == "P1" then
      draw_player_state(cursor_data[1],1)
      pstr = my_name
    elseif str == "P2" then
      draw_player_state(cursor_data[2],2)
      pstr = op_name
    elseif character then
      pstr = character.display_name
    elseif string.sub(str, 1, 2) ~= "__" then
      pstr = str:gsub("^%l", string.upper)
    end
    if x ~= 0 then
      if cursor_data[1].state and cursor_data[1].state.cursor == str 
        and ( str ~= "__Empty" or ( cursor_data[1].position[1] == x and cursor_data[1].position[2] == y ) ) then
        draw_cursor(button_height, spacing, 1, cursor_data[1].state.ready)
      end
      if (character_select_mode == "2p_net_vs" or character_select_mode == "2p_local_vs")
        and cursor_data[2].state and cursor_data[2].state.cursor == str
        and ( str ~= "__Empty" or ( cursor_data[2].position[1] == x and cursor_data[2].position[2] == y ) ) then
        draw_cursor(button_height, spacing, 2, cursor_data[2].state.ready)
      end
    end
    if str ~= "__Empty" then
      gprintf(pstr, render_x+x_add, render_y+y_add,width_for_alignment,halign)
    end
  end

  print("got to LOC before net_vs_room character select loop")
  menu_clock = 0

  while true do
    if character_select_mode == "2p_net_vs" then
      for _,msg in ipairs(this_frame_messages) do
        if msg.win_counts then
          update_win_counts(msg.win_counts)
        end
        if msg.menu_state then
          if currently_spectating then
            if msg.player_number == 1 or msg.player_number == 2 then
              cursor_data[msg.player_number].state = msg.menu_state
              refresh_based_on_own_mods(cursor_data[msg.player_number].state)
              character_loader_load(cursor_data[msg.player_number].state.character)
            end
          else
            cursor_data[2].state = msg.menu_state
            refresh_based_on_own_mods(cursor_data[2].state)
            character_loader_load(cursor_data[2].state.character)
          end
          refresh_loaded_and_ready(cursor_data[1],cursor_data[2])
        end
        if msg.ranked_match_approved then
          match_type = "Ranked"
          match_type_message = ""
          if msg.caveats then
            match_type_message = match_type_message..(msg.caveats[1] or "")
          end
        elseif msg.ranked_match_denied then
          match_type = "Casual"
          match_type_message = "Not ranked. "
          if msg.reasons then
            match_type_message = match_type_message..(msg.reasons[1] or "Reason unknown")
          end
        --[[elseif msg.ranked_match_denied and cursor_data.state.level >= 11 then
	  match_type = "Casual"
	  match_type_message = "EX Mode Activated "
	    if msg.reasons then
	  match_type_message = match_type_message..(msg.reasons[1] or "Reason unknown")
	  end]]
        end
        if msg.leave_room then
          my_win_count = 0
          op_win_count = 0
          return main_net_vs_lobby
        end
        if msg.match_start or replay_of_match_so_far then
          print("currently_spectating: "..tostring(currently_spectating))
          local fake_P1 = P1
          local fake_P2 = P2
          refresh_based_on_own_mods(msg.opponent_settings)
          refresh_based_on_own_mods(msg.player_settings, true)
          -- mainly for spectator mode, those characters have already been loaded otherwise
          character_loader_load(msg.player_settings.character)
          character_loader_load(msg.opponent_settings.character)
          character_loader_wait()
          P1 = Stack(1, "vs", msg.player_settings.panels_dir, msg.player_settings.level, msg.player_settings.character, msg.player_settings.player_number)
          P1.enable_analytics = not currently_spectating and not replay_of_match_so_far
          P2 = Stack(2, "vs", msg.opponent_settings.panels_dir, msg.opponent_settings.level, msg.opponent_settings.character, msg.opponent_settings.player_number)
          if currently_spectating then
            P1.panel_buffer = fake_P1.panel_buffer
            P1.gpanel_buffer = fake_P1.gpanel_buffer
          end
          P2.panel_buffer = fake_P2.panel_buffer
          P2.gpanel_buffer = fake_P2.gpanel_buffer
          P1.garbage_target = P2
          P2.garbage_target = P1
          move_stack(P2,2)
          replay.vs = {P="",O="",I="",Q="",R="",in_buf="",
                      P1_level=P1.level,P2_level=P2.level,
                      P1_name=my_name, P2_name=op_name,
                      P1_char=P1.character,P2_char=P2.character,
                      ranked=msg.ranked, do_countdown=true}
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
            gprint(to_print,unpack(main_menu_screen_pos))
            if not do_messages() then
              return main_dumb_transition, {main_select_mode, "Disconnected from server.\n\nReturning to main menu...", 60, 300}
            end
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
            gprint(to_print,unpack(main_menu_screen_pos))
            if not do_messages() then
              return main_dumb_transition, {main_select_mode, "Disconnected from server.\n\nReturning to main menu...", 60, 300}
            end
            wait()
            if game_start_timeout > 250 then
              return main_dumb_transition, {main_select_mode,
                              "game start timed out.\n This is a known bug, but you may post it in #panel-attack-bugs-features \nif you'd like.\n"
                              .."\n".."msg.match_start = "..(tostring(msg.match_start) or "nil")
                              .."\n".."replay_of_match_so_far = "..(tostring(replay_of_match_so_far) or "nil")
                              .."\n".."P1.panel_buffer = "..P1.panel_buffer
                              .."\n".."P2.panel_buffer = "..P2.panel_buffer
                              .."\n".."P1.gpanel_buffer = "..P1.gpanel_buffer
                              .."\n".."P2.gpanel_buffer = "..P2.gpanel_buffer,
                              180}
            end
          end
          P1:starting_state()
          P2:starting_state()
          return main_net_vs
        end
      end
    end

    -- those values span multiple 'map blocks'
    if current_server_supports_ranking then
      draw_button(1,1,2,1,"__Mode","center","top")
      draw_button(1,3,2,1,"__Level","center","top")
      draw_button(1,5,2,1,"__Panels","center","top")
    else
      draw_button(1,1,3,1,"__Level","center","top")
      draw_button(1,4,3,1,"__Panels","center","top")
    end
    draw_button(1,7,1,1,"__Ready","center","center")

    for i=2,X do
      for j=1,Y do
        local valign = "top"
        if map[current_page][i][j] == "__Leave" or map[current_page][i][j] == "__Random" then
          valign = "center"
        end
        draw_button(i,j,1,1,map[current_page][i][j],"center",valign)
      end
    end
    local my_rating_difference = ""
    local op_rating_difference = ""
    if current_server_supports_ranking and not global_current_room_ratings[my_player_number].placement_match_progress then
      if global_current_room_ratings[my_player_number].difference then
        if global_current_room_ratings[my_player_number].difference>= 0 then
          my_rating_difference = "(+"..global_current_room_ratings[my_player_number].difference..") "
        else
          my_rating_difference = "("..global_current_room_ratings[my_player_number].difference..") "
        end
      end
      if global_current_room_ratings[op_player_number].difference then
        if global_current_room_ratings[op_player_number].difference >= 0 then
          op_rating_difference = "(+"..global_current_room_ratings[op_player_number].difference..") "
        else
          op_rating_difference = "("..global_current_room_ratings[op_player_number].difference..") "
        end
      end
    end
    local function get_player_state_str(player_number, rating_difference, win_count, op_win_count, expected_win_ratio)
      local state = ""
      if current_server_supports_ranking then
        state = state.."Rating: "..(global_current_room_ratings[player_number].league or "")
        if not global_current_room_ratings[player_number].placement_match_progress then
          state = state.."\n"..rating_difference..global_current_room_ratings[player_number].new
        elseif global_current_room_ratings[player_number].placement_match_progress
        and global_current_room_ratings[player_number].new
        and global_current_room_ratings[player_number].new == 0 then
          state = state.."\n"..global_current_room_ratings[player_number].placement_match_progress
        end
      end
      if character_select_mode == "2p_net_vs" or character_select_mode == "2p_local_vs" then
        if current_server_supports_ranking then
          state = state.."\n"
        end
        state = state.."Wins: "..win_count
        if (current_server_supports_ranking and expected_win_ratio) or win_count + op_win_count > 0 then
          state = state.."\nWinrate:"
          local need_line_return = false
          if win_count + op_win_count > 0 then
            state = state.." actual: "..(100*round(win_count/(op_win_count+win_count),2)).."%"
            need_line_return = true
          end
          if current_server_supports_ranking and expected_win_ratio then
            if need_line_return then
              state = state.."\n        "
            end
            state = state.." expected: "..expected_win_ratio.."%"
          end
        end
      end
      return state
    end
    draw_button(0,1,1,1,"P1")
    draw_button(0,2,2,1,get_player_state_str(my_player_number,my_rating_difference,my_win_count,op_win_count,my_expected_win_ratio),"left","top",true)
    if cursor_data[1].state and op_name then
      draw_button(0,5,1,1,"P2")
      draw_button(0,6,2,1,get_player_state_str(op_player_number,op_rating_difference,op_win_count,my_win_count,op_expected_win_ratio),"left","top",true)
      --state = state.." "..json.encode(op_state)
    end
    if character_select_mode == "2p_net_vs" then
      if not cursor_data[1].state.ranked and not cursor_data[2].state.ranked then
        match_type_message = ""
      end
      gprintf(match_type, 0, 15, canvas_width, "center")
      gprintf(match_type_message, 0, 30, canvas_width, "center")
    end
    if pages_amount ~= 1 then
      gprintf("Page "..current_page.."/"..pages_amount, 0, 660, canvas_width, "center")
    end
    wait()

    local ret = nil

    local function move_cursor(cursor_pos,direction)
     local dx,dy = unpack(direction)
      local can_x,can_y = wrap(1, cursor_pos[1]+dx, X), wrap(1, cursor_pos[2]+dy, Y)
      while can_x ~= cursor_pos[1] or can_y ~= cursor_pos[2] do
        if map[current_page][can_x][can_y] and ( map[current_page][can_x][can_y] ~= map[current_page][cursor_pos[1]][cursor_pos[2]] or 
          map[current_page][can_x][can_y] == "__Empty" ) then
          break
        end
        can_x,can_y = wrap(1, can_x+dx, X), wrap(1, can_y+dy, Y)
      end
      cursor_pos[1],cursor_pos[2] = can_x,can_y
    end

    local function change_panels_dir(panels_dir,increment)
      local current = 0
      for k,v in ipairs(IMG_panels_dirs) do
        if v == panels_dir then
          current = k
          break
        end
      end
      local dir_count = #IMG_panels_dirs
      local new_theme_idx = ((current - 1 + increment) % dir_count) + 1
      for k,v in ipairs(IMG_panels_dirs) do
        if k == new_theme_idx then
            return v
        end
      end
      return panels_dir
    end

    variable_step(function()
      menu_clock = menu_clock + 1

      character_loader_update()
      refresh_loaded_and_ready(cursor_data[1].state,cursor_data[2].state)

      local up,down,left,right = {-1,0}, {1,0}, {0,-1}, {0,1}
      local selectable = {__Panels=true, __Level=true, __Ready=true}
      if not currently_spectating then
        local KMax = 1
        if character_select_mode == "2p_local_vs" then
          KMax = 2
        end
        for i=1,KMax do
          local k=K[i]
          local cursor = cursor_data[i]
          if menu_prev_page(k) then
            if not cursor.selected then current_page = bound(1, current_page-1, pages_amount) end
          elseif menu_next_page(k) then
            if not cursor.selected then current_page = bound(1, current_page+1, pages_amount) end
          elseif menu_up(k) then
            if not cursor.selected then move_cursor(cursor.position,up) end
          elseif menu_down(k) then
            if not cursor.selected then move_cursor(cursor.position,down) end
          elseif menu_left(k) then
            if cursor.selected then
              if cursor.state.cursor == "__Level" then
                cursor.state.level = bound(1, cursor.state.level-1, 11)   
                if cursor.state.level >= 11 and cursor.state.ranked then
                  cursor.state.ranked = false
                end
              elseif cursor.state.cursor == "__Panels" then
                cursor.state.panels_dir = change_panels_dir(cursor.state.panels_dir,-1)
              end
            end
            if not cursor.selected then move_cursor(cursor.position,left) end
          elseif menu_right(k) then
            if cursor.selected then
              if cursor.state.cursor == "__Level" then
                cursor.state.level = bound(1, cursor.state.level+1, 11)
                if cursor.state.level >= 11 and cursor.state.ranked then
                  cursor.state.ranked = false
                end
              elseif cursor.state.cursor == "__Panels" then
                cursor.state.panels_dir = change_panels_dir(cursor.state.panels_dir,1)
              end
            end
            if not cursor.selected then move_cursor(cursor.position,right) end
          elseif menu_enter(k) then
            if selectable[cursor.state.cursor] then
              cursor.selected = not cursor.selected
            elseif cursor.state.cursor == "__Leave" then
              if character_select_mode == "2p_net_vs" then
                if not do_leave() then
                  ret = {main_dumb_transition, {main_select_mode, "Error when leaving online"}}
                end
              else
                ret = {main_select_mode}
              end
            elseif cursor.state.cursor == "__Random" then
              cursor.state.character = uniformly(characters_ids_for_current_theme)
              characters[cursor.state.character]:play_selection_sfx()
              character_loader_load(cursor.state.character)
            elseif cursor.state.cursor == "__Mode" then
              if cursor.state.level < 11 then
		cursor.state.ranked = not cursor.state.ranked
              end	
            elseif cursor.state.cursor ~= "__Empty" then
              cursor.state.character = cursor.state.cursor
              cursor.state.character_display_name = characters[cursor.state.character].display_name
              characters[cursor.state.character]:play_selection_sfx()
              character_loader_load(cursor.state.character)
              --When we select a character, move cursor to "__Ready"
              cursor.state.cursor = "__Ready"
              cursor.position = shallowcpy(name_to_xy_per_page[current_page]["__Ready"])
            end
          elseif menu_escape(k) then
            if cursor.state.cursor == "__Leave" then
              if character_select_mode == "2p_net_vs" then
                if not do_leave() then
                  ret = {main_dumb_transition, {main_select_mode, "Error when leaving online"}}
                end
              else
                ret = {main_select_mode}
              end
            end
            cursor.selected = false
            cursor.position = shallowcpy(name_to_xy_per_page[current_page]["__Leave"])
          end
          if cursor.state ~= nil then
            cursor.state.cursor = map[current_page][cursor.position[1]][cursor.position[2]]
            cursor.state.wants_ready = cursor.selected and cursor.state.cursor=="__Ready"
          end
        end
        -- update config, does not redefine it
        config.character = cursor_data[1].state.character
        config.level = cursor_data[1].state.level
        config.ranked = cursor_data[1].state.ranked
        if config.use_panels_from_assets_folder == false then
          config.panels_dir_when_not_using_set_from_assets_folder = cursor_data[1].state.panels_dir
          config.panels_dir = config.panels_dir_when_not_using_set_from_assets_folder
        end

        if character_select_mode == "2p_local_vs" then -- this is registered for future entering of the lobby
          global_op_state = shallowcpy(cursor_data[2].state)
          global_op_state.wants_ready = false
        end

        if character_select_mode == "2p_net_vs" and not content_equal(cursor_data[1].state, prev_state) and not currently_spectating then
          json_send({menu_state=cursor_data[1].state})
        end
        prev_state = shallowcpy(cursor_data[1].state)

      else -- (we are are spectating)
        if menu_escape(K[1]) then
          do_leave()
          ret = {main_net_vs_lobby}
        end
      end
    end)
    if ret then
      return unpack(ret)
    end
    if cursor_data[1].state.ready and character_select_mode == "1p_vs_yourself" then
      P1 = Stack(1, "vs", cursor_data[1].state.panels_dir, cursor_data[1].state.level, cursor_data[1].state.character)
      P1.enable_analytics = true
      P1.garbage_target = P1
      make_local_panels(P1, "000000")
      make_local_gpanels(P1, "000000")
      P1:starting_state()
      return main_dumb_transition, {main_local_vs_yourself, "Game is starting...", 30, 30}
    elseif cursor_data[1].state.ready and character_select_mode == "2p_local_vs" and cursor_data[2].state.ready then
      P1 = Stack(1, "vs", cursor_data[1].state.panels_dir, cursor_data[1].state.level, cursor_data[1].state.character)
      P1.enable_analytics = true
      P2 = Stack(2, "vs", cursor_data[2].state.panels_dir, cursor_data[2].state.level, cursor_data[2].state.character)
      P1.garbage_target = P2
      P2.garbage_target = P1
      move_stack(P2,2)
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
      P1:starting_state()
      P2:starting_state()
      return main_local_vs
    elseif character_select_mode == "2p_net_vs" then
      if not do_messages() then
        return main_dumb_transition, {main_select_mode, "Disconnected from server.\n\nReturning to main menu...", 60, 300}
      end
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
  stop_the_music()
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
  local lobby_menu_x = {[true]=main_menu_screen_pos[1]-200, [false]=main_menu_screen_pos[1]} --will be used to make room in case the leaderboard should be shown.
  local lobby_menu_y = main_menu_screen_pos[2]-120
  local sent_requests = {}
  while true do
      if connection_up_time <= login_status_message_duration then
        gprint(login_status_message, lobby_menu_x[showing_leaderboard], lobby_menu_y)
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
        love.window.requestAttention()
        return main_character_select
      end
      if msg.unpaired then
        unpaired_players = msg.unpaired
        -- players who leave the unpaired list no longer have standing invitations to us.\
        -- we also no longer have a standing invitation to them, so we'll remove them from sent_requests
        local new_willing = {}
        local new_sent_requests = {}
        for _,player in ipairs(unpaired_players) do
          new_willing[player] = willing_players[player]
          new_sent_requests[player] = sent_requests[player]
        end
        willing_players = new_willing
        sent_requests = new_sent_requests
      end
      if msg.spectatable then
        spectatable_rooms = msg.spectatable
      end
      if msg.game_request then
        willing_players[msg.game_request.sender] = true
        love.window.requestAttention()
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
        to_print = to_print .. "   " .. items[i] ..(sent_requests[items[i]] and " (Request sent)" or "").. (willing_players[items[i]] and " (Wants to play with you :o)" or "") .. "\n"
      elseif i < #items - 1 and items[i].name then
        to_print = to_print .. "   spectate " .. items[i].name .. " (".. items[i].state .. ")\n" --printing room names
      elseif i < #items then
        to_print = to_print .. "   " .. items[i] .. "\n"
      else
        to_print = to_print .. "   " .. items[i]
      end
    end
    gprint(notice[#items > 2], lobby_menu_x[showing_leaderboard], lobby_menu_y+90)
    gprint(arrow, lobby_menu_x[showing_leaderboard], lobby_menu_y+120)
    gprint(to_print, lobby_menu_x[showing_leaderboard], lobby_menu_y+120)
    if showing_leaderboard then
      gprint(leaderboard_string, lobby_menu_x[showing_leaderboard]+400, lobby_menu_y)
    end
    gprint(join_community_msg, main_menu_screen_pos[1]+30, main_menu_screen_pos[2]+280)

    wait()
    local ret = nil
    variable_step(function()
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
          ret = {main_select_mode}
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
          sent_requests[op_name] = true
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
          ret = {main_select_mode}
        elseif showing_leaderboard then
          showing_leaderboard = false
        else
          active_idx = #items
        end
      end
    end)
    if ret then
      return unpack(ret)
    end
    active_back = active_idx == #items
    if active_idx ~= prev_act_idx then
      print("#items: "..#items.."  idx_old: "..prev_act_idx.."  idx_new: "..active_idx.."  active_back: "..tostring(active_back))
      prev_act_idx = active_idx
    end
    if not do_messages() then
      return main_dumb_transition, {main_select_mode, "Disconnected from server.\n\nReturning to main menu...", 60, 300}
    end
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
  gprint("Setting up connection...", unpack(main_menu_screen_pos))
  wait()
  network_init(ip)
  local timeout_counter = 0
  while not connection_is_ready() do
    gprint("Connecting...", unpack(main_menu_screen_pos))
    wait()
    if not do_messages() then
      return main_dumb_transition, {main_select_mode, "Disconnected from server.\n\nReturning to main menu...", 60, 300}
    end
  end
  connected_server_ip = ip
  logged_in = false
  
  return main_net_vs_lobby
end

function main_net_vs()
  --STONER_MODE = true
  bg = IMG_stages[math.random(#IMG_stages)]
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
        return main_net_vs_lobby
      end
    end

    local name_and_score = { (my_name or "").."\nWins: "..my_win_count, (op_name or "").."\nWins: "..op_win_count}
    gprint(name_and_score[1], P1.score_x, P1.score_y-48)
    gprint(name_and_score[2], P2.score_x, P2.score_y-48)
    if not config.debug_mode then --this is printed in the same space as the debug details
      gprint(spectators_string, P1.score_x, P1.score_y+177)
    end
    if match_type == "Ranked" then
      if global_current_room_ratings[my_player_number]
      and global_current_room_ratings[my_player_number].new then
        local rating_to_print = "Rating: "
        if global_current_room_ratings[my_player_number].new > 0 then
          rating_to_print = rating_to_print.." "..global_current_room_ratings[my_player_number].new
        end
        gprint(rating_to_print, P1.score_x, P1.score_y-16)
      end
      if global_current_room_ratings[op_player_number]
      and global_current_room_ratings[op_player_number].new then
        local op_rating_to_print = "Rating: "
        if global_current_room_ratings[op_player_number].new > 0 then
          op_rating_to_print = op_rating_to_print.." "..global_current_room_ratings[op_player_number].new
        end
        gprint(op_rating_to_print, P2.score_x, P2.score_y-16)
      end
    end
    if not (P1 and P1.play_to_end) and not (P2 and P2.play_to_end) then
      P1:render()
      P2:render()
      wait()
      if currently_spectating and this_frame_keys["escape"] then
        print("spectator pressed escape during a game")
        stop_the_music()
        my_win_count = 0
        op_win_count = 0
        json_send({leave_room=true})
        return main_net_vs_lobby
      end
      if not do_messages() then
        return main_dumb_transition, {main_select_mode, "Disconnected from server.\n\nReturning to main menu...", unpack(main_menu_screen_pos)}
      end
    end

    --print(P1.CLOCK, P2.CLOCK)
    if (P1 and P1.play_to_end) or (P2 and P2.play_to_end) then
      if not P1.game_over then
        if currently_spectating then
          P1:foreign_run()
        else
          P1:local_run()
        end
      end
      if not P2.game_over then
        P2:foreign_run()
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
        if not P2.game_over then
          P2:foreign_run()
        end
      end)
    end

    local outcome_claim = nil
    local winSFX = nil
    if P1.game_over and P2.game_over and P1.CLOCK == P2.CLOCK then
      end_text = "Draw"
      outcome_claim = 0
    elseif P1.game_over and P1.CLOCK <= P2.CLOCK then
      winSFX = P2:pick_win_sfx()
      end_text = op_name.." Wins" .. (currently_spectating and " " or " :(")
      op_win_count = op_win_count + 1 -- leaving these in just in case used with an old server that doesn't keep score.  win_counts will get overwritten after this by the server anyway.
      outcome_claim = P2.player_number
    elseif P2.game_over and P2.CLOCK <= P1.CLOCK then
      winSFX = P1:pick_win_sfx()
      end_text = my_name.." Wins" .. (currently_spectating and " " or " ^^")
      my_win_count = my_win_count + 1 -- leave this in
      outcome_claim = P1.player_number
    end
    if end_text then
      analytics_game_ends()
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
        return main_dumb_transition, {main_character_select, end_text, 45, 45, winSFX}
      else
        return main_dumb_transition, {main_character_select, end_text, 45, 180, winSFX}
      end
    end
  end
end

function main_local_vs_setup()
  currently_spectating = false
  my_name = config.name or "Player 1"
  op_name = "Player 2"
  op_state = nil
  character_select_mode = "2p_local_vs"
  return main_character_select
end

function main_local_vs()
  -- TODO: replay!
  bg = IMG_stages[math.random(#IMG_stages)]
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
    local winSFX = nil
    if P1.game_over and P2.game_over and P1.CLOCK == P2.CLOCK then
      end_text = "Draw"
    elseif P1.game_over and P1.CLOCK <= P2.CLOCK then
      winSFX = P2:pick_win_sfx()
      op_win_count = op_win_count + 1
      end_text = "P2 wins ^^"
    elseif P2.game_over and P2.CLOCK <= P1.CLOCK then
      winSFX = P1:pick_win_sfx()
      my_win_count = my_win_count + 1
      end_text = "P1 wins ^^"
    end
    if end_text then
      analytics_game_ends()
      return main_dumb_transition, {main_character_select, end_text, 45, nil, winSFX}
    end
  end
end

function main_local_vs_yourself_setup()
  currently_spectating = false
  my_name = config.name or "Player 1"
  op_name = nil
  op_state = nil
  character_select_mode = "1p_vs_yourself"
  return main_character_select
end

function main_local_vs_yourself()
  -- TODO: replay!
  bg = IMG_stages[math.random(#IMG_stages)]
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
      analytics_game_ends()
      return main_dumb_transition, {main_character_select, end_text, 45}
    end
  end
end

local function draw_debug_mouse_panel()
  if debug_mouse_panel then
    local str = "Panel info:\nrow: "..debug_mouse_panel[1].."\ncol: "..debug_mouse_panel[2]
    for k,v in spairs(debug_mouse_panel[3]) do
      str = str .. "\n".. k .. ": "..tostring(v)
    end
    gprintf(str, 10, 10)
  end
end

function main_replay_vs()
  local replay = replay.vs
  if replay == nil then
    return main_dumb_transition, {main_select_mode, "I don't have a vs replay :("}
  end
  fallback_when_missing = nil
  bg = IMG_stages[math.random(#IMG_stages)]
  P1 = Stack(1, "vs", config.panels_dir, replay.P1_level or 5)
  P2 = Stack(2, "vs", config.panels_dir, replay.P2_level or 5)
  P1.do_countdown = replay.do_countdown or false
  P2.do_countdown = replay.do_countdown or false
  P1.ice = true
  P1.garbage_target = P2
  P2.garbage_target = P1
  move_stack(P2,2)
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
  refresh_based_on_own_mods(P1)
  refresh_based_on_own_mods(P2, true)
  character_loader_load(P1.character)
  character_loader_load(P2.character)
  character_loader_wait()
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
  while true do
    debug_mouse_panel = nil
    gprint(my_name or "", P1.score_x, P1.score_y-28)
    gprint(op_name or "", P2.score_x, P2.score_y-28)
    P1:render()
    P2:render()
    draw_debug_mouse_panel()
    wait()
    local ret = nil
    variable_step(function()
      if this_frame_keys["escape"] then
        ret = {main_select_mode}
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
    end)
    if ret then
      return unpack(ret)
    end
    local winSFX = nil
    if P1.game_over and P2.game_over and P1.CLOCK == P2.CLOCK then
      end_text = "Draw"
    elseif P1.game_over and P1.CLOCK <= P2.CLOCK then
      winSFX = P2:pick_win_sfx()
      if replay.P2_name and replay.P2_name ~= "anonymous" then
        end_text = replay.P2_name.." wins"
      else
        end_text = "P2 wins"
      end
    elseif P2.game_over and P2.CLOCK <= P1.CLOCK then
      winSFX = P1:pick_win_sfx()
      if replay.P1_name and replay.P1_name ~= "anonymous" then
        end_text = replay.P1_name.." wins"
      else
        end_text = "P1 wins"
      end
    end
    if end_text then
      return main_dumb_transition, {main_select_mode, end_text, nil, nil, winSFX}
    end
  end
end

function main_replay_endless()
  bg = IMG_stages[math.random(#IMG_stages)]
  local replay = replay.endless
  if replay == nil or replay.speed == nil then
    return main_dumb_transition,
      {main_select_mode, "I don't have an endless replay :("}
  end
  P1 = Stack(1, "endless", config.panels_dir, replay.speed, replay.difficulty)
  P1.do_countdown = replay.do_countdown or false
  P1.max_runs_per_frame = 1
  P1.input_buffer = table.concat({replay.in_buf})
  P1.panel_buffer = replay.pan_buf
  P1.gpanel_buffer = replay.gpan_buf
  P1.speed = replay.speed
  P1.difficulty = replay.difficulty
  P1:starting_state()
  local run = true
  while true do
    P1:render()
    wait()
    local ret = nil
    variable_step(function()
      if this_frame_keys["escape"] then
        ret = {main_select_mode}
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
          ret = {main_dumb_transition, {main_select_mode, end_text, 30}}
        end
        P1:foreign_run()
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function main_replay_puzzle()
  bg = IMG_stages[math.random(#IMG_stages)]
  local replay = replay.puzzle
  if not replay or replay.in_buf == nil or replay.in_buf == "" then
    return main_dumb_transition,
      {main_select_mode, "I don't have a puzzle replay :("}
  end
  P1 = Stack(1, "puzzle", config.panels_dir)
  P1.do_countdown = replay.do_countdown or false
  P1.max_runs_per_frame = 1
  P1.input_buffer = replay.in_buf
  P1:set_puzzle_state(unpack(replay.puzzle))
  local run = true
  while true do
    debug_mouse_panel = nil
    P1:render()
    draw_debug_mouse_panel()
    wait()
    local ret = nil
    variable_step(function()
      if this_frame_keys["escape"] then
        ret =  {main_select_mode}
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
            ret = {main_dumb_transition, {main_select_mode, "You win!"}}
          elseif P1.puzzle_moves == 0 then
            ret = {main_dumb_transition, {main_select_mode, "You lose :("}}
          end
        end
        P1:foreign_run()
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function make_main_puzzle(puzzles)
  local awesome_idx, next_func = 1, nil
  function next_func()
    bg = IMG_stages[math.random(#IMG_stages)]
    consuming_timesteps = true
    replay.puzzle = {}
    local replay = replay.puzzle
    P1 = Stack(1, "puzzle", config.panels_dir)
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
      local ret = nil
      variable_step(function()
        if this_frame_keys["escape"] then
          ret = {main_select_puzz}
        end
        if P1.n_active_panels == 0 and
            P1.prev_active_panels == 0 then
          if P1:puzzle_done() then
            awesome_idx = (awesome_idx % #puzzles) + 1
            write_replay_file()
            if awesome_idx == 1 then
              ret = {main_dumb_transition, {main_select_puzz, "You win!", 30}}
            else
              ret = {main_dumb_transition, {next_func, "You win!", 30}}
            end
          elseif P1.puzzle_moves == 0 then
            write_replay_file()
            ret = {main_dumb_transition, {main_select_puzz, "You lose :(", 30}}
          end
        end
        if P1.n_active_panels ~= 0 or P1.prev_active_panels ~= 0 or
            P1.puzzle_moves ~= 0 then
          P1:local_run()
        end
      end)
      if ret then
        return unpack(ret)
      end
    end
  end
  return next_func
end

do
  local items = {}
  for key,val in spairs(puzzle_sets) do
    items[#items+1] = {key, make_main_puzzle(val)}
  end
  items[#items+1] = {"Back", main_select_mode}
  function main_select_puzz()
    love.audio.stop()
    stop_the_music()
    bg = title
    local active_idx = last_puzzle_idx or 1
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
      gprint("Puzzles:", unpack(main_menu_screen_pos) )
      gprint("Note: you may place new custom puzzles in\n\n%appdata%\\Panel Attack\\puzzles\n\nSee the README and example puzzle set there\nfor instructions", main_menu_screen_pos[1]-280, main_menu_screen_pos[2]+220)
      gprint(arrow, main_menu_screen_pos[1]+100, main_menu_screen_pos[2])
      gprint(to_print, main_menu_screen_pos[1]+100, main_menu_screen_pos[2])
      wait()
      local ret = nil
      variable_step(function()
        if menu_up(k) then
          active_idx = wrap(1, active_idx-1, #items)
        elseif menu_down(k) then
          active_idx = wrap(1, active_idx+1, #items)
        elseif menu_enter(k) then
          last_puzzle_idx = active_idx
          ret = {items[active_idx][2], items[active_idx][3]}
        elseif menu_escape(k) then
          if active_idx == #items then
            ret = {items[active_idx][2], items[active_idx][3]}
          else
            active_idx = #items
          end
        end
      end)
      if ret then
        return unpack(ret)
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
    gprint(arrow, unpack(main_menu_screen_pos))
    gprint(to_print, unpack(main_menu_screen_pos))
    gprint(to_print2, unpack(main_menu_screen_pos))
  end
  local idxs_to_set = {}
  while true do
    get_items()
    if #idxs_to_set > 0 then
      items[idxs_to_set[1]][2] = "___"
    end
    print_stuff()
    wait()
    local ret = nil
    variable_step(function()
      if #idxs_to_set > 0 then
        local idx = idxs_to_set[1]
        for key,val in pairs(this_frame_keys) do
          if val then
            k[key_names[idx]] = key
            table.remove(idxs_to_set, 1)
            if #idxs_to_set == 0 then
              write_key_file()
            end
          end
        end
      elseif menu_up(K[1]) then
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
          idxs_to_set = {active_idx}
        elseif active_idx == #key_names + 1 then
          idxs_to_set = {1,2,3,4,5,6,7,8}
        else
          ret = {items[active_idx][3], items[active_idx][4]}
        end
      elseif menu_escape(K[1]) then
        if active_idx == #items then
          ret = {items[active_idx][3], items[active_idx][4]}
        else
          active_idx = #items
        end
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function main_show_custom_graphics_readme(idx)
  if not love.filesystem.getInfo("assets/"..prefix_of_ignored_dirs..default_assets_dir) then
    print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
    gprint("Hold on.  Copying an example folder to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
    wait()
    recursive_copy("assets/"..default_assets_dir, "assets/"..prefix_of_ignored_dirs..default_assets_dir)
  end

  -- add other defaults panels sets here so that anyone can update them if wanted
  local default_panels_dirs = { default_panels_dir, "libre" }
  
  for _,panels_dir in ipairs(default_panels_dirs) do
    if not love.filesystem.getInfo("panels/"..prefix_of_ignored_dirs..panels_dir) then
      print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
      gprint("Hold on. Copying example folders to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
      wait()
      recursive_copy("panels/"..panels_dir, "panels/"..prefix_of_ignored_dirs..panels_dir)
    end
  end

  local custom_graphics_readme = read_txt_file("Custom Graphics Readme.txt")
  while true do
    gprint(custom_graphics_readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(function()
      if menu_escape(K[1]) or menu_enter(K[1]) then
        ret = {main_options, {idx}}
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function main_show_custom_sounds_readme(idx)
  if not love.filesystem.getInfo("sounds/"..prefix_of_ignored_dirs..default_sounds_dir)then
    print("Hold on.  Copying an example folder to make this easier...\n This make take a few seconds.")
    gprint("Hold on.  Copying an example folder to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
    wait()
    recursive_copy("sounds/"..default_sounds_dir, "sounds/"..prefix_of_ignored_dirs..default_sounds_dir)
  end
  local custom_sounds_readme = read_txt_file("Custom Sounds Readme.txt")
  while true do
    gprint(custom_sounds_readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(function()
      if menu_escape(K[1]) or menu_enter(K[1]) then
        ret = {main_options, {idx}}
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function main_show_custom_characters_readme(idx)
  for _,current_character in ipairs(default_characters_ids) do
    if not love.filesystem.getInfo("characters/"..prefix_of_ignored_dirs..current_character) then
      print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
      gprint("Hold on.  Copying an example folder to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
      wait()
      recursive_copy("characters/"..current_character, "characters/"..prefix_of_ignored_dirs..current_character)
    end
  end

  local custom_characters_readme = read_txt_file("Custom Characters Readme.txt")
  while true do
    gprint(custom_characters_readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(function()
      if menu_escape(K[1]) or menu_enter(K[1]) then
        ret = {main_options, {idx}}
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function main_options(starting_idx)
  local items, active_idx = {}, starting_idx or 1
  local k = K[1]
  local selected, deselected_this_frame, adjust_active_value = false, false, false
  local save_replays_publicly_choices = {"with my name", "anonymously", "not at all"}
  local on_off_text = {[true]="On", [false]="Off"}
  local name, version, vendor, device = love.graphics.getRendererInfo()
  memory_before_options_menu = {  config.assets_dir or default_assets_dir,
                                  config.panels_dir_when_not_using_set_from_assets_folder or default_panels_dir,
                                  config.sounds_dir or default_sounds_dir,
                                  config.use_panels_from_assets_folder,
                                  config.use_default_characters,
                                  config.enable_analytics }
  --make so we can get "anonymously" from save_replays_publicly_choices["anonymously"]
  for k,v in ipairs(save_replays_publicly_choices) do
    save_replays_publicly_choices[v] = v
  end

  local function get_dir_set(set,path)
    local raw_dir_list = love.filesystem.getDirectoryItems(path)
    for k,v in ipairs(raw_dir_list) do
      local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
      if love.filesystem.getInfo(path.."/"..v) and v ~= "Example folder structure" and start_of_v ~= prefix_of_ignored_dirs then
        set[#set+1] = v
      end
    end
  end

  local asset_sets = {}
  get_dir_set(asset_sets,"assets")
  local panel_sets = {}
  get_dir_set(panel_sets,"panels")
  local sound_sets = {}
  get_dir_set(sound_sets,"sounds")

  print("asset_sets:")
  for k,v in ipairs(asset_sets) do
    print(v)
  end
  items = {
    --options menu table reference:
    --{[1]"Option Name", [2]current or default value, [3]type, [4]min or bool value or choices_table,
    -- [5]max, [6]sound_source, [7]selectable, [8]next_func, [9]play_while selected}
    {"Master Volume", config.master_volume or 100, "numeric", 0, 100, characters[config.character].musics.normal_music, true, nil, true},
    {"SFX Volume", config.SFX_volume or 100, "numeric", 0, 100, sounds.SFX.cur_move, true},
    {"Music Volume", config.music_volume or 100, "numeric", 0, 100, characters[config.character].musics.normal_music, true, nil, true},
    {"Vsync", on_off_text[config.vsync], "bool", false, nil, nil,false},
    {"Debug Mode", on_off_text[config.debug_mode or false], "bool", false, nil, nil,false},
    {"Save replays publicly",
      save_replays_publicly_choices[config.save_replays_publicly]
        or save_replays_publicly_choices["with my name"],
      "multiple choice", save_replays_publicly_choices},
    {"Graphics set", config.assets_dir or default_assets_dir, "multiple choice", asset_sets},
    {"Panels set", config.panels_dir_when_not_using_set_from_assets_folder or default_panels_dir, "multiple choice", panel_sets},
    {"About custom graphics", "", "function", nil, nil, nil, nil, main_show_custom_graphics_readme},
    {"Sounds set", config.sounds_dir or default_sounds_dir, "multiple choice", sound_sets},
    {"About custom sounds", "", "function", nil, nil, nil, nil, main_show_custom_sounds_readme},
    {"Ready countdown", on_off_text[config.ready_countdown_1P or false], "bool", true, nil, nil,false},
    {"Show FPS", on_off_text[config.show_fps or false], "bool", true, nil, nil,false},
    {"Use panels from assets folder", on_off_text[config.use_panels_from_assets_folder], "bool", true, nil, nil,false},
    {"Use default characters", on_off_text[config.use_default_characters], "bool", true, nil, nil,false},
    {"Danger music change-back delay", on_off_text[config.danger_music_changeback_delay or false], "bool", false, nil, nil, false},
    {"About custom characters", "", "function", nil, nil, nil, nil, main_show_custom_characters_readme},
    {"Enable analytics", on_off_text[config.enable_analytics or false], "bool", false, nil, nil, false},
    {"Back", "", nil, nil, nil, nil, false, main_select_mode}
  }
  local function print_stuff()
    gprint("graphics card:  "..(device or "nil"), 100, 0)
    local to_print, to_print2, arrow = "", "", ""
    for i=1,#items do
      if active_idx == i then
        arrow = arrow .. ">"
      else
        arrow = arrow .. "\n"
      end
      to_print = to_print .. "   " .. items[i][1] .. "\n"
      to_print2 = to_print2 .. "                            "
      if active_idx == i and selected then
        to_print2 = to_print2 .. "                          < "
      else
        to_print2 = to_print2 .. "                            "
      end
      to_print2 = to_print2.. items[i][2]
      if active_idx == i and selected then
        to_print2 = to_print2 .. " >"
      end
      to_print2 = to_print2 .. "\n"
    end
    local x,y = unpack(main_menu_screen_pos)
    x = x - 60 --options menu is 'lefter' than main_menu
    gprint(arrow, x, y)
    gprint(to_print, x, y)
    gprint(to_print2, x, y)
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
  local do_menu_function = false
  while true do
    print_stuff()
    wait()
    local ret = nil
    variable_step(function()
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
          ret = {exit_options_menu}
        end
      elseif menu_escape(K[1]) then
        if selected then
          selected = not selected
          deselected_this_frame = true
        elseif active_idx == #items then
          ret = {exit_options_menu}
        else
          active_idx = #items
        end
      end
      if adjust_active_value and not ret then
        if items[active_idx][3] == "bool" then
          if active_idx == 4 then
            config.debug_mode = not config.debug_mode
            items[active_idx][2] = on_off_text[config.debug_mode or false]
          end
          if items[active_idx][1] == "Ready countdown" then
            config.ready_countdown_1P = not config.ready_countdown_1P
            items[active_idx][2] = on_off_text[config.ready_countdown_1P]
          elseif items[active_idx][1] == "Vsync" then
            config.vsync = not config.vsync
            items[active_idx][2] = on_off_text[config.vsync]
            love.window.setVSync(config.vsync and 1 or 0)
          elseif items[active_idx][1] == "Show FPS" then
            config.show_fps = not config.show_fps
            items[active_idx][2] = on_off_text[config.show_fps]
          elseif items[active_idx][1] == "Use panels from assets folder" then
            config.use_panels_from_assets_folder = not config.use_panels_from_assets_folder
            items[active_idx][2] = on_off_text[config.use_panels_from_assets_folder]
          elseif items[active_idx][1] == "Use default characters" then
            config.use_default_characters = not config.use_default_characters
            items[active_idx][2] = on_off_text[config.use_default_characters]
          elseif items[active_idx][1] == "Danger music change-back delay" then
            config.danger_music_changeback_delay = not config.danger_music_changeback_delay
            items[active_idx][2] = on_off_text[config.danger_music_changeback_delay]
          elseif items[active_idx][1] == "Enable analytics" then
            config.enable_analytics = not config.enable_analytics
            items[active_idx][2] = on_off_text[config.enable_analytics]
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
          if config.music_volume ~= items[3][2] then --music volume should be updated
            config.music_volume = items[3][2]
            items[3][6]:setVolume(config.music_volume/100) --do just the one music source until we deselect
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
          elseif active_idx == 7 then
            config.panels_dir_when_not_using_set_from_assets_folder = items[active_idx][2]
          elseif active_idx == 9 then
            config.sounds_dir = items[active_idx][2]
          end
          --add any other multiple choice config updates here
        end
        adjust_active_value = false
      end
      if items[active_idx][3] == "function" and do_menu_function and not ret then
        ret = {items[active_idx][8], {active_idx}}
      end
      if not ret and selected and items[active_idx][9] and items[active_idx][6] and not items[active_idx][6]:isPlaying() then
      --if selected and play_while_selected and sound source exists and it isn't playing
        items[active_idx][6]:play()
      end
      if not ret and deselected_this_frame then
        if items[active_idx][6] then --sound_source for this menu item exists
          items[active_idx][6]:stop()
          love.audio.stop()
          stop_the_music()
        end
        deselected_this_frame = false
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function exit_options_menu()
  gprint("writing config to file...", unpack(main_menu_screen_pos))
  wait()
  if config.use_panels_from_assets_folder then
    config.panels_dir = config.assets_dir
  else
    config.panels_dir = config.panels_dir_when_not_using_set_from_assets_folder
  end
  write_conf_file()

  if config.assets_dir ~= memory_before_options_menu[1] 
    or config.use_default_characters ~= memory_before_options_menu[5]
    or config.sounds_dir ~= memory_before_options_menu[3] then
    gprint("reloading characters...", unpack(main_menu_screen_pos))
    wait()
    characters_init()
  end

  if config.assets_dir ~= memory_before_options_menu[1] 
    or config.use_default_characters ~= memory_before_options_menu[5] then
    gprint("reloading graphics...", unpack(main_menu_screen_pos))
    wait()
    graphics_init()
  end

  if config.panels_dir_when_not_using_set_from_assets_folder ~= memory_before_options_menu[2]
  or config.use_panels_from_assets_folder ~= memory_before_options_menu[4]
  or config.assets_dir ~= memory_before_options_menu[1] then
    gprint("reloading panels...", unpack(main_menu_screen_pos))
    wait()
    panels_init()
  end

  if config.sounds_dir ~= memory_before_options_menu[3] 
    or config.use_default_characters ~= memory_before_options_menu[5] then
    gprint("reloading sounds...", unpack(main_menu_screen_pos))
    wait()
    sound_init()
  else
    apply_config_volume()
  end

  if config.enable_analytics ~= memory_before_options_menu[6] then
    print("loading analytics...")
    gprint("loading analytics...", unpack(main_menu_screen_pos))
    wait()
    analytics_init()
  end

  memory_before_options_menu = nil
  return main_select_mode
end

function main_set_name()
  local name = config.name or ""
  while true do
    local to_print = "Enter your name:\n"..name
    if (love.timer.getTime()*3) % 2 > 1 then
        to_print = to_print .. "|"
    end
    gprint(to_print, unpack(main_menu_screen_pos))
    wait()
    local ret = nil
    variable_step(function()
      if this_frame_keys["escape"] then
        ret = {main_select_mode}
      end
      if this_frame_keys["return"] or this_frame_keys["kenter"] then
        config.name = name
        write_conf_file()
        ret = {main_select_mode}
      end
      if menu_backspace(K[1]) then
        -- Remove the last character.
        -- This could be a UTF-8 character, so handle it properly.
        local utf8offset = utf8.offset(name, -1)
        if utf8offset then
          name = string.sub(name, 1, utf8offset - 1)
        end
      end
      for _,v in ipairs(this_frame_unicodes) do
        name = name .. v
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function main_music_test()
  gprint("Loading required sounds... (this may take a while)", unpack(main_menu_screen_pos))
  wait()
  -- loads music for characters that are not fully loaded
  for _,character_id in ipairs(characters_ids_for_current_theme) do
    if not characters[character_id].fully_loaded then
      characters[character_id]:sound_init(true,false)
    end
  end

  local index = 1
  local tracks = {}

  for _,character_id in ipairs(characters_ids_for_current_theme) do
    local character = characters[character_id]
    tracks[#tracks+1] = {
      name = character.display_name .. ": normal_music",
      char = character_id,
      type = "normal_music",
      start = character.musics.normal_music_start or zero_sound,
      loop = character.musics.normal_music
    }
    if character.musics.danger_music then
      tracks[#tracks+1] = {
        name = character.display_name .. ": danger_music",
        char = character_id,
        type = "danger_music",
        start = character.musics.danger_music_start or zero_sound,
        loop = character.musics.danger_music
      }
    end
  end

  -- initial song starts here
  find_and_add_music(tracks[index].char, tracks[index].type)

  while true do
    tp =  "Currently playing: " .. tracks[index].name
    tp = tp .. (table.getn(currently_playing_tracks) == 1 and "\nPlaying the intro\n" or "\nPlaying main loop\n")
    min_time = math.huge
    for k, _ in pairs(music_t) do if k and k < min_time then min_time = k end end
    tp = tp .. string.format("%d", min_time - love.timer.getTime() )
    tp = tp .. "\n\n\n< and > to play navigate themes\nESC to leave"
    gprint(tp,unpack(main_menu_screen_pos))
    wait()
    local ret = nil
    variable_step(function()
      if menu_left(K[1]) or menu_right(K[1]) or menu_escape(K[1]) then
        stop_the_music()
      end
      if menu_left(K[1]) then  index = index - 1 end
      if menu_right(K[1]) then index = index + 1 end
      if index > #tracks then index = 1 end
      if index < 1 then index = #tracks end
      if menu_left(K[1]) or menu_right(K[1]) then
        find_and_add_music(tracks[index].char, tracks[index].type)
      end
      if menu_escape(K[1]) then

        -- unloads music for characters that are not fully loaded (it has been loaded when entering this submenu)
        for _,character_id in ipairs(characters_ids_for_current_theme) do
          if not characters[character_id].fully_loaded then
            characters[character_id]:sound_uninit()
          end
        end

        ret = {main_select_mode}
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function fullscreen()
  if love.graphics.getSupported("canvas") then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
  end
  return main_select_mode
end

function main_dumb_transition(next_func, text, timemin, timemax, winnerSFX)
  if P1 and P1.character then
    characters[P1.character]:stop_sounds()
  end
  if P2 and P2.character then
    characters[P2.character]:stop_sounds()
  end
  love.audio.stop()
  stop_the_music()
  winnerSFX = winnerSFX or nil
  if not SFX_mute then
    if winnerSFX ~= nil then
      winnerSFX:play()
    elseif SFX_GameOver_Play == 1 then
      sounds.SFX.game_over:play()
    end
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
    gprint(text, unpack(main_menu_screen_pos))
    wait()
    local ret = nil
    variable_step(function()
      if t >= timemin and (t >=timemax or (menu_enter(k) or menu_escape(k))) then
        ret = {next_func}
      end
      t = t + 1
      --if TCP_sock then
      --  if not do_messages() then
      --    -- do something? probably shouldn't drop back to the main menu transition since we're already here
      --  end
      --end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

function exit_game(...)
 love.event.quit()
 return main_select_mode
end

function love.quit()
  love.audio.stop()
  config.window_x, config.window_y, config.display = love.window.getPosition()
  write_conf_file()
end

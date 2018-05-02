local wait, resume = coroutine.yield, coroutine.resume

local main_select_mode, main_endless, make_main_puzzle, main_net_vs_setup,
  main_replay_endless, main_replay_puzzle, main_net_vs,
  main_config_input, main_dumb_transition, main_select_puzz,
  menu_up, menu_down, menu_left, menu_right, menu_enter, menu_escape,
  main_replay_vs, main_local_vs_setup, main_local_vs, menu_key_func,
  multi_func, normal_key, main_set_name, main_net_vs_room, main_net_vs_lobby
  
local PLAYING = "playing, not joinable"  -- room states
local CHARACTERSELECT = "joinable" --room states
local currently_spectating = false

function fmainloop()
  local func, arg = main_select_mode, nil
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
    close_socket()
    local items = {{"1P endless", main_select_speed_99, {main_endless}},
        {"1P puzzle", main_select_puzz},
        {"1P time attack", main_select_speed_99, {main_time_attack}},
        {"2P fakevs at burke.ro", main_net_vs_setup, {"burke.ro"}},
        {"2P fakevs local game", main_local_vs_setup},
        {"Replay of 1P endless", main_replay_endless},
        {"Replay of 1P puzzle", main_replay_puzzle},
        {"Replay of 2P fakevs", main_replay_vs},
        {"Configure input", main_config_input},
        {"Set name", main_set_name},
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
  local speed, difficulty, active_idx = 1,1,1
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
  replay.speed = P1.speed
  replay.difficulty = P1.difficulty
  make_local_panels(P1, "000000")
  make_local_gpanels(P1, "000000")
  while true do
    P1:render()
    wait()
    if P1.game_over then
    -- TODO: proper game over.
      write_replay_file()
      return main_dumb_transition, {main_select_mode, "You scored "..P1.score}
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
    if P1.game_over or P1.CLOCK == 120*60 then
    -- TODO: proper game over.
      return main_dumb_transition, {main_select_mode, "You scored "..P1.score}
    end
    variable_step(function()
      if (not P1.game_over)  and P1.CLOCK < 120 * 60 then
        P1:local_run() end end)
  end
end

function main_net_vs_room()
  P2 = {panel_buffer="", gpanel_buffer=""}
  local k = K[1]
  local map = {{"level", "level", "level", "level", "level", "level", "ready"},
               {"random", "windy", "sherbet", "thiana", "ruby", "lip", "elias"},
               {"flare", "neris", "seren", "phoenix", "dragon", "thanatos", "cordelia"},
			   {"lakitu", "bumpty", "poochy", "wiggler", "froggy", "blargg", "lungefish"},
			   {"raphael", "yoshi", "hookbill", "navalpiranha", "kamek", "bowser", "leave"}}
  local cursor,op_cursor,X,Y = {1,1},{1,1},5,7
  local up,down,left,right = {-1,0}, {1,0}, {0,-1}, {0,1}
  local my_state = {character=config.character, level=config.level, cursor="level", ready=false}
  my_win_count = my_win_count or 0
  local prev_state = shallowcpy(my_state)
  local op_state = global_op_state or {character="lip", level=5, cursor="level", ready=false}
  global_op_state = nil
  op_win_count = op_win_count or 0
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
    json_send({leave_room=true})
  end
  local name_to_xy = {}
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
    local spacing = 4
    local x_padding = math.floor((819-menu_width)/2)
    local y_padding = math.floor((612-menu_height)/2)
    set_color(unpack(colors.white))
    render_x = x_padding+(y-1)*100+spacing
    render_y = y_padding+(x-1)*100+spacing
    grectangle("line", render_x, render_y, w*100-2*spacing, h*100-2*spacing)
    local y_add,x_add = 10,30
    local pstr = str
    if str == "level" then
      if selected and active_str == "level" then
		pstr = pstr .. "\nLevel: < "..my_state.level.." >\nOpponent's level: "..op_state.level
	  else
	    pstr = pstr .. "\nLevel: "..my_state.level.."\nOpponent's level: "..op_state.level
	  end
      y_add,x_add = 9,180
    end
    if my_state.cursor == str then pstr = pstr.."\n"..my_name end
    if op_state.cursor == str then pstr = pstr.."\n"..op_name end
    gprint(pstr, render_x+10, render_y+y_add)
  end
  while true do
    for _,msg in ipairs(this_frame_messages) do
      if msg.menu_state then
        op_state = msg.menu_state
      end
      if msg.leave_room then
		my_win_count = 0
		op_win_count = 0
        return main_net_vs_lobby
      end
      if msg.match_start then
        local fake_P1
		print("currently_spectating: "..tostring(currently_spectating))
		if currently_spectating then
		  print("created fake_P1")
		  fake_P1 = Stack(1, "vs", msg.player_settings.level, msg.player_settings.character)
		  fake_P1.panel_buffer = ""
		  fake_P1.gpanel_buffer = ""
		end
		local fake_P2 = P2
        P1 = Stack(1, "vs", msg.player_settings.level, msg.player_settings.character)
        P2 = Stack(2, "vs", msg.opponent_settings.level, msg.opponent_settings.character)
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
                    P1_char=P1.character,P2_char=P2.character}
        if not currently_spectating then
			ask_for_gpanels("000000")
			ask_for_panels("000000")
		end
        to_print = "Game is starting!\n".."Level: "..P1.level.."\nOpponent's level: "..P2.level
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
    end
    draw_button(1,1,6,1,"level")
    draw_button(1,7,1,1,"ready")
    for i=2,X do
      for j=1,Y do
        draw_button(i,j,1,1,map[i][j])
      end
    end
    gprint(my_name..": "..json.encode(my_state).."  Wins: "..my_win_count.."\n"..op_name..": "..json.encode(op_state).."  Wins: "..op_win_count, 50, 50)
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
			do_leave()
		  elseif active_str == "random" then
			config.character = uniformly(characters)
		  else
			config.character = active_str
			--When we select a character, move cursor to "ready"
			active_str = "ready"
			cursor = shallowcpy(name_to_xy["ready"])
		  end
		elseif menu_escape(k) then
		  if active_str == "leave" then
			do_leave()
		  end
		  cursor = shallowcpy(name_to_xy["leave"])
		end
		active_str = map[cursor[1]][cursor[2]]
		my_state = {character=config.character, level=config.level, cursor=active_str,
					ready=(selected and active_str=="ready")}
		if not content_equal(my_state, prev_state) and not currently_spectating then
		  json_send({menu_state=my_state})
		end
		prev_state = my_state
	else -- (we are are spectating)
		if menu_escape(k) then
		  do_leave()
		  return main_net_vs_lobby
		end
	end
	do_messages()
	
  end
end

function main_net_vs_lobby()
  local active_name, active_idx, active_back = "", 1
  local items
  local unpaired_players = {} -- list
  local willing_players = {} -- set
  local spectatable_rooms = {}
  local k = K[1]
  local notice = {[true]="Select a player name to ask for a match.", [false]="You are all alone in the lobby :("}
  while true do
    for _,msg in ipairs(this_frame_messages) do
      if msg.choose_another_name then
        error("name is taken :<")
      end
      if msg.create_room or msg.spectate_request_granted then
        return main_net_vs_room
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
    end
    local to_print = ""
    local arrow = ""
    items = {}
    for _,v in ipairs(unpaired_players) do
      if v ~= config.name then
        items[#items+1] = v
      end
    end
	local lastPlayerIndex = #items --the rest of the items will be spectatable rooms, except the last item
    for _,v in ipairs(spectatable_rooms) do
	  items[#items+1] = v
	end
    if active_back then
      if active_idx ~= 1 then
        active_idx = #items+1
      end
    else
      while active_idx > #items do
        active_idx = active_idx - 1
      end
      active_name = items[active_idx]
    end
	
	items[#items+1] = "Back to main menu" -- the last item is "Back to the main menu"
    for i=1,#items do
      if active_idx == i then
        arrow = arrow .. ">"
      else
        arrow = arrow .. "\n"
      end
	  if i <= lastPlayerIndex then
		to_print = to_print .. "   " .. items[i] .. (willing_players[items[i]] and " (Wants to play with you :o)" or "") .. "\n"
	  elseif i < #items and items[i].name then
	    to_print = to_print .. "   spectate " .. items[i].name .. " (".. items[i].state .. ")\n" --printing room names 
	  else
	    to_print = to_print .. "   " .. items[i]
	  end
    end
    gprint(notice[#items > 1], 300, 250)
    gprint(arrow, 300, 280)
    gprint(to_print, 300, 280)
    wait()
    if menu_up(k) then
      active_idx = wrap(1, active_idx-1, #items)
    elseif menu_down(k) then
      active_idx = wrap(1, active_idx+1, #items)
    elseif menu_enter(k) then
      if active_idx == #items then
        return main_select_mode
      end
	  if active_idx <= lastPlayerIndex then
		
		op_name = items[active_idx]
		currently_spectating = false
		request_game(items[active_idx])
	  else
	    my_name = items[active_idx].a
		op_name = items[active_idx].b
	    currently_spectating = true
	    request_spectate(items[active_idx].roomNumber)
	  end
    elseif menu_escape(k) then
      if active_idx == #items then
        return main_select_mode
      else
        active_idx = #items
      end
    end
    active_back = active_idx == #items
    do_messages()
  end
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
  while not connection_is_ready() do
    gprint("Connecting...", 300, 280)
    wait()
    do_messages()
  end
  if true then return main_net_vs_lobby end
  local my_level, to_print, fake_P2 = 5, nil, P2
  local k = K[1]
  while got_opponent == nil do
    gprint("Waiting for opponent...", 300, 280)
    do_messages()
    wait()
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
              P1_level=P1_level,P2_level=P2_level}
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
        return main_net_vs_lobby
      end
    end
	gprint(my_name, 315, 40)
	gprint(op_name, 410, op_name_y)
	gprint("Wins: "..my_win_count, 315, 70)
	gprint("Wins: "..op_win_count, 410, 70)
	--TODO: allow spectators to leave a game in progress
	--if menu_escape(k) and currently_spectating then
	--	  do_leave()
	--	  return main_net_vs_lobby
	--end
    P1:render()
    P2:render()
    wait()
    do_messages()
    print(P1.CLOCK, P2.CLOCK)
    variable_step(function()
      if not P1.game_over then
		if currently_spectating then
		  P1:foreign_run()
		else
          P1:local_run() 
		end
	  end
	end)
    if not P2.game_over then
      P2:foreign_run()
    end
    if P1.game_over and P2.game_over and P1.CLOCK == P2.CLOCK then
      end_text = "Draw"
    elseif P1.game_over and P1.CLOCK <= P2.CLOCK then
      end_text = op_name.." Wins :("
	  op_win_count = op_win_count + 1
    elseif P2.game_over and P2.CLOCK <= P1.CLOCK then
      end_text = my_name.." Wins ^^"
	  my_win_count = my_win_count + 1
    end
    if end_text then
      undo_stonermode()
      write_replay_file()
      json_send({game_over=true})
      return main_dumb_transition, {main_net_vs_lobby, end_text, 45, 180}
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

function main_replay_vs()
  local replay = replay.vs
  P1 = Stack(1, "vs", replay.P1_level or 5)
  P2 = Stack(2, "vs", replay.P2_level or 5)
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
  P1:starting_state()
  P2:starting_state()
  local end_text = nil
  local run = true
  while true do
    mouse_panel = nil
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
      end_text = "You lose :("
    elseif P2.game_over and P2.CLOCK <= P1.CLOCK then
      end_text = "You win ^^"
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
    if this_frame_keys["return"] then
      run = not run
    end
    if this_frame_keys["\\"] then
      run = false
    end
    if run or this_frame_keys["\\"] then
      if P1.game_over then
      -- TODO: proper game over.
        return main_dumb_transition, {main_select_mode, "You scored "..P1.score}
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
            return main_dumb_transition, {main_select_puzz, "You win!"}
          else
            return main_dumb_transition, {ret, "You win!"}
          end
        elseif P1.puzzle_moves == 0 then
          write_replay_file()
          return main_dumb_transition, {main_select_puzz, "You lose :("}
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
  love.audio.stop()
  if (not SFX_mute and SFX_GameOver_Play) then
	SFX_GameOver:play()
  end
  SFX_GameOver_Play = 0

  text = text or ""
  timemin = timemin or 0
  timemax = timemax or 3600
  local t = 0
  local k = K[1]
  while true do
    if next_func == main_net_vs_room then
      for _,msg in ipairs(this_frame_messages) do
        if msg.menu_state then
          global_op_state = msg.menu_state
        end
      end
    end
    gprint(text, 300, 280)
    wait()
    if t >= timemin and (t >=timemax or (menu_enter(k) or menu_escape(k))) then
      return next_func
    end
    t = t + 1
    if TCP_sock then
      do_messages()
    end
  end
end

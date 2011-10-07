local wait = coroutine.yield

local main_select_mode, main_endless, make_main_puzzle, main_net_vs_setup,
  main_replay_endless, main_replay_puzzle, main_net_vs,
  main_config_input, main_dumb_transition, main_select_puzz,
  menu_up, menu_down, menu_left, menu_right, menu_enter, menu_escape

function fmainloop()
  local func, arg = main_select_mode, nil
  while true do
    func,arg = func(unpack(arg or {}))
  end
end

local menu_reserved_keys = {z=true, x=true, up=true,
  down=true, ["return"]=true, kenter=true, escape=true}

function repeating_key(key)
  local key_time = keys[key]
  return this_frame_keys[key] or
    (key_time and key_time > 25 and key_time % 3 ~= 0)
end

function menu_up()
  return repeating_key("up") or
    (repeating_key(k_up) and not menu_reserved_keys[k_up])
end

function menu_down()
  return repeating_key("down") or
    (repeating_key(k_down) and not menu_reserved_keys[k_down])
end

function menu_left()
  return repeating_key("left") or
    (repeating_key(k_left) and not menu_reserved_keys[k_left])
end

function menu_right()
  return repeating_key("right") or
    (repeating_key(k_right) and not menu_reserved_keys[k_right])
end

function menu_enter()
  return this_frame_keys["return"] or this_frame_keys["kenter"] or
    this_frame_keys["z"] or
    (this_frame_keys[k_swap1] and not menu_reserved_keys[k_swap1])
end

function menu_escape()
  return this_frame_keys["escape"] or this_frame_keys["x"] or
    (this_frame_keys[k_swap2] and not menu_reserved_keys[k_swap2])
end

do
  local active_idx = 1
  function main_select_mode()
    local items = {{"1P endless", main_select_speed_99, {main_endless}},
        {"1P puzzle", main_select_puzz},
        {"1P time attack", main_select_speed_99, {main_time_attack}},
        {"2P fakevs at dustinho.com", main_net_vs_setup, {"dustinho.com"}},
        {"2P fakevs on localhost", main_net_vs_setup, {"127.0.0.1"}},
        {"Replay of 1P endless", main_replay_endless},
        {"Replay of 1P puzzle", main_replay_puzzle},
        {"Configure input", main_config_input},
        {"Quit", os.exit}}
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
      if menu_up() then
        active_idx = wrap(1, active_idx-1, #items)
      elseif menu_down() then
        active_idx = wrap(1, active_idx+1, #items)
      elseif menu_enter() then
        print(items[active_idx][2])
        return items[active_idx][2], items[active_idx][3]
      elseif menu_escape() then
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
    if menu_up() then
      active_idx = wrap(1, active_idx-1, #items)
    elseif menu_down() then
      active_idx = wrap(1, active_idx+1, #items)
    elseif menu_right() then
      if active_idx==1 then speed = bound(1,speed+1,99)
      elseif active_idx==2 then difficulty = bound(1,difficulty+1,3) end
    elseif menu_left() then
      if active_idx==1 then speed = bound(1,speed-1,99)
      elseif active_idx==2 then difficulty = bound(1,difficulty-1,3) end
    elseif menu_enter() then
      if active_idx == 3 then
        return items[active_idx][2], {speed, difficulty, ...}
      elseif active_idx == 4 then
        return items[active_idx][2], items[active_idx][3]
      else
        active_idx = wrap(1, active_idx + 1, #items)
      end
    elseif menu_escape() then
      if active_idx == #items then
        return items[active_idx][2], items[active_idx][3]
      else
        active_idx = #items
      end
    end
  end
end

function main_endless(...)
  replay.endless = {}
  local replay=replay.endless
  replay.pan_buf = ""
  replay.in_buf = ""
  replay.gpan_buf = ""
  replay.mode = "endless"
  P1 = Stack("endless", ...)
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
    P1:local_run()
    --groundhogday mode
    --[[if P1.CLOCK == 1001 then
      local prev_states = P1.prev_states
      P1 = prev_states[600]
      P1.prev_states = prev_states
    end--]]
  end
end

function main_time_attack(...)
  P1 = Stack("time", ...)
  make_local_panels(P1, "000000")
  while true do
    P1:render()
    wait()
    if P1.game_over or P1.CLOCK == 120*60 then
    -- TODO: proper game over.
      return main_dumb_transition, {main_select_mode, "You scored "..P1.score}
    end
    P1:local_run()
  end
end

function main_net_vs_setup(ip)
  P1, P1_level, P2_level, got_opponent = nil, nil, nil, nil, nil
  P2 = {panel_buffer="", gpanel_buffer=""}
  network_init(ip)
  local my_level, to_print, fake_P2 = 5, nil, P2
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
    elseif menu_enter() then
      P1_level = my_level
      net_send("L"..(({[10]=0})[my_level] or my_level))
    elseif menu_up() or menu_right() then
      my_level = bound(1,my_level+1,10)
    elseif menu_down() or menu_left() then
      my_level = bound(1,my_level-1,10)
    end
  end
  P1 = Stack("vs", P1_level)
  P2 = Stack("vs", P2_level)
  P2.panel_buffer = fake_P2.panel_buffer
  P2.gpanel_buffer = fake_P2.gpanel_buffer
  P1.garbage_target = P2
  P2.garbage_target = P1
  P2.pos_x = 172
  P2.score_x = 410
  replay.vs = {P="",O="",I="",Q="",R="",in_buf=""}
  ask_for_panels("000000")
  ask_for_gpanels("000000")
  to_print = "Level: "..my_level.."\nOpponent's level: "..(P2_level or "???")
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
  local end_text = nil
  while true do
    P1:render()
    P2:render()
    wait()
    do_messages()
    if not P1.game_over then
      P1:local_run()
    end
    if not P2.game_over then
      P2:foreign_run()
    end
    if P1.game_over and P2.game_over and P1.CLOCK == P2.CLOCK then
      end_text = "Draw"
    elseif P1.game_over and P1.CLOCK <= P2.CLOCK then
      end_text = "You lose :("
    elseif P2.game_over and P2.CLOCK <= P1.CLOCK then
      end_text = "You win ^^"
    end
    if end_text then
      undo_stonermode()
      write_replay_file()
      close_socket()
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
  P1 = Stack("endless",replay.speed, replay.difficulty)
  P1.garbage_target = P1
  P1.max_runs_per_frame = 1
  P1.input_buffer = table.concat({replay.in_buf})
  P1.panel_buffer = replay.pan_buf
  P1.gpanel_buffer = replay.gpan_buf
  P1.speed = replay.speed
  P1.difficulty = replay.difficulty
  while true do
    P1:render()
    wait()
    if P1.game_over then
    -- TODO: proper game over.
      return main_dumb_transition, {main_select_mode, "You scored "..P1.score}
    end
    P1:foreign_run()
  end
end

function main_replay_puzzle()
  local replay = replay.puzzle
  if replay.in_buf == nil or replay.in_buf == "" then
    return main_dumb_transition,
      {main_select_mode, "I don't have a puzzle replay :("}
  end
  P1 = Stack("puzzle")
  P1.max_runs_per_frame = 1
  P1.input_buffer = replay.in_buf
  P1:set_puzzle_state(unpack(replay.puzzle))
  while true do
    P1:render()
    wait()
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

function make_main_puzzle(puzzles)
  local awesome_idx, ret = 1, nil
  function ret()
    replay.puzzle = {}
    local replay = replay.puzzle
    P1 = Stack("puzzle")
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
      P1:local_run()
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
      if menu_up() then
        active_idx = wrap(1, active_idx-1, #items)
      elseif menu_down() then
        active_idx = wrap(1, active_idx+1, #items)
      elseif menu_enter() then
        return items[active_idx][2], items[active_idx][3]
      elseif menu_escape() then
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
  local function get_items()
    items = {}
    for i=1,#key_names do
      items[#items+1] = {pretty_names[i], _G[key_names[i]]}
    end
    items[#items+1] = {"Set all keys", ""}
    items[#items+1] = {"Back", "", main_select_mode}
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
          _G[key_names[idx]] = key
          brk = true
        end
      end
    end
  end
  while true do
    get_items()
    print_stuff()
    wait()
    if menu_up() then
      active_idx = wrap(1, active_idx-1, #items)
    elseif menu_down() then
      active_idx = wrap(1, active_idx+1, #items)
    elseif menu_enter() then
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
    elseif menu_escape() then
      if active_idx == #items then
        return items[active_idx][3], items[active_idx][4]
      else
        active_idx = #items
      end
    end
  end
end

function main_dumb_transition(next_func, text)
  text = text or ""
  while true do
    gprint(text, 300, 280)
    wait()
    if menu_enter() or menu_escape() then
      return next_func
    end
  end
end

local wait = coroutine.yield

local main_select_mode, main_solo, main_puzzle, main_net_vs_setup,
  main_replay_endless, main_replay_puzzle, main_net_vs,
  main_config_input,
  menu_up, menu_down, menu_left, menu_right, menu_enter, menu_escape

function fmainloop()
  local func, arg = main_select_mode, nil
  while true do
    func,arg = func(arg)
  end
end

local menu_reserved_keys = {z=true, x=true, up=true,
  down=true, ["return"]=true, kenter=true, escape=true}

function menu_up()
  return this_frame_keys["up"] or
    (this_frame_keys[k_up] and not menu_reserved_keys[k_up])
end

function menu_down()
  return this_frame_keys["down"] or
    (this_frame_keys[k_down] and not menu_reserved_keys[k_down])
end

function menu_left()
  return this_frame_keys["left"] or
    (this_frame_keys[k_left] and not menu_reserved_keys[k_left])
end

function menu_right()
  return this_frame_keys["right"] or
    (this_frame_keys[k_right] and not menu_reserved_keys[k_right])
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

function main_select_mode()
  local items = {{"1P endless", main_solo},
      {"1P puzzle", main_puzzle},
      {"2P endless at Tom's apartment", main_net_vs_setup, "sfo.zkpq.ca"},
      {"2P endless on localhost", main_net_vs_setup, "127.0.0.1"},
      {"Replay of 1P endless", main_replay_endless},
      {"Replay of 1P puzzle", main_replay_puzzle},
      {"Configure input", main_config_input},
      {"Quit", os.exit}}
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
      active_idx = ((active_idx - 2) % #items)+1
    elseif menu_down() then
      active_idx = (active_idx % #items)+1
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

function main_solo()
  replay_pan_buf = ""
  replay_in_buf = ""
  P1 = Stack()
  make_local_panels(P1, "000000")
  while true do
    P1:local_run()
    wait()
    if P1.game_over then
    -- TODO: proper game over.
      return main_select_mode
    end
  end
end

function main_net_vs_setup(ip)
  network_init(ip)
  P1 = Stack()
  P2 = Stack()
  P2.pos_x = 172
  P2.score_x = 410
  while P1.panel_buffer == "" or P2.panel_buffer == "" do
    gprint("Waiting for opponent...", 300, 280)
    do_messages()
    wait()
  end
  return main_net_vs
end

function main_net_vs()
  while true do
    do_messages()
    P1:local_run()
    P2:foreign_run()
    if P1.game_over then
      error("game over lol")
    end
    wait()
  end
  -- TODO: transition to some other state instead of erroring.
end

function main_replay_endless()
  P1 = Stack()
  P1.max_runs_per_frame = 1
  P1.input_buffer = replay_in_buf
  P1.panel_buffer = replay_pan_buf
  while true do
    P1:foreign_run()
    wait()
    if P1.game_over then
    -- TODO: proper game over.
      return main_select_mode
    end
  end
end

function main_replay_puzzle()
  P1 = Stack()
  P1.max_runs_per_frame = 1
  P1.input_buffer = preplay_in_buf
  P1:set_puzzle_state(unpack(preplay_puzz))
  P1.cur_row = 7
  P1.cur_col = 3
  while true do
    P1:foreign_run()
    wait()
    if P1.n_active_panels == 0 then
      if P1:puzzle_done() then
        return main_select_mode
      elseif P1.puzzle_moves == 0 then
        return main_select_mode
      end
    end
  end
end

local awesome_idx = 1
function main_puzzle()
  P1 = Stack()
  P1.cur_row = 7
  P1.cur_col = 3
  local puzzles = {
  {"032510036520646325641313412143112146325461131516131516416123442315632515",5},
  {"4000441101", 1},
  {"223233", 1},
  {"400000600000600046400", 1},
  {"100001300033100", 1},
  {"4200002400002400", 1},
  {"2000024400043300211310", 1},
  {"5000001200014500043420166350226232", 1},
  {"214365214365662622214365214365", 1},
  {"5000054550441310513350", 2},
  {"40000040000030000042000025200051200066500031320556512", 3},
  {"111111555555666666333333222222444444111111555555666666333333222222444444",1},
  {"010000019000199900911900991900", 3},
  {"006020006020001013412143412146325461131516131516416123",5},
  }
  if awesome_idx == nil then
    awesome_idx = math.random(#puzzles)
  end
  P1:set_puzzle_state(unpack(puzzles[awesome_idx]))
  preplay_puzz = puzzles[awesome_idx]
  preplay_in_buf = ""
  while true do
    P1:local_run()
    if P1.n_active_panels == 0 then
      if P1:puzzle_done() then
        awesome_idx = (awesome_idx % #puzzles) + 1
        return main_puzzle
      elseif P1.puzzle_moves == 0 then
        return main_select_mode
      end
    end
    wait()
  end
end

preplay_puzz = {"032510036520646325641313412143112146325461131516131516416123442315632515",5}
preplay_in_buf = {
"0000000000000000000000",
"0000000000000000000000",
"0000000000000000000000",
"0000000000000000000000",
"0000000000000000000000",
"0000000001000000000000",
"0000000000000000000000",
"0000000000000000000000",
"0000000001000000000000",
"0000000000000000000000",
"0000000000000000000000",
"0000000000000000001000",
"0000000010000000000000",
"0000000000000000000000",
"0000000000000000001000",
"0000000010000000000000",
"0000000000000000001000",
"0000000010000000000000",
"0000000000000000000000",
"0000000000000000001000",
"0000000010000000000000",
"0000000000000000000000",
"0000000000000000001000"}
for i=1,70 do
  table.insert(preplay_in_buf, 11, "0000000000000000000000")
end
for i=1,70 do
  table.insert(preplay_in_buf, 1, "0000000000000000000000")
end
for i=#preplay_in_buf+1,1000 do
  preplay_in_buf[i] ="0000000000000000000000"
end
preplay_in_buf=table.concat(preplay_in_buf)

function main_config_input()
  local key_names = {"k_up", "k_down", "k_left", "k_right", "k_swap1",
    "k_swap2", "k_raise1", "k_raise2"}
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
      active_idx = ((active_idx - 2) % #items)+1
    elseif menu_down() then
      active_idx = (active_idx % #items)+1
    elseif menu_enter() then
      if active_idx <= #key_names then
        set_key(active_idx)
      elseif active_idx == #key_names + 1 then
        for i=1,8 do
          set_key(i)
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

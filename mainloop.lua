local wait = coroutine.yield

function fmainloop()
  local func = main_select_mode
  local arg = nil
  while true do
    func,arg = func(arg)
  end
end

function main_select_mode()
  local items = {{"1P endless", main_solo},
      {"1P puzzle", main_puzzle},
      {"2P endless at Tom's apartment", main_net_vs_setup, "sfo.zkpq.ca"},
      {"2P endless on localhost", main_net_vs_setup, "sfo.zkpq.ca"},
      {"Replay of 1P endless", main_replay},
      {"Quit", exit}}
  local active_idx = 1
  while true do
    to_print = ""
    arrow = ""
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
    if this_frame_keys[k_up] then
      active_idx = ((active_idx - 2) % #items)+1
    elseif this_frame_keys[k_down] then
      active_idx = (active_idx % #items)+1
    elseif this_frame_keys[k_swap1] or this_frame_keys["return"] or
        this_frame_keys["kpenter"] then
      return items[active_idx][2], items[active_idx][3]
    elseif this_frame_keys[k_swap2] or this_frame_keys["escape"] then
      if active_idx == 6 then
        exit()
      else
        active_idx = 6
      end
    end
    wait()
  end
end

function main_solo()
  replay_pan_buf = ""
  replay_in_buf = ""
  P1 = Stack()
  make_local_panels(P1, "000000")
  while true do
    P1:local_run()
    if P1.game_over then
    -- TODO: proper game over.
      return main_select_mode
    end
    wait()
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

function main_replay()
  P1 = Stack()
  P1.max_runs_per_frame = 1
  P1.input_buffer = replay_in_buf..""
  P1.panel_buffer = replay_pan_buf..""
  while true do
    P1:foreign_run()
    if P1.game_over then
    -- TODO: proper game over.
      return main_select_mode
    end
    wait()
  end
end

function main_puzzle()
  replay_pan_buf = ""
  replay_in_buf = ""
  P1 = Stack()
  P1.puzzle_mode = true
  P1:set_puzzle_state("010000019000199900911900991900", 3)
  while true do
    P1:local_run()
    if P1.n_active_panels == 0 then
      if P1:puzzle_done() then
        return main_select_mode
      elseif P1.puzzle_moves == 0 then
        error("PUZZLE LOSE :(")
      end
    end
    wait()
  end
end

local replay_browser = {}

replay_browser.selection     = nil
replay_browser.base_path     = "replays"
replay_browser.current_path  = "/"
replay_browser.path_contents = {}
replay_browser.filename      = nil
replay_browser.state         = "browser"

replay_browser.menu_x        = 400
replay_browser.menu_y        = 280
replay_browser.menu_h        = 14
replay_browser.menu_cursor_offset = 16

replay_browser.cursor_pos    = 0

replay_browser.replay_id_top = 0

function replay_browser.main()

  local function replay_browser_menu()
    if (replay_browser.replay_id_top == 0) then
      if replay_browser.current_path ~= "/" then
        gprint("< " .. loc("rp_browser_up") .. " >", replay_browser.menu_x, replay_browser.menu_y)
      else
        gprint("< " .. loc("rp_browser_root") .. " >", replay_browser.menu_x, replay_browser.menu_y)
      end
    else
      gprint("^ " .. loc("rp_browser_more") .. " ^", replay_browser.menu_x, replay_browser.menu_y)
    end

    for i,p in pairs(replay_browser.path_contents) do
      if (i > replay_browser.replay_id_top) and (i <= replay_browser.replay_id_top + 20) then
        gprint(p, replay_browser.menu_x, replay_browser.menu_y + (i - replay_browser.replay_id_top) * replay_browser.menu_h)
      end
    end

    if #replay_browser.path_contents > replay_browser.replay_id_top + 20 then
      gprint("v " .. loc("rp_browser_more") .. " v", replay_browser.menu_x, replay_browser.menu_y + 21 * replay_browser.menu_h)
    end

    gprint(">", replay_browser.menu_x - replay_browser.menu_cursor_offset + math.sin(love.timer.getTime() * 8) * 5, replay_browser.menu_y + (replay_browser.cursor_pos - replay_browser.replay_id_top) * replay_browser.menu_h)
  end

  local function replay_browser_cursor(move)
    replay_browser.cursor_pos  = wrap(0, replay_browser.cursor_pos + move, #replay_browser.path_contents)
    if replay_browser.cursor_pos <= replay_browser.replay_id_top then
      replay_browser.replay_id_top = math.max(replay_browser.cursor_pos, 1) - 1
    end
    if replay_browser.replay_id_top < replay_browser.cursor_pos - 20 then
      replay_browser.replay_id_top = replay_browser.cursor_pos - 20
    end
  end

  local function replay_browser_update(new_path)
    if new_path then
      replay_browser.cursor_pos    = 0
      replay_browser.replay_id_top = 0
      if new_path == "" then
        new_path  = "/"
      end
      replay_browser.current_path  = new_path
    end
    replay_browser.path_contents  = get_directory_contents(replay_browser.base_path .. replay_browser.current_path)
  end

  local function replay_browser_go_up()
    replay_browser_update(replay_browser.current_path:gsub("(.*/).*/$","%1"))
  end


  local function replay_browser_load_details(path)

    replay_browser.filename  = path
    local file, error_msg  = love.filesystem.read(replay_browser.filename)

    if file == nil then
      print(loc("rp_browser_error_loading", error_msg))
      return false
    end

    replay = json.decode(file)
    if type(replay.in_buf) == "table" then
      replay.in_buf = table.concat(replay.in_buf)
    end
    return true

  end


  local function replay_browser_select()
    if replay_browser.cursor_pos == 0 then
      replay_browser_go_up()

    else
      replay_browser.selection  = replay_browser.base_path .. replay_browser.current_path .. replay_browser.path_contents[replay_browser.cursor_pos]
      local file_info  = love.filesystem.getInfo(replay_browser.selection)
      if file_info then
        if file_info.type == "file" then
          return replay_browser_load_details(replay_browser.selection)
        elseif file_info.type == "directory" then
          replay_browser_update(replay_browser.current_path .. replay_browser.path_contents[replay_browser.cursor_pos] .."/")
        else
          print(loc("rp_browser_error_unknown_filetype", file_info.type, replay_browser.selection))
        end
      else
        print(loc("rp_browser_error_file_not_found", replay_browser.selection))
      end
    end
  end

  replay_browser.state = "browser"
  replay_browser_update()

  coroutine.yield()

  while true do
    local ret = nil


    if replay_browser.state == "browser" then

      gprint(loc("rp_browser_header"), replay_browser.menu_x + 170, replay_browser.menu_y - 40)
      gprint(loc("rp_browser_current_dir", replay_browser.base_path .. replay_browser.current_path), replay_browser.menu_x, replay_browser.menu_y - 40 + replay_browser.menu_h)
      replay_browser_menu()

      variable_step(function()
        local k = K[1]
        if menu_escape(k) then
          ret = {main_select_mode}
        elseif menu_enter(k) then
          if replay_browser_select() then
            replay_browser.state  = "info"
          end
        elseif menu_backspace(k) then
          replay_browser_go_up()
        else
          if menu_up(k) then
            replay_browser_cursor(-1)
          end
          if menu_down(k) then
            replay_browser_cursor(1)
          end
        end
      end)

    elseif replay_browser.state == "info" then
      local next_func = nil

      gprint(loc("rp_browser_info_header"), replay_browser.menu_x + 170, replay_browser.menu_y - 40) 
      gprint(replay_browser.filename, replay_browser.menu_x - 150, replay_browser.menu_y - 40 + replay_browser.menu_h)

      if replay.vs then
        gprint(loc("rp_browser_info_2p_vs"), replay_browser.menu_x + 220, replay_browser.menu_y + 20)

        gprint(loc("rp_browser_info_1p"), replay_browser.menu_x, replay_browser.menu_y + 50)
        gprint(loc("rp_browser_info_name", replay.vs.P1_name), replay_browser.menu_x, replay_browser.menu_y + 65)
        gprint(loc("rp_browser_info_level", replay.vs.P1_level), replay_browser.menu_x, replay_browser.menu_y + 80)
        gprint(loc("rp_browser_info_character", replay.vs.P1_char), replay_browser.menu_x, replay_browser.menu_y + 95)

        gprint(loc("rp_browser_info_2p"), replay_browser.menu_x + 300, replay_browser.menu_y + 50)
        gprint(loc("rp_browser_info_name", replay.vs.P2_name), replay_browser.menu_x + 300, replay_browser.menu_y + 65)
        gprint(loc("rp_browser_info_level", replay.vs.P2_level), replay_browser.menu_x + 300, replay_browser.menu_y + 80)
        gprint(loc("rp_browser_info_character", replay.vs.P2_char), replay_browser.menu_x + 300, replay_browser.menu_y + 95)

        if replay.vs.ranked then
          gprint(loc("rp_browser_info_ranked"), replay_browser.menu_x + 200, replay_browser.menu_y + 120)
        end

        next_func = main_replay_vs

      elseif replay.endless then
        gprint(loc("rp_browser_info_endless"), replay_browser.menu_x + 220, replay_browser.menu_y + 20)

        gprint(loc("rp_browser_info_speed", replay.endless.speed), replay_browser.menu_x + 150, replay_browser.menu_y + 50)
        gprint(loc("rp_browser_info_difficulty", replay.endless.difficulty), replay_browser.menu_x + 150, replay_browser.menu_y + 65)

        next_func = main_replay_endless

      elseif replay.puzzle then
        gprint(loc("rp_browser_info_puzzle"), replay_browser.menu_x + 220, replay_browser.menu_y + 20)

        gprint(loc("rp_browser_no_info"), replay_browser.menu_x + 150, replay_browser.menu_y + 50)

        next_func = main_replay_puzzle

      else
        gprint(loc("rp_browser_error_unknown_replay_type"), replay_browser.menu_x + 220, replay_browser.menu_y + 20)

      end

      gprint(loc("rp_browser_watch"), replay_browser.menu_x + 75, replay_browser.menu_y + 150)

      variable_step(function()
        local k = K[1]
        if menu_backspace(k) or menu_escape(k) then
          replay_browser.state  = "browser"
        elseif menu_enter(k) then
          if next_func then
            ret = {next_func}
          end
        end
      end)

    end


    if ret then
      return unpack(ret)
    end

    coroutine.yield()

  end

end

return replay_browser

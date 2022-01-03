local wait = coroutine.yield

-- menu for configuring inputs
local function main_config_input()
  local pretty_names = {loc("up"), loc("down"), loc("left"), loc("right"), "A", "B", "X", "Y", "L", "R", loc("start")}
  local menu_x, menu_y = unpack(main_menu_screen_pos)

  local active_player = 1 -- current player we are setting inputs for
  local k = K[active_player] -- keys for that player
  local input_menu = nil
  local createInputMenu
  local idxs_to_set = {} -- indexs we are waiting for the user to key press
  local ret = nil

  local function incrementPlayer()
    active_player = wrap(1, active_player + 1, 2)
    k = K[active_player]
    if input_menu then
      input_menu:remove_self()
    end
    input_menu = createInputMenu(active_player)
  end

  local function selectKey()
    input_menu:set_button_setting(input_menu.active_idx, "___")
    idxs_to_set = {input_menu.active_idx}
  end

  local function selectAllKeys()
    input_menu:set_active_idx(2)
    for i = 1, #key_names do
      input_menu:set_button_setting(i + 1, "___")
      table.insert(idxs_to_set, i + 1)
    end
  end

  local function goEscape()
    input_menu:set_active_idx(#input_menu.buttons)
  end

  local function mainMenu()
    input_menu:remove_self()
    ret = {main_select_mode}
  end

  function createInputMenu(player)
    local clickMenu = Click_menu(menu_x, menu_y, nil, canvas_height - menu_y - 10, 1)
    clickMenu:add_button(loc("player") .. " ", incrementPlayer, goEscape)
    clickMenu:set_button_setting(#clickMenu.buttons, active_player)
    for i = 1, #key_names do
      clickMenu:add_button(pretty_names[i], selectKey, goEscape)
      clickMenu:set_button_setting(#clickMenu.buttons, k[key_names[i]] or loc("op_none"))
    end
    clickMenu:add_button(loc("op_all_keys") .. " ", selectAllKeys, goEscape)
    clickMenu:add_button(loc("back") .. " ", mainMenu, mainMenu)

    return clickMenu
  end

--[[ TODO left and right
         elseif menu_left(K[1]) then
active_player = wrap(1, active_player - 1, 2)
k = K[active_player]
elseif menu_right(K[1]) then
active_player = wrap(1, active_player + 1, 2)
k = K[active_player]
]]

  input_menu = createInputMenu(active_player)

  while true do
    input_menu:draw()
    wait()
    variable_step(
      function()
        if #idxs_to_set > 0 then
          local idx = idxs_to_set[1]
          for key, val in pairs(this_frame_keys) do
            if val then
              k[key_names[idx - 1]] = key
              table.remove(idxs_to_set, 1)
              if #idxs_to_set == 0 then
                write_key_file()
              end
              input_menu:set_active_idx(idx + 1)
              input_menu:set_button_setting(idx, k[key_names[idx - 1]] or loc("op_none"))
            end
          end
        else
          input_menu:update()
        end
      end
    )

    if ret then
      return unpack(ret)
    end
  end
end

return main_config_input
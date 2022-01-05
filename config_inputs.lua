local wait = coroutine.yield

-- menu for configuring inputs
local function main_config_input()
  local pretty_names = {loc("up"), loc("down"), loc("left"), loc("right"), "A", "B", "X", "Y", "L", "R", loc("start")}
  local menu_x, menu_y = unpack(main_menu_screen_pos)

  menu_y = menu_y + 40

  local active_configuration = 1 -- current configuration we are setting inputs for
  local inputConfiguration = GAME.input.inputConfigurations[active_configuration] -- keys for that configuration
  local input_menu = nil
  local createInputMenu
  local idxs_to_set = {} -- indexs we are waiting for the user to key press
  local ret = nil

  local function decrementConfiguration()
    active_configuration = wrap(1, active_configuration - 1, GAME.input.maxConfigurations)
    inputConfiguration = GAME.input.inputConfigurations[active_configuration]
    if input_menu then
      input_menu:remove_self()
    end
    input_menu = createInputMenu(active_configuration)
  end

  local function incrementConfiguration()
    active_configuration = wrap(1, active_configuration + 1, GAME.input.maxConfigurations)
    inputConfiguration = GAME.input.inputConfigurations[active_configuration]
    if input_menu then
      input_menu:remove_self()
    end
    input_menu = createInputMenu(active_configuration)
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

  function createInputMenu(configurationNumber)
    local clickMenu = Click_menu(menu_x, menu_y, nil, canvas_height - menu_y - 10, 1)
    clickMenu:add_button(loc("configuration") .. " ", incrementConfiguration, goEscape, decrementConfiguration, incrementConfiguration)
    clickMenu:set_button_setting(#clickMenu.buttons, configurationNumber)
    for i = 1, #key_names do
      clickMenu:add_button(pretty_names[i], selectKey, goEscape)
      local cleanString = GAME.input:cleanNameForButton(inputConfiguration[key_names[i]]) or loc("op_none")
      clickMenu:set_button_setting(#clickMenu.buttons, cleanString)
    end
    clickMenu:add_button(loc("op_all_keys") .. " ", selectAllKeys, goEscape)
    clickMenu:add_button(loc("back") .. " ", mainMenu, mainMenu)

    return clickMenu
  end

  input_menu = createInputMenu(active_configuration)

  while true do
    gprintf(loc("config_input_welcome"), 0, menu_y - 30, canvas_width, "center")
    input_menu:draw()
    wait()
    variable_step(
      function()
        if #idxs_to_set > 0 then
          local idx = idxs_to_set[1]
          for key, val in pairs(this_frame_keys) do
            if val then
              inputConfiguration[key_names[idx - 1]] = key
              table.remove(idxs_to_set, 1)
              if #idxs_to_set == 0 then
                write_key_file()
              end
              input_menu:set_active_idx(idx + 1)
              local cleanString = GAME.input:cleanNameForButton(inputConfiguration[key_names[idx-1]]) or loc("op_none")
              input_menu:set_button_setting(idx, cleanString)
              break
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
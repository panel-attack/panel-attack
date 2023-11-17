local wait = coroutine.yield

-- menu for configuring inputs
local function main_config_input()
  local pretty_names = {loc("up"), loc("down"), loc("left"), loc("right"), "A", "B", "X", "Y", "L", "R", loc("start")}
  local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
  local ignoreMenuPressesTimer = nil

  local active_configuration = 1 -- current configuration we are setting inputs for
  local inputConfiguration = GAME.input.inputConfigurations[active_configuration] -- keys for that configuration
  local input_menu = nil
  local createInputMenu
  local idxs_to_set = {} -- indexs we are waiting for the user to key press
  local ret = nil

  local function recreateInputMenu()
    inputConfiguration = GAME.input.inputConfigurations[active_configuration]
    if input_menu then
      input_menu:remove_self()
    end
    input_menu = createInputMenu(active_configuration)
  end

  local function decrementConfiguration()
    active_configuration = wrap(1, active_configuration - 1, GAME.input.maxConfigurations)
    recreateInputMenu()
  end

  local function incrementConfiguration()
    active_configuration = wrap(1, active_configuration + 1, GAME.input.maxConfigurations)
    recreateInputMenu()
  end

  local function setConfiguration(configuration)
    active_configuration = wrap(1, configuration, GAME.input.maxConfigurations)
    recreateInputMenu()
  end

  local function selectKey()
    input_menu:set_button_setting(input_menu.active_idx, "___")
    idxs_to_set = {input_menu.active_idx}
  end

  local function selectAllKeys()
    input_menu:set_active_idx(2)
    for i = 1, #KEY_NAMES do
      input_menu:set_button_setting(i + 1, "___")
      table.insert(idxs_to_set, i + 1)
    end
  end


  local function resetKeys()
    setConfiguration(1)

    for i, keys in ipairs(KEY_NAMES) do
      input_menu:set_button_setting(i + 1, KEYS[i])
      inputConfiguration[KEY_NAMES[i]] = KEYS[i]
    end 

    for iConfig = 2, GAME.input.maxConfigurations do
      setConfiguration(iConfig)
      for i = 1, #KEY_NAMES do
        input_menu:set_button_setting(i + 1, loc("op_none"))
        inputConfiguration[KEY_NAMES[i]] = nil
      end
    end

    setConfiguration(1)
    write_key_file()
  end

  local function goEscape()
    input_menu:set_active_idx(#input_menu.buttons)
  end

  local function mainMenu()
    input_menu:remove_self()
    ret = {main_select_mode}
  end

  function createInputMenu(configurationNumber)
    local clickMenu = Click_menu(menu_x, menu_y, nil, themes[config.theme].main_menu_max_height, 1)
    clickMenu:add_button(loc("configuration") .. " ", incrementConfiguration, goEscape, decrementConfiguration, incrementConfiguration)
    clickMenu:set_button_setting(#clickMenu.buttons, configurationNumber)
    for i = 1, #KEY_NAMES do
      clickMenu:add_button(pretty_names[i], selectKey, goEscape)
      local cleanString = GAME.input:cleanNameForButton(inputConfiguration[KEY_NAMES[i]]) or loc("op_none")
      clickMenu:set_button_setting(#clickMenu.buttons, cleanString)
    end
    clickMenu:add_button(loc("op_all_keys") .. " ", selectAllKeys, goEscape)
    clickMenu:add_button("Reset to default controls" .. " ", resetKeys, goEscape)
    clickMenu:add_button(loc("back") .. " ", mainMenu, mainMenu)

    return clickMenu
  end

  input_menu = createInputMenu(active_configuration)

  while true do
    gprintf(loc("config_input_welcome"), 0, input_menu.y - 30, canvas_width, "center")
    input_menu:draw()
    wait()
    variable_step(
      function()
        if #idxs_to_set > 0 then
          local idx = idxs_to_set[1]
          for key, val in pairs(this_frame_keys) do
            if val then
              inputConfiguration[KEY_NAMES[idx - 1]] = key
              table.remove(idxs_to_set, 1)
              if #idxs_to_set == 0 then
                write_key_file()
                ignoreMenuPressesTimer = 30
              end
              input_menu:set_active_idx(idx + 1)
              local cleanString = GAME.input:cleanNameForButton(inputConfiguration[KEY_NAMES[idx-1]]) or loc("op_none")
              input_menu:set_button_setting(idx, cleanString)
              break
            end
          end
        elseif not ignoreMenuPressesTimer then
          input_menu:update()
        end

        if ignoreMenuPressesTimer then
          ignoreMenuPressesTimer = ignoreMenuPressesTimer - 1
          if ignoreMenuPressesTimer == 0 then
            ignoreMenuPressesTimer = nil
          end
        end
      end
    )

    if ret then
      return unpack(ret)
    end
  end
end

return main_config_input
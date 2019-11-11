local options = {}

local wait = coroutine.yield

local memory_before_options_menu = nil

local function main_show_custom_themes_readme(idx)
  bg = themes[config.theme].images.bg_readme

  if not love.filesystem.getInfo("themes/"..prefix_of_ignored_dirs..default_theme_dir) then
    print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
    gprint("Hold on.  Copying an example folder to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
    wait()
    recursive_copy("themes/"..default_theme_dir, "themes/"..prefix_of_ignored_dirs..default_theme_dir)
  end

  local readme = read_txt_file("readme_themes.txt")
  while true do
    gprint(readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(function()
      if menu_escape(K[1]) or menu_enter(K[1]) then
        ret = {options.main, {idx}}
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

local function main_show_custom_stages_readme(idx)
  bg = themes[config.theme].images.bg_readme

  for _,stage in ipairs(default_stages_ids) do
    if not love.filesystem.getInfo("stages/"..prefix_of_ignored_dirs..stage) then
      print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
      gprint("Hold on.  Copying an example folder to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
      wait()
      recursive_copy("stages/"..stage, "stages/"..prefix_of_ignored_dirs..stage)
    end
  end

  local readme = read_txt_file("readme_stages.txt")
  while true do
    gprint(readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(function()
      if menu_escape(K[1]) or menu_enter(K[1]) then
        ret = {options.main, {idx}}
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

local function main_show_custom_characters_readme(idx)
  bg = themes[config.theme].images.bg_readme
  
  for _,current_character in ipairs(default_characters_ids) do
    if not love.filesystem.getInfo("characters/"..prefix_of_ignored_dirs..current_character) then
      print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
      gprint("Hold on.  Copying an example folder to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
      wait()
      recursive_copy("characters/"..current_character, "characters/"..prefix_of_ignored_dirs..current_character)
    end
  end

  local readme = read_txt_file("readme_characters.txt")
  while true do
    gprint(readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(function()
      if menu_escape(K[1]) or menu_enter(K[1]) then
        ret = {options.main, {idx}}
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

local function main_show_custom_panels_readme(idx)
  bg = themes[config.theme].images.bg_readme

 -- add other defaults panels sets here so that anyone can update them if wanted
  local default_panels_dirs = { default_panels_dir }
  
  for _,panels_dir in ipairs(default_panels_dirs) do
    if not love.filesystem.getInfo("panels/"..prefix_of_ignored_dirs..panels_dir) then
      print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
      gprint("Hold on. Copying example folders to make this easier...\n\nThis may take a few seconds or maybe even a minute or two.\n\nDon't worry if the window goes inactive or \"not responding\"", 280, 280)
      wait()
      recursive_copy("panels/"..panels_dir, "panels/"..prefix_of_ignored_dirs..panels_dir)
    end
  end

  local readme = read_txt_file("readme_panels.txt")
  while true do
    gprint(readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(function()
      if menu_escape(K[1]) or menu_enter(K[1]) then
        ret = {options.main, {idx}}
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

local function exit_options_menu()
  gprint("writing config to file...", unpack(main_menu_screen_pos))
  wait()

  local selected_theme = memory_before_options_menu.theme
  memory_before_options_menu.theme = config.theme
  config.theme = selected_theme

  write_conf_file()

  if config.theme ~= memory_before_options_menu.theme then
    gprint("reloading theme...", unpack(main_menu_screen_pos))
    wait()
    stop_the_music()
    theme_init()
    if themes[config.theme].musics["main"] then
      find_and_add_music(themes[config.theme].musics, "main")
    end
  end

  if config.theme ~= memory_before_options_menu.theme 
    or config.use_music_from ~= memory_before_options_menu.use_music_from then
    gprint("reloading characters...", unpack(main_menu_screen_pos))
    wait()
    characters_init()
  end

  if config.use_music_from ~= memory_before_options_menu.use_music_from then
    gprint("reloading stages...", unpack(main_menu_screen_pos))
    wait()
    stages_init()
  end

  if config.enable_analytics ~= memory_before_options_menu.enable_analytics then
    gprint("reloading analytics...", unpack(main_menu_screen_pos))
    wait()
    analytics_init()
  end

  apply_config_volume()

  memory_before_options_menu = nil
  normal_music_for_sound_option = nil
  return main_select_mode
end

function options.main(starting_idx)
  bg = themes[config.theme].images.bg_main
  local items, active_idx = {}, starting_idx or 1
  local k = K[1]
  local selected, deselected_this_frame, adjust_active_value = false, false, false
  local save_replays_publicly_choices = {"with my name", "anonymously", "not at all"}
  local use_music_from_choices = {"stage", "characters"}
  local on_off_text = {[true]="On", [false]="Off"}
  memory_before_options_menu = { theme=config.theme,--this one is actually updated with the menu and change upon leaving, be careful!
                                enable_analytics=config.enable_analytics,
                                use_music_from=config.use_music_from }
  --make so we can get "anonymously" from save_replays_publicly_choices["anonymously"]
  for k,v in ipairs(save_replays_publicly_choices) do
    save_replays_publicly_choices[v] = v
  end
  for k,v in ipairs(use_music_from_choices) do
    use_music_from_choices[v] = v
  end

  local function get_dir_set(set,path)
    local raw_dir_list = love.filesystem.getDirectoryItems(path)
    for k,v in ipairs(raw_dir_list) do
      local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
      if love.filesystem.getInfo(path.."/"..v) and start_of_v ~= prefix_of_ignored_dirs then
        set[#set+1] = v
      end
    end
  end

  local themes_set = {}
  get_dir_set(themes_set,"themes")
  local panels_set = {}
  get_dir_set(panels_set,"panels")

  local normal_music_for_sound_option = nil
  local function update_normal_music_for_sound_volume_option()
    if config.use_music_from == "stage" then
      local stage_id = config.stage
      if stage_id == random_stage_special_value then
        stage_id = uniformly(stages_ids_for_current_theme)
      end
      stage_loader_load(stage_id)
      stage_loader_wait()
      normal_music_for_sound_option = stages[stage_id].musics.normal_music
    else
      if config.character == random_character_special_value then
        local random_id = uniformly(characters_ids_for_current_theme)
        character_loader_load(random_id)
        character_loader_wait()
        normal_music_for_sound_option = characters[random_id].musics.normal_music
      else
        -- config.character should already be loaded!
        normal_music_for_sound_option = characters[config.character].musics.normal_music
      end
    end
  end
  update_normal_music_for_sound_volume_option()

  items = {
    --options menu table reference:
    --{[1]"Option Name", [2]current or default value, [3]type, [4]min or bool value or choices_table,
    -- [5]max, [6]sound_source, [7]selectable, [8]next_func, [9]play_while selected}
    {"Master Volume", config.master_volume, "numeric", 0, 100, normal_music_for_sound_option, true, nil, true},
    {"SFX Volume", config.SFX_volume, "numeric", 0, 100, themes[config.theme].sounds.cur_move, true},
    {"Music Volume", config.music_volume, "numeric", 0, 100, normal_music_for_sound_option, true, nil, true},
    {"Debug Mode", on_off_text[config.debug_mode], "bool", false, nil, nil,false},
    {"Save replays publicly", save_replays_publicly_choices[config.save_replays_publicly] or save_replays_publicly_choices["with my name"], "multiple choice", save_replays_publicly_choices},
    {"Theme", config.theme, "multiple choice", themes_set},
    {"Ready countdown", on_off_text[config.ready_countdown_1P], "bool", true, nil, nil,false},
    {"Show FPS", on_off_text[config.show_fps], "bool", true, nil, nil,false},
    {"Danger music change-back delay", on_off_text[config.danger_music_changeback_delay], "bool", false, nil, nil, false},
    {"Enable analytics", on_off_text[config.enable_analytics], "bool", false, nil, nil, false},
    {"Use music from", use_music_from_choices[config.use_music_from], "multiple choice", use_music_from_choices},
    {"About custom themes", "", "function", nil, nil, nil, nil, main_show_custom_themes_readme},
    {"About custom characters", "", "function", nil, nil, nil, nil, main_show_custom_characters_readme},
    {"About custom stages", "", "function", nil, nil, nil, nil, main_show_custom_stages_readme},
    {"About custom panels", "", "function", nil, nil, nil, nil, main_show_custom_panels_readme},
    {"Back", "", nil, nil, nil, nil, false, main_select_mode}
  }
  local function print_stuff()
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
          elseif items[active_idx][1] == "Show FPS" then
            config.show_fps = not config.show_fps
            items[active_idx][2] = on_off_text[config.show_fps]
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
          if items[active_idx][1] == "Save replays publicly" then
            config.save_replays_publicly = items[active_idx][2]
          -- don't change config.theme directly here as it is used while being in this menu! instead we change it upon leaving
          elseif items[active_idx][1] == "Theme" then
            memory_before_options_menu.theme = items[active_idx][2]
          elseif items[active_idx][1] == "Use music from" then
            config.use_music_from = items[active_idx][2]
            update_normal_music_for_sound_volume_option()
            items[1][6] = normal_music_for_sound_option
            items[3][6] = normal_music_for_sound_option
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
        end
        deselected_this_frame = false
      end
    end)
    if ret then
      return unpack(ret)
    end
  end
end

return options
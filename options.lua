local options = {}

local analytics = require("analytics")
local wait = coroutine.yield

local memory_before_options_menu = nil

-- opens up music test menu
local function main_music_test()
  gprint(loc("op_music_load"), unpack(main_menu_screen_pos))
  wait()
  -- load music for characters/stages that are not fully loaded
  for _, character_id in ipairs(characters_ids_for_current_theme) do
    if not characters[character_id].fully_loaded then
      characters[character_id]:sound_init(true, false)
    end
  end
  for _, stage_id in ipairs(stages_ids_for_current_theme) do
    if not stages[stage_id].fully_loaded then -- we perform the same although currently no stage are being loaded at this point
      stages[stage_id]:sound_init(true, false)
    end
  end

  local index = 1
  local tracks = {}

  for _, character_id in ipairs(characters_ids_for_current_theme) do
    local character = characters[character_id]
    if character.musics.normal_music then
      tracks[#tracks + 1] = {
        is_character = true,
        name = character.display_name .. ": normal_music",
        id = character_id,
        type = "normal_music",
        start = character.musics.normal_music_start or zero_sound,
        loop = character.musics.normal_music
      }
    end
    if character.musics.danger_music then
      tracks[#tracks + 1] = {
        is_character = true,
        name = character.display_name .. ": danger_music",
        id = character_id,
        type = "danger_music",
        start = character.musics.danger_music_start or zero_sound,
        loop = character.musics.danger_music
      }
    end
  end
  for _, stage_id in ipairs(stages_ids_for_current_theme) do
    local stage = stages[stage_id]
    if stage.musics.normal_music then
      tracks[#tracks + 1] = {
        is_character = false,
        name = stage.display_name .. ": normal_music",
        id = stage_id,
        type = "normal_music",
        start = stage.musics.normal_music_start or zero_sound,
        loop = stage.musics.normal_music
      }
    end
    if stage.musics.danger_music then
      tracks[#tracks + 1] = {
        is_character = false,
        name = stage.display_name .. ": danger_music",
        id = stage_id,
        type = "danger_music",
        start = stage.musics.danger_music_start or zero_sound,
        loop = stage.musics.danger_music
      }
    end
  end

  -- stop main music
  stop_all_audio()

  -- initial song starts here
  find_and_add_music(tracks[index].is_character and characters[tracks[index].id].musics or stages[tracks[index].id].musics, tracks[index].type)

  while true do
    tp = loc("op_music_current") .. tracks[index].name
    tp = tp .. (table.getn(currently_playing_tracks) == 1 and "\n" .. loc("op_music_intro") .. "\n" or "\n" .. loc("op_music_loop") .. "\n")
    min_time = math.huge
    for k, _ in pairs(music_t) do
      if k and k < min_time then
        min_time = k
      end
    end
    tp = tp .. string.format("%d", min_time - love.timer.getTime())
    tp = tp .. "\n\n\n" .. loc("op_music_nav", "<", ">", "ESC")
    gprint(tp, unpack(main_menu_screen_pos))
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_left() or menu_right() or menu_escape() then
          stop_the_music()
        end
        if menu_left() then
          index = index - 1
        end
        if menu_right() then
          index = index + 1
        end
        if index > #tracks then
          index = 1
        end
        if index < 1 then
          index = #tracks
        end
        if menu_left() or menu_right() then
          find_and_add_music(tracks[index].is_character and characters[tracks[index].id].musics or stages[tracks[index].id].musics, tracks[index].type)
        end

        if menu_escape() then
          -- unloads music for characters/stages that are not fully loaded (they have been loaded when entering this submenu)
          for _, character_id in ipairs(characters_ids_for_current_theme) do
            if not characters[character_id].fully_loaded then
              characters[character_id]:sound_uninit()
            end
          end
          for _, stage_id in ipairs(stages_ids_for_current_theme) do
            if not stages[stage_id].fully_loaded then
              stages[stage_id]:sound_uninit()
            end
          end

          ret = {main_select_mode}
        end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end

local function main_show_custom_themes_readme(idx)
  GAME.backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()

  if not love.filesystem.getInfo("themes/" .. prefix_of_ignored_dirs .. default_theme_dir) then
    print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
    gprint(loc("op_copy_files"), 280, 280)
    wait()
    recursive_copy("themes/" .. default_theme_dir, "themes/" .. prefix_of_ignored_dirs .. default_theme_dir)

    -- Android can't easily copy into the save dir, so do it for them to help.
    recursive_copy("default_data/themes", "themes")
  end

  local readme = read_txt_file("readme_themes.txt")
  while true do
    gprint(readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_escape() or menu_enter() then
          ret = {options.main, {idx}}
        end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end

local function main_show_custom_stages_readme(idx)
  GAME.backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()

  local readme = read_txt_file("readme_stages.txt")
  while true do
    gprint(readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_escape() or menu_enter() then
          ret = {options.main, {idx}}
        end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end

local function main_show_custom_characters_readme(idx)
  GAME.backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()

  local readme = read_txt_file("readme_characters.txt")
  while true do
    gprint(readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_escape() or menu_enter() then
          ret = {options.main, {idx}}
        end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end

local function main_show_custom_panels_readme(idx)
  GAME.backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()

  local readme = read_txt_file("readme_panels.txt")
  while true do
    gprint(readme, 15, 15)
    do_menu_function = false
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_escape() or menu_enter() then
          ret = {options.main, {idx}}
        end
      end
    )
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
    gprint(loc("op_reload_theme"), unpack(main_menu_screen_pos))
    wait()
    stop_the_music()
    theme_init()
    if themes[config.theme].musics["main"] then
      find_and_add_music(themes[config.theme].musics, "main")
    end
  end

  -- stages before characters since they are part of their loading
  if config.theme ~= memory_before_options_menu.theme then
    gprint(loc("op_reload_stages"), unpack(main_menu_screen_pos))
    wait()
    stages_init()
  end

  if config.theme ~= memory_before_options_menu.theme then
    gprint(loc("op_reload_characters"), unpack(main_menu_screen_pos))
    wait()
    characters_init()
  end

  if config.enable_analytics ~= memory_before_options_menu.enable_analytics then
    gprint(loc("op_reload_analytics"), unpack(main_menu_screen_pos))
    wait()
    analytics.init()
  end

  apply_config_volume()

  memory_before_options_menu = nil
  normal_music_for_sound_option = nil
  return main_select_mode
end

function options.main(starting_idx)
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()

  local items, active_idx = {}, starting_idx or 1
  local selected, deselected_this_frame, adjust_active_value = false, false, false
  local save_replays_publicly_choices = {{"with my name", "op_replay_public_with_name"}, {"anonymously", "op_replay_public_anonymously"}, {"not at all", "op_replay_public_no"}}
  local use_music_from_choices = {{"stage", "op_only_stage"}, {"often_stage", "op_often_stage"}, {"either", "op_stage_characters"}, {"often_characters", "op_often_characters"}, {"characters", "op_only_characters"}}
  local on_off_text = {[true] = {"On", "op_on"}, [false] = {"Off", "op_off"}}
  local language_choices = {}
  for k, v in ipairs(localization:get_list_codes()) do
    language_choices[k] = {v, "LANG"}
  end

  memory_before_options_menu = {
    theme = config.theme,
     --this one is actually updated with the menu and change upon leaving, be careful!
    enable_analytics = config.enable_analytics
  }

  for k, v in ipairs(save_replays_publicly_choices) do
    save_replays_publicly_choices[v[1]] = v
  end
  for k, v in ipairs(use_music_from_choices) do
    use_music_from_choices[v[1]] = v
  end

  local function get_dir_set(set, path)
    local raw_dir_list = love.filesystem.getDirectoryItems(path)
    for k, v in ipairs(raw_dir_list) do
      local start_of_v = string.sub(v, 0, string.len(prefix_of_ignored_dirs))
      if love.filesystem.getInfo(path .. "/" .. v) and start_of_v ~= prefix_of_ignored_dirs then
        set[#set + 1] = {v, nil}
      end
    end
  end

  local themes_set = {}
  get_dir_set(themes_set, "themes")

  local normal_music_for_sound_option = nil
  local function update_normal_music_for_sound_volume_option()
    if config.use_music_from == "stage" then
      local stage_id = config.stage
      if stage_id == random_stage_special_value then
        stage_id = table.getRandomElement(stages_ids_for_current_theme)
        if stages[stage_id]:is_bundle() then -- may pick a bundle
          stage_id = table.getRandomElement(stages[stage_id].sub_stages)
        end
      elseif stages[stage_id]:is_bundle() then -- may pick a bundle
        stage_id = table.getRandomElement(stages[stage_id].sub_stages)
      end
      stage_loader_load(stage_id)
      stage_loader_wait()
      normal_music_for_sound_option = stages[stage_id].musics.normal_music
    else
      if config.character == random_character_special_value then
        local random_id = table.getRandomElement(characters_ids_for_current_theme)
        character_loader_load(random_id)
        character_loader_wait()
        normal_music_for_sound_option = characters[random_id].musics.normal_music
      else
        -- config.character should already be loaded!
        normal_music_for_sound_option = characters[config.character].musics.normal_music
      end
    end

    if not normal_music_for_sound_option then -- avoid crashes!
      normal_music_for_sound_option = zero_sound
    end
  end
  update_normal_music_for_sound_volume_option()
  items = {
    --options menu table reference:
    --{[1] option id, [2] loc key, [3]current or default value, [4]type, [5]min or bool value or choices_table (composed of {value, loc_key}),
    -- [6]max, [7]sound_source, [8]selectable, [9]next_func, [10]play_while selected}
    --[[1]] {"language", "op_language", {localization:get_language(), "LANG"}, "multiple choice", language_choices},
    --[[2]] {"master_volume", "op_vol", config.master_volume, "numeric", 0, 100, normal_music_for_sound_option, true, nil, true},
    --[[3]] {"sfx_volume", "op_vol_sfx", config.SFX_volume, "numeric", 0, 100, themes[config.theme].sounds.cur_move, true},
    --[[4]] {"music_volume", "op_vol_music", config.music_volume, "numeric", 0, 100, normal_music_for_sound_option, true, nil, true},
    --[[5]] {"vsync", "op_vsync", on_off_text[config.vsync], "bool", false, nil, nil, false},
    --[[6]] {"debug", "op_debug", on_off_text[config.debug_mode], "bool", false, nil, nil, false},
    --[[7]] {
      "replays",
      "op_replay_public",
      save_replays_publicly_choices[config.save_replays_publicly] or save_replays_publicly_choices["with my name"],
      "multiple choice",
      save_replays_publicly_choices
    },
    --[[8]] {"theme", "op_theme", {config.theme, nil}, "multiple choice", themes_set},
    --[[9]] {"countdown", "op_countdown", on_off_text[config.ready_countdown_1P], "bool", true, nil, nil, false},
    --[[10]] {"fps", "op_fps", on_off_text[config.show_fps], "bool", true, nil, nil, false},
    --[[11]] {"infos", "op_ingame_infos", on_off_text[config.show_ingame_infos], "bool", true, nil, nil, false},
    --[[12]] {"music_delay", "op_music_delay", on_off_text[config.danger_music_changeback_delay], "bool", false, nil, nil, false},
    --[[13]] {"analytics", "op_analytics", on_off_text[config.enable_analytics], "bool", false, nil, nil, false},
    --[[14]] {"input_repeat_delay", "op_input_delay", config.input_repeat_delay, "numeric", 1, 50, nil, true},
    --[[15]] {"portrait_darkness", "op_portrait_darkness", config.portrait_darkness, "numeric", 0, 100, nil, true},
    --[[16]] {"popfx", "op_popfx", on_off_text[config.popfx], "bool", true, nil, nil, false},
    --[[17]] {"cardfx_scale", "op_cardfx_scale", config.cardfx_scale, "numeric", 1, 200, nil, true},
    --[[18]] {"music_from", "op_use_music_from", use_music_from_choices[config.use_music_from], "multiple choice", use_music_from_choices},
    --[[19]] {"about_themes", "op_about_themes", "", "function", nil, nil, nil, nil, main_show_custom_themes_readme},
    --[[20]] {"about_chars", "op_about_characters", "", "function", nil, nil, nil, nil, main_show_custom_characters_readme},
    --[[21]] {"about_stages", "op_about_stages", "", "function", nil, nil, nil, nil, main_show_custom_stages_readme},
    --[[22]] {"about_panels", "op_about_panels", "", "function", nil, nil, nil, nil, main_show_custom_panels_readme},
    --[[23]] {"Music test", "mm_music_test", "", "function", nil, nil, nil, nil, main_music_test},
    --[[24]] {"back", "back", "", nil, nil, nil, nil, false, main_select_mode},
  }
  local function print_stuff()
    local to_print, to_print2, arrow = "", "", ""
    for i = 1, #items do
      if active_idx == i then
        arrow = arrow .. ">"
      else
        arrow = arrow .. "\n"
      end
      to_print = to_print .. "   " .. loc(items[i][2]) .. "\n"
      to_print2 = to_print2 .. "                                                                    "
      if active_idx == i and selected then
        to_print2 = to_print2 .. "                < "
      else
        to_print2 = to_print2 .. "                  "
      end
      if items[i][4] == "multiple choice" or items[i][4] == "bool" then
        to_print2 = to_print2 .. (items[i][3][2] and loc(items[i][3][2]) or items[i][3][1])
      else
        to_print2 = to_print2 .. items[i][3]
      end
      if active_idx == i and selected then
        to_print2 = to_print2 .. " >"
      end
      to_print2 = to_print2 .. "\n"
    end
    local x, y = unpack(main_menu_screen_pos)
    x = x - 60 --options menu is 'lefter' than main_menu
    gprint(arrow, x, y)
    gprint(to_print, x, y)
    gprint(to_print2, x, y)
  end
  local function adjust_left()
    if items[active_idx][4] == "numeric" then
      if items[active_idx][3] > items[active_idx][5] then --value > minimum
        items[active_idx][3] = items[active_idx][3] - 1
      end
    elseif items[active_idx][4] == "multiple choice" then
      adjust_backwards = true
      adjust_active_value = true
    end
    --the following is enough for "bool"
    adjust_active_value = true
    if items[active_idx][7] and not items[active_idx][10] then
      --sound_source for this menu item exists and not play_while_selected
      items[active_idx][7]:stop()
      items[active_idx][7]:play()
    end
  end
  local function adjust_right()
    if items[active_idx][4] == "numeric" then
      if items[active_idx][3] < items[active_idx][6] then --value < maximum
        items[active_idx][3] = items[active_idx][3] + 1
      end
    elseif items[active_idx][4] == "multiple choice" then
      adjust_active_value = true
    end
    --the following is enough for "bool"
    adjust_active_value = true
    if items[active_idx][7] and not items[active_idx][10] then
      --sound_source for this menu item exists and not play_while_selected
      items[active_idx][7]:stop()
      items[active_idx][7]:play()
    end
  end
  local do_menu_function = false
  while true do
    print_stuff()
    wait()
    local ret = nil
    variable_step(
      function()
        if menu_up() and not selected then
          active_idx = wrap(1, active_idx - 1, #items)
        elseif menu_down() and not selected then
          active_idx = wrap(1, active_idx + 1, #items)
        elseif menu_left() and (selected or not items[active_idx][8]) then --or not selectable
          adjust_left()
        elseif menu_right() and (selected or not items[active_idx][8]) then --or not selectable
          adjust_right()
        elseif menu_enter() then
          if items[active_idx][8] then --is selectable
            selected = not selected
            if not selected then
              deselected_this_frame = true
              adjust_active_value = true
            end
          elseif items[active_idx][4] == "bool" or items[active_idx][4] == "multiple choice" then
            adjust_active_value = true
          elseif items[active_idx][4] == "function" then
            do_menu_function = true
          elseif active_idx == #items then
            ret = {exit_options_menu}
          end
        elseif menu_escape() then
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
          if items[active_idx][4] == "bool" then
            --add any other bool config updates here
            if items[active_idx][1] == "debug" then
              config.debug_mode = not config.debug_mode
              items[active_idx][3] = on_off_text[config.debug_mode]
            elseif items[active_idx][1] == "countdown" then
              config.ready_countdown_1P = not config.ready_countdown_1P
              items[active_idx][3] = on_off_text[config.ready_countdown_1P]
            elseif items[active_idx][1] == "vsync" then
              config.vsync = not config.vsync
              items[active_idx][3] = on_off_text[config.vsync]
              love.window.setVSync(config.vsync and 1 or 0)
            elseif items[active_idx][1] == "fps" then
              config.show_fps = not config.show_fps
              items[active_idx][3] = on_off_text[config.show_fps]
            elseif items[active_idx][1] == "debug" then
              config.debug_mode = not config.debug_mode
              items[active_idx][3] = on_off_text[config.debug_mode]
            elseif items[active_idx][1] == "infos" then
              config.show_ingame_infos = not config.show_ingame_infos
              items[active_idx][3] = on_off_text[config.show_ingame_infos]
            elseif items[active_idx][1] == "music_delay" then
              config.danger_music_changeback_delay = not config.danger_music_changeback_delay
              items[active_idx][3] = on_off_text[config.danger_music_changeback_delay]
            elseif items[active_idx][1] == "analytics" then
              config.enable_analytics = not config.enable_analytics
              items[active_idx][3] = on_off_text[config.enable_analytics]
            elseif items[active_idx][1] == "popfx" then
              config.popfx = not config.popfx
              items[active_idx][3] = on_off_text[config.popfx]
            end
          elseif items[active_idx][4] == "numeric" then
            --add any other numeric config updates here
            if config.master_volume ~= items[2][3] then
              config.master_volume = items[2][3]
              love.audio.setVolume(config.master_volume / 100)
            end
            if config.SFX_volume ~= items[3][3] then --SFX volume should be updated
              config.SFX_volume = items[3][3]
              items[3][7]:setVolume(config.SFX_volume / 100) --do just the one sound effect until we deselect
            end
            if config.music_volume ~= items[4][3] then --music volume should be updated
              config.music_volume = items[4][3]
              items[4][7]:setVolume(config.music_volume / 100) --do just the one music source until we deselect
            end
            if config.input_repeat_delay ~= items[14][3] then --music volume should be updated
              config.input_repeat_delay = items[14][3]
            end
            if config.portrait_darkness ~= items[15][3] then
              config.portrait_darkness = items[15][3]
            end
            if config.cardfx_scale ~= items[17][3] then
              config.cardfx_scale = items[17][3]
            end
          elseif items[active_idx][4] == "multiple choice" then
            local active_choice_num = 1
            --find the key for the currently selected choice
            for k, v in ipairs(items[active_idx][5]) do
              if v == items[active_idx][3] then
                active_choice_num = k
              end
            end
            -- the next line of code means
            -- current_choice_num = choices[wrap(1, next_choice_num, last_choice_num)]
            if adjust_backwards then
              items[active_idx][3] = items[active_idx][5][wrap(1, active_choice_num - 1, #items[active_idx][5])]
              adjust_backwards = nil
            else
              items[active_idx][3] = items[active_idx][5][wrap(1, active_choice_num + 1, #items[active_idx][5])]
            end
            if items[active_idx][1] == "replays" then
              -- don't change config.theme directly here as it is used while being in this menu! instead we change it upon leaving
              config.save_replays_publicly = items[active_idx][3][1]
            elseif items[active_idx][1] == "theme" then
              memory_before_options_menu.theme = items[active_idx][3][1]
            elseif items[active_idx][1] == "music_from" then
              config.use_music_from = items[active_idx][3][1]
              update_normal_music_for_sound_volume_option()
              items[2][7] = normal_music_for_sound_option
              items[4][7] = normal_music_for_sound_option
            elseif items[active_idx][1] == "language" then
              localization:set_language(items[active_idx][3][1])
            end
          --add any other multiple choice config updates here
          end
          adjust_active_value = false
        end
        if items[active_idx][4] == "function" and do_menu_function and not ret then
          ret = {items[active_idx][9], {active_idx}}
        end
        if not ret and selected and items[active_idx][10] and items[active_idx][7] and not items[active_idx][7]:isPlaying() then
          --if selected and play_while_selected and sound source exists and it isn't playing
          items[active_idx][7]:play()
        end
        if not ret and deselected_this_frame then
          if items[active_idx][7] then --sound_source for this menu item exists
            items[active_idx][7]:stop()
          end
          deselected_this_frame = false
        end
      end
    )
    if ret then
      return unpack(ret)
    end
  end
end

return options

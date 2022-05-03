local options = {}
local analytics = require("analytics")
local wait = coroutine.yield
local memory_before_options_menu = nil
local theme_index
local found_themes = {}

local function general_menu()
  local ret = nil
  local menu_x, menu_y = unpack(main_menu_screen_pos)
  local save_replays_publicly_choices = {{"with my name", "op_replay_public_with_name"}, {"anonymously", "op_replay_public_anonymously"}, {"not at all", "op_replay_public_no"}}
  local save_replays_preference_index
  for k, v in ipairs(save_replays_publicly_choices) do
    if v[1] == config.save_replays_publicly then
      save_replays_preference_index = k
      break
    end
  end
  local generalMenu

  local function update_vsync(noToggle)
    if not noToggle then
      config.vsync = not config.vsync
      love.window.setVSync(config.vsync and 1 or 0)
    end
    generalMenu:set_button_setting(1, config.vsync and loc("op_on") or loc("op_off"))
  end

  local function update_debug(noToggle)
    if not noToggle then
      config.debug_mode = not config.debug_mode
    end
    generalMenu:set_button_setting(2, config.debug_mode and loc("op_on") or loc("op_off"))
  end

  local function update_countdown(noToggle)
    if not noToggle then
      config.ready_countdown_1P = not config.ready_countdown_1P
    end
    generalMenu:set_button_setting(3, config.ready_countdown_1P and loc("op_on") or loc("op_off"))
  end

  local function update_fps(noToggle)
    if not noToggle then
      config.show_fps = not config.show_fps
    end
    generalMenu:set_button_setting(4, config.show_fps and loc("op_on") or loc("op_off"))
  end

  local function update_infos(noToggle)
    if not noToggle then
      config.show_ingame_infos = not config.show_ingame_infos
    end
    generalMenu:set_button_setting(5, config.show_ingame_infos and loc("op_on") or loc("op_off"))
  end

  local function update_analytics(noToggle)
    if not noToggle then
      config.enable_analytics = not config.enable_analytics
    end
    generalMenu:set_button_setting(6, config.enable_analytics and loc("op_on") or loc("op_off"))
  end

  local function update_input_repeat_delay()
    generalMenu:set_button_setting(7, config.input_repeat_delay)
  end

  local function increase_input_repeat_delay()
    config.input_repeat_delay = bound(0, config.input_repeat_delay + 1, 50)
    update_input_repeat_delay()
  end

  local function decrease_input_repeat_delay()
    config.input_repeat_delay = bound(0, config.input_repeat_delay - 1, 50)
    update_input_repeat_delay()
  end

  local function update_replay_preference()
    config.save_replays_publicly = save_replays_publicly_choices[save_replays_preference_index][1]
    generalMenu:set_button_setting(8, loc(save_replays_publicly_choices[save_replays_preference_index][2]))
  end

  local function increase_publicness() -- privatize or publicize?
    save_replays_preference_index = bound(1, save_replays_preference_index + 1, #save_replays_publicly_choices)
    update_replay_preference()
  end

  local function increase_privateness()
    save_replays_preference_index = bound(1, save_replays_preference_index - 1, #save_replays_publicly_choices)
    update_replay_preference()
  end

  local function nextMenu()
    generalMenu:selectNextIndex()
  end

  local function goEscape()
    generalMenu:set_active_idx(#generalMenu.buttons)
  end

  local function exitSettings()
    ret = {options.main, {2}}
  end

  generalMenu = Click_menu(menu_x, menu_y, nil, canvas_height - menu_y - 10, 1)
  generalMenu:add_button(loc("op_vsync"), update_vsync, goEscape, update_vsync, update_vsync)
  generalMenu:add_button(loc("op_debug"), update_debug, goEscape, update_debug, update_debug)
  generalMenu:add_button(loc("op_countdown"), update_countdown, goEscape, update_countdown, update_countdown)
  generalMenu:add_button(loc("op_fps"), update_fps, goEscape, update_fps, update_fps)
  generalMenu:add_button(loc("op_ingame_infos"), update_infos, goEscape, update_infos, update_infos)
  generalMenu:add_button(loc("op_analytics"), update_analytics, goEscape, update_analytics, update_analytics)
  generalMenu:add_button(loc("op_input_delay"), nextMenu, goEscape, decrease_input_repeat_delay, increase_input_repeat_delay)
  generalMenu:add_button(loc("op_replay_public"), nextMenu, goEscape, increase_publicness, increase_privateness)
  generalMenu:add_button(loc("back"), exitSettings, exitSettings)
  update_vsync(true)
  update_debug(true)
  update_countdown(true)
  update_fps(true)
  update_infos(true)
  update_analytics(true)
  update_input_repeat_delay()
  update_replay_preference()

  while true do
    generalMenu:draw()
    wait()
    variable_step(
      function()
        generalMenu:update()
      end
    )

    if ret then
      generalMenu:remove_self()
      return unpack(ret)
    end
  end
end

local function graphics_menu()
  local ret = nil
  local menu_x, menu_y = unpack(main_menu_screen_pos)
  local graphicsMenu

  local function update_theme()
    graphicsMenu:set_button_setting(1, found_themes[theme_index])
  end

  local function next_theme()
    theme_index = bound(1, theme_index + 1, #found_themes)
    update_theme()
  end

  local function previous_theme()
    theme_index = bound(1, theme_index - 1, #found_themes)
    update_theme()
  end

  local function update_portrait_darkness()
    graphicsMenu:set_button_setting(2, config.portrait_darkness)
  end

  local function increase_portrait_darkness()
    config.portrait_darkness = bound(0, config.portrait_darkness + 1, 100)
    update_portrait_darkness()
  end

  local function decrease_portrait_darkness()
    config.portrait_darkness = bound(0, config.portrait_darkness - 1, 100)
    update_portrait_darkness()
  end

  local function update_popfx(noToggle)
    if not noToggle then
      config.popfx = not config.popfx
    end
    graphicsMenu:set_button_setting(3, config.popfx and loc("op_on") or loc("op_off"))
  end

  local function nextMenu()
    graphicsMenu:selectNextIndex()
  end

  local function goEscape()
    graphicsMenu:set_active_idx(#graphicsMenu.buttons)
  end

  local function exitSettings()
    ret = {options.main, {3}}
  end

  graphicsMenu = Click_menu(menu_x, menu_y, nil, canvas_height - menu_y - 10, 1)
  graphicsMenu:add_button(loc("op_theme"), nextMenu, goEscape, previous_theme, next_theme)
  graphicsMenu:add_button(loc("op_portrait_darkness"), nextMenu, goEscape, decrease_portrait_darkness, increase_portrait_darkness)
  graphicsMenu:add_button(loc("op_popfx"), update_popfx, goEscape, update_popfx, update_popfx)
  graphicsMenu:add_button(loc("back"), exitSettings, exitSettings)
  update_theme()
  update_portrait_darkness()
  update_popfx(true)

  while true do
    graphicsMenu:draw()
    wait()
    variable_step(
      function()
        graphicsMenu:update()
      end
    )

    if ret then
      graphicsMenu:remove_self()
      return unpack(ret)
    end
  end
end

local function audio_menu(button_idx)
  local ret = nil
  local menu_x, menu_y = unpack(main_menu_screen_pos)
  menu_y = menu_y + 70
  local music_choice_frequency
  local use_music_from_choices = {{"stage", "op_only_stage"}, {"often_stage", "op_often_stage"}, {"either", "op_stage_characters"}, {"often_characters", "op_often_characters"}, {"characters", "op_only_characters"}}
  for k, v in ipairs(use_music_from_choices) do
    if v[1] == config.use_music_from then
      music_choice_frequency = k
    end
  end
  local audioMenu

  local function update_master_volume()
    audioMenu:set_button_setting(1, config.master_volume)
    apply_config_volume()
  end

  local function increase_master_volume()
    config.master_volume = bound(0, config.master_volume + 1, 100)
    update_master_volume()
  end

  local function decrease_master_volume()
    config.master_volume = bound(0, config.master_volume - 1, 100)
    update_master_volume()
  end

  local function update_sfx_volume()
    audioMenu:set_button_setting(2, config.SFX_volume)
    apply_config_volume()
  end

  local function increase_sfx_volume()
    config.SFX_volume = bound(0, config.SFX_volume + 1, 100)
    update_sfx_volume()
  end

  local function decrease_sfx_volume()
    config.SFX_volume = bound(0, config.SFX_volume - 1, 100)
    update_sfx_volume()
  end

  local function update_music_volume()
    audioMenu:set_button_setting(3, config.music_volume)
    apply_config_volume()
  end

  local function increase_music_volume()
    config.music_volume = bound(0, config.music_volume + 1, 100)
    update_music_volume()
  end

  local function decrease_music_volume()
    config.music_volume = bound(0, config.music_volume - 1, 100)
    update_music_volume()
  end

  local function update_music_frequency()
    config.use_music_from = use_music_from_choices[music_choice_frequency][1]
    audioMenu:set_button_setting(4, loc(use_music_from_choices[music_choice_frequency][2]))
  end

  local function increase_character_frequency()
    music_choice_frequency = bound(1, music_choice_frequency + 1, #use_music_from_choices)
    update_music_frequency()
  end

  local function increase_stage_frequency()
    music_choice_frequency = bound(1, music_choice_frequency - 1, #use_music_from_choices)
    update_music_frequency()
  end

  local function update_music_delay(noToggle)
    if not noToggle then
      config.danger_music_changeback_delay = not config.danger_music_changeback_delay
    end
    audioMenu:set_button_setting(5, config.danger_music_changeback_delay and loc("op_on") or loc("op_off"))
  end

  local function enter_music_test()
    ret = {
      function()
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
          local audio_test_ret = nil
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

                audio_test_ret = {audio_menu, {6}}
              end
            end
          )
          if audio_test_ret then
            return unpack(audio_test_ret)
          end
        end
      end
    }
  end

  local function nextMenu()
    audioMenu:selectNextIndex()
  end

  local function goEscape()
    audioMenu:set_active_idx(#audioMenu.buttons)
  end

  local function exitSettings()
    ret = {options.main, {4}}
  end

  audioMenu = Click_menu(menu_x, menu_y, nil, canvas_height - menu_y - 10, 1)
  audioMenu:add_button(loc("op_vol"), nextMenu, goEscape, decrease_master_volume, increase_master_volume)
  audioMenu:add_button(loc("op_vol_sfx"), nextMenu, goEscape, decrease_sfx_volume, increase_sfx_volume)
  audioMenu:add_button(loc("op_vol_music"), nextMenu, goEscape, decrease_music_volume, increase_music_volume)
  audioMenu:add_button(loc("op_use_music_from"), nextMenu, goEscape, increase_stage_frequency, increase_character_frequency)
  audioMenu:add_button(loc("op_music_delay"), update_music_delay, goEscape, update_music_delay, update_music_delay)
  audioMenu:add_button(loc("mm_music_test"), enter_music_test, goEscape, decrease_music_volume, increase_music_volume)
  audioMenu:add_button(loc("back"), exitSettings, exitSettings)
  update_master_volume()
  update_sfx_volume()
  update_music_volume()
  update_music_frequency()
  update_music_delay(true)

  if button_idx then
    audioMenu:set_active_idx(button_idx)
  end

  while true do
    audioMenu:draw()
    wait()
    variable_step(
      function()
        audioMenu:update()
      end
    )

    if ret then
      audioMenu:remove_self()
      return unpack(ret)
    end
  end
end

local function about_menu(button_idx)
  local ret = nil
  local menu_x, menu_y = unpack(main_menu_screen_pos)
  GAME.backgroundImage = themes[config.theme].images.bg_main
  local aboutMenu

  local function show_themes_readme()
    ret = {
      function()
        GAME.backgroundImage = themes[config.theme].images.bg_readme
        reset_filters()

        if not love.filesystem.getInfo("themes/" .. prefix_of_ignored_dirs .. default_theme_dir) then
          --print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
          gprint(loc("op_copy_files"), 280, 280)
          wait()
          recursive_copy("themes/" .. default_theme_dir, "themes/" .. prefix_of_ignored_dirs .. default_theme_dir)

          -- Android can't easily copy into the save dir, so do it for them to help.
          recursive_copy("default_data/themes", "themes")
        end

        local readme = read_txt_file("readme_themes.txt")
        while true do
          gprint(readme, 15, 15)
          wait()
          local theme_ret = nil
          variable_step(
            function()
              if menu_escape() or menu_enter() then
                theme_ret = {about_menu, {1}}
              end
            end
          )
          if theme_ret then
            return unpack(theme_ret)
          end
        end
      end
    }
  end

  local function show_characters_readme()
    ret = {
      function()
        GAME.backgroundImage = themes[config.theme].images.bg_readme
        reset_filters()

        local readme = read_txt_file("readme_characters.txt")
        while true do
          gprint(readme, 15, 15)
          wait()
          local characters_ret = nil
          variable_step(
            function()
              if menu_escape() or menu_enter() then
                characters_ret = {about_menu, {2}}
              end
            end
          )
          if characters_ret then
            return unpack(characters_ret)
          end
        end
      end
    }
  end

  local function show_stages_readme()
    ret = {
      function()
        GAME.backgroundImage = themes[config.theme].images.bg_readme
        reset_filters()

        local readme = read_txt_file("readme_stages.txt")
        while true do
          gprint(readme, 15, 15)
          wait()
          local stages_ret = nil
          variable_step(
            function()
              if menu_escape() or menu_enter() then
                stages_ret = {about_menu, {3}}
              end
            end
          )
          if stages_ret then
            return unpack(stages_ret)
          end
        end
      end
    }
  end

  local function show_panels_readme()
    ret = {
      function()
        GAME.backgroundImage = themes[config.theme].images.bg_readme
        reset_filters()

        local readme = read_txt_file("readme_panels.txt")
        while true do
          gprint(readme, 15, 15)
          wait()
          local panels_ret = nil
          variable_step(
            function()
              if menu_escape() or menu_enter() then
                panels_ret = {about_menu, {4}}
              end
            end
          )
          if panels_ret then
            return unpack(panels_ret)
          end
        end
      end
    }
  end

  local function show_system_info()
    ret = {
      function()
        GAME.backgroundImage = themes[config.theme].images.bg_readme
        reset_filters()
        local renderer_name, renderer_version, graphics_card_vendor, graphics_card_name = love.graphics.getRendererInfo()
        local sys_info = {}
        sys_info[#sys_info + 1] = {name = "Operating System", value = love.system.getOS()} 
        sys_info[#sys_info + 1] = {name = "Renderer", value = renderer_name.." "..renderer_version}
        sys_info[#sys_info + 1] = {name = "Graphics Card", value = graphics_card_name}
        sys_info[#sys_info + 1] = {name = "LOVE Version", value = Game.loveVersionString()} 
        sys_info[#sys_info + 1] = {name = "Panel Attack Engine Version", value = VERSION} 
        sys_info[#sys_info + 1] = {name = "Panel Attack Release Version", value = GAME_UPDATER_GAME_VERSION} 
        sys_info[#sys_info + 1] = {name = "Save Data Directory Path", value = love.filesystem.getSaveDirectory()}  
        sys_info[#sys_info + 1] = {name = "Characters [Enabled/Total]", value = #characters_ids_for_current_theme.."/"..#characters_ids} 
        sys_info[#sys_info + 1] = {name = "Stages [Enabled/Total]", value = #stages_ids_for_current_theme.."/"..#stages_ids} 
        sys_info[#sys_info + 1] = {name = "Total Panel Sets", value = #panels_ids} 
        sys_info[#sys_info + 1] = {name = "Total Themes", value = #found_themes}
        local info_string = ""
        for index, info in ipairs(sys_info) do
          info_string = info_string .. info.name .. ": " .. (info.value or "Unknown") .. "\n"
        end
        while true do
          gprint(info_string, 15, 15)
          wait()
          local panels_ret = nil
          variable_step(
            function()
              if menu_escape() or menu_enter() then
                panels_ret = {about_menu, {5}}
              end
            end
          )
          if panels_ret then
            return unpack(panels_ret)
          end
        end
      end
    }
  end

  local function nextMenu()
    aboutMenu:selectNextIndex()
  end

  local function goEscape()
    aboutMenu:set_active_idx(#aboutMenu.buttons)
  end

  local function exitSettings()
    ret = {options.main, {5}}
  end

  aboutMenu = Click_menu(menu_x, menu_y, nil, canvas_height - menu_y - 10, 1)
  aboutMenu:add_button(loc("op_about_themes"), show_themes_readme, goEscape)
  aboutMenu:add_button(loc("op_about_characters"), show_characters_readme, goEscape)
  aboutMenu:add_button(loc("op_about_stages"), show_stages_readme, goEscape)
  aboutMenu:add_button(loc("op_about_panels"), show_panels_readme, goEscape)
  aboutMenu:add_button("System Info", show_system_info, goEscape)
  aboutMenu:add_button(loc("back"), exitSettings, exitSettings)

  if button_idx then
    aboutMenu:set_active_idx(button_idx)
  end

  while true do
    aboutMenu:draw()
    wait()
    variable_step(
      function()
        aboutMenu:update()
      end
    )

    if ret then
      aboutMenu:remove_self()
      return unpack(ret)
    end
  end
end

function options.main(button_idx)
  local ret = nil
  local menu_x, menu_y = unpack(main_menu_screen_pos)
  menu_y = menu_y + 70
  local language_number
  local language_choices = {}
  for k, v in ipairs(localization:get_list_codes()) do
    language_choices[k] = v
    if localization:get_language() == v then
      language_number = k
    end
  end
  local optionsMenu

  local function update_language(update_text)
    localization:set_language(language_choices[language_number])
    optionsMenu:set_button_setting(1, loc("LANG"))
    if update_text then
      ret = {options.main} -- this allows the menu to change the text
    end
  end

  local function increase_language()
    language_number = bound(1, language_number + 1, #localization:get_list_codes())
    update_language(true)
  end

  local function decrease_language()
    language_number = bound(1, language_number - 1, #localization:get_list_codes())
    update_language(true)
  end

  local function enter_general_menu()
    ret = {general_menu}
  end

  local function enter_graphics_menu()
    ret = {graphics_menu}
  end

  local function enter_audio_menu()
    ret = {audio_menu}
  end

  local function enter_about_menu()
    ret = {about_menu}
  end

  local function nextMenu()
    optionsMenu:selectNextIndex()
  end

  local function goEscape()
    optionsMenu:set_active_idx(#optionsMenu.buttons)
  end

  local function exitSettings()
    gprint("writing config to file...", unpack(main_menu_screen_pos))
    wait()

    config.theme = found_themes[theme_index]

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
    ret = {main_select_mode}
  end

  optionsMenu = Click_menu(menu_x, menu_y, nil, canvas_height - menu_y - 10, 1)
  optionsMenu:add_button(loc("op_language"), nextMenu, goEscape, decrease_language, increase_language)
  optionsMenu:add_button("General", enter_general_menu, goEscape)
  optionsMenu:add_button("Graphics", enter_graphics_menu, goEscape)
  optionsMenu:add_button("Audio", enter_audio_menu, goEscape)
  optionsMenu:add_button("About", enter_about_menu, goEscape)
  optionsMenu:add_button(loc("back"), exitSettings, exitSettings)
  update_language()

  if button_idx then
    optionsMenu:set_active_idx(button_idx)
  else
    found_themes = {}
    for k, v in ipairs(love.filesystem.getDirectoryItems("themes")) do
      if love.filesystem.getInfo("themes/" .. v) and v:sub(0, prefix_of_ignored_dirs:len()) ~= prefix_of_ignored_dirs then
        found_themes[#found_themes + 1] = v
        if config.theme == v then
          theme_index = #found_themes
        end
      end
    end
    memory_before_options_menu = {
      theme = config.theme,
      --this one is actually updated with the menu and change upon leaving, be careful!
      enable_analytics = config.enable_analytics
    }
  end

  while true do
    optionsMenu:draw()
    wait()
    variable_step(
      function()
        optionsMenu:update()
      end
    )

    if ret then
      optionsMenu:remove_self()
      return unpack(ret)
    end
  end
end

return options

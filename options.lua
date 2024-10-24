local options = {}
local analytics = require("analytics")
local consts = require("consts")
local wait = coroutine.yield
local memory_before_options_menu = nil
local theme_index
local scaleTypeIndex
local fixedScaleIndex
local found_themes = {}
local utf8 = require("utf8")
local tableUtils = require("tableUtils")

local function general_menu()
  local ret = nil
  local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
  local save_replays_publicly_choices = {{"with my name", "op_replay_public_with_name"}, {"anonymously", "op_replay_public_anonymously"}, {"not at all", "op_replay_public_no"}}
  local save_replays_preference_index
  for k, v in ipairs(save_replays_publicly_choices) do
    if v[1] == config.save_replays_publicly then
      save_replays_preference_index = k
      break
    end
  end
  local generalMenu

  local function update_countdown(noToggle)
    if not noToggle then
      config.ready_countdown_1P = not config.ready_countdown_1P
    end
    generalMenu:set_button_setting(1, config.ready_countdown_1P and loc("op_on") or loc("op_off"))
  end

  local function update_fps(noToggle)
    if not noToggle then
      config.show_fps = not config.show_fps
    end
    generalMenu:set_button_setting(2, config.show_fps and loc("op_on") or loc("op_off"))
  end

  local function update_infos(noToggle)
    if not noToggle then
      config.show_ingame_infos = not config.show_ingame_infos
    end
    generalMenu:set_button_setting(3, config.show_ingame_infos and loc("op_on") or loc("op_off"))
  end

  local function update_analytics(noToggle)
    if not noToggle then
      config.enable_analytics = not config.enable_analytics
    end
    generalMenu:set_button_setting(4, config.enable_analytics and loc("op_on") or loc("op_off"))
  end

  local function update_input_repeat_delay()
    generalMenu:set_button_setting(5, config.input_repeat_delay)
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
    generalMenu:set_button_setting(6, loc(save_replays_publicly_choices[save_replays_preference_index][2]))
  end

  local function increase_publicness() -- privatize or publicize?
    save_replays_preference_index = bound(1, save_replays_preference_index + 1, #save_replays_publicly_choices)
    update_replay_preference()
  end

  local function increase_privateness()
    save_replays_preference_index = bound(1, save_replays_preference_index - 1, #save_replays_publicly_choices)
    update_replay_preference()
  end

  local activeGarbageCollectionPercent = config.activeGarbageCollectionPercent * 100

  local function updateGarbageCollectionPercent()
    config.activeGarbageCollectionPercent = activeGarbageCollectionPercent / 100
    generalMenu:set_button_setting(7, activeGarbageCollectionPercent)
  end

  local function increaseGarbageCollectionPercent()
    activeGarbageCollectionPercent = bound(10, activeGarbageCollectionPercent + 1, 80)
    updateGarbageCollectionPercent()
  end

  local function decreaseGarbageCollectionPercent()
    activeGarbageCollectionPercent = bound(10, activeGarbageCollectionPercent - 1, 80)
    updateGarbageCollectionPercent()
  end

  local function nextMenu()
    generalMenu:selectNextIndex()
  end

  local function goEscape()
    generalMenu:set_active_idx(#generalMenu.buttons)
  end

  generalMenu = Click_menu(menu_x, menu_y, nil, themes[config.theme].main_menu_max_height, 1)
  generalMenu:add_button(loc("op_countdown"), update_countdown, goEscape, update_countdown, update_countdown)
  generalMenu:add_button(loc("op_fps"), update_fps, goEscape, update_fps, update_fps)
  generalMenu:add_button(loc("op_ingame_infos"), update_infos, goEscape, update_infos, update_infos)
  generalMenu:add_button(loc("op_analytics"), update_analytics, goEscape, update_analytics, update_analytics)
  generalMenu:add_button(loc("op_input_delay"), update_input_repeat_delay, goEscape, decrease_input_repeat_delay, increase_input_repeat_delay)
  generalMenu:add_button(loc("op_replay_public"), update_replay_preference, goEscape, increase_publicness, increase_privateness)
  generalMenu:add_button(loc("op_performance_drain"), updateGarbageCollectionPercent, goEscape, decreaseGarbageCollectionPercent, increaseGarbageCollectionPercent)

  if GAME_UPDATER and GAME_UPDATER.releaseStreams and GAME_UPDATER_STATES then
    local releaseStreams = {}
    for name, _ in pairs(GAME_UPDATER.releaseStreams) do
      releaseStreams[#releaseStreams+1] = name
    end

    -- in case the version was changed earlier and we return to options again, reset to the currently launched version
    -- this is so whatever the user leaves the setting on when quitting options that will be what is launched with next time
    GAME_UPDATER:writeLaunchConfig(GAME_UPDATER.activeVersion)

    local releaseStreamIndex = tableUtils.indexOf(releaseStreams, GAME_UPDATER.activeVersion.releaseStream.name)

    local function updateReleaseStreamPreference()
      local releaseStream = GAME_UPDATER.releaseStreams[releaseStreams[releaseStreamIndex]]
      local version = GAME_UPDATER.getLatestInstalledVersion(releaseStream)
      if not version then
        if not GAME_UPDATER:updateAvailable(releaseStream) then
          GAME_UPDATER:getAvailableVersions(releaseStream)
          while GAME_UPDATER.state ~= GAME_UPDATER_STATES.idle do
            GAME_UPDATER:update()
          end
        end
        if GAME_UPDATER:updateAvailable(releaseStream) then
          table.sort(releaseStream.availableVersions, function(a,b) return a.version > b.version end)
          version = releaseStream.availableVersions[1]
        else
          -- if we cannot find available versions for a release stream, remove it from the selection
          table.remove(releaseStreams, releaseStreamIndex)
          releaseStreamIndex = bound(1, releaseStreamIndex, #releaseStreams)
          updateReleaseStreamPreference()
          return
        end
      end
      GAME_UPDATER:writeLaunchConfig(version)
      generalMenu:set_button_setting(8, releaseStream.name)
    end

    local function increaseReleaseStreamIndex()
      releaseStreamIndex = bound(1, releaseStreamIndex + 1, #releaseStreams)
      updateReleaseStreamPreference()
    end

    local function decreaseReleaseStreamIndex()
      releaseStreamIndex = bound(1, releaseStreamIndex - 1, #releaseStreams)
      updateReleaseStreamPreference()
    end

    generalMenu:add_button("Release Stream", updateReleaseStreamPreference, goEscape, decreaseReleaseStreamIndex, increaseReleaseStreamIndex)
    updateReleaseStreamPreference()
  end

  local function exitSettings()
    ret = {options.main, {2}}
    if GAME_UPDATER and GAME_UPDATER.releaseStreams then
      if generalMenu.buttons[8].currentSettingText ~= GAME_UPDATER.activeReleaseStream.name then
        love.window.showMessageBox("Changing Release Stream", "Please restart the game to launch the selected release stream")
      end
    end
  end

  generalMenu:add_button(loc("back"), exitSettings, exitSettings)
  update_countdown(true)
  update_fps(true)
  update_infos(true)
  update_analytics(true)
  update_input_repeat_delay()
  update_replay_preference()
  updateGarbageCollectionPercent()

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
  local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
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

  local scaleTypeOptions = {"auto", "fit", "fixed"}
  local translatedScaleTypeOptions = {loc("op_scale_auto"), loc("op_scale_fit"), loc("op_scale_fixed")}
  scaleTypeIndex = 1
  for index, scaleType in ipairs(scaleTypeOptions) do
    if scaleType == config.gameScaleType then
      scaleTypeIndex = index
      break
    end
  end
  fixedScaleIndex = 1
  for index, fixedScale in ipairs(GAME.availableScales) do
    if fixedScale == config.gameScaleFixedValue then
      fixedScaleIndex = index
      break
    end
  end

  local updateFixedScale

  local function scaleSettingsChanged()
    GAME.showGameScale = true
    local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local previousXScale = GAME.canvasXScale
    GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
    if previousXScale ~= GAME.canvasXScale then
      GAME:refreshCanvasAndImagesForNewScale()
    end
  end

  local function updateScaleType(noUpdate)
    if noUpdate == false then
      config.gameScaleType = scaleTypeOptions[scaleTypeIndex]
      scaleSettingsChanged()
    end
    graphicsMenu:set_button_setting(2, translatedScaleTypeOptions[scaleTypeIndex])
    updateFixedScale(true)
  end

  local function previousScaleType()
    scaleTypeIndex = bound(1, scaleTypeIndex - 1, #scaleTypeOptions)
    updateScaleType(false)
  end

  local function nextScaleType()
    scaleTypeIndex = bound(1, scaleTypeIndex + 1, #scaleTypeOptions)
    updateScaleType(false)
  end

  updateFixedScale = function(noUpdate)
    if config.gameScaleType == "fixed" then
      if noUpdate == false then
        config.gameScaleFixedValue = GAME.availableScales[fixedScaleIndex]
        scaleSettingsChanged()
      end
      graphicsMenu:set_button_setting(3, GAME.availableScales[fixedScaleIndex]) --todo localize
    else
      -- ideally we would hide this setting, but its too hard without better UI control support
      graphicsMenu:set_button_setting(3, nil)
    end
  end

  local function previousFixedScale()
    if config.gameScaleType == "fixed" then
      fixedScaleIndex = bound(1, fixedScaleIndex - 1, #GAME.availableScales)
      updateFixedScale(false)
    end
  end

  local function nextFixedScale()
    if config.gameScaleType == "fixed" then
      fixedScaleIndex = bound(1, fixedScaleIndex + 1, #GAME.availableScales)
      updateFixedScale(false)
    end
  end

  local function update_portrait_darkness()
    graphicsMenu:set_button_setting(4, config.portrait_darkness)
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
    graphicsMenu:set_button_setting(5, config.popfx and loc("op_on") or loc("op_off"))
  end

  local function update_renderTelegraph(noToggle)
    if not noToggle then
      config.renderTelegraph = not config.renderTelegraph
    end
    graphicsMenu:set_button_setting(6, config.renderTelegraph and loc("op_on") or loc("op_off"))
  end

  local function update_renderAttacks(noToggle)
    if not noToggle then
      config.renderAttacks = not config.renderAttacks
    end
    graphicsMenu:set_button_setting(7, config.renderAttacks and loc("op_on") or loc("op_off"))
  end

  local function updateShakeIntensity()
    graphicsMenu:set_button_setting(8, config.shakeIntensity)
  end

  local function decreaseShakeIntensity()
    config.shakeIntensity = bound(0.5, config.shakeIntensity - 0.05, 1)
    updateShakeIntensity()
  end

  local function increaseShakeIntensity()
    config.shakeIntensity = bound(0.5, config.shakeIntensity + 0.05, 1)
    updateShakeIntensity()
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

  graphicsMenu = Click_menu(menu_x, menu_y, nil, themes[config.theme].main_menu_max_height, 1)
  graphicsMenu:add_button(loc("op_theme"), next_theme, goEscape, previous_theme, next_theme)
  graphicsMenu:add_button(loc("op_scale"), nextScaleType, goEscape, previousScaleType, nextScaleType)
  graphicsMenu:add_button(loc("op_scale_fixed_value"), nextFixedScale, goEscape, previousFixedScale, nextFixedScale)
  graphicsMenu:add_button(loc("op_portrait_darkness"), increase_portrait_darkness, goEscape, decrease_portrait_darkness, increase_portrait_darkness)
  graphicsMenu:add_button(loc("op_popfx"), update_popfx, goEscape, update_popfx, update_popfx)
  graphicsMenu:add_button(loc("op_renderTelegraph"), update_renderTelegraph, goEscape, update_renderTelegraph, update_renderTelegraph)
  graphicsMenu:add_button(loc("op_renderAttacks"), update_renderAttacks, goEscape, update_renderAttacks, update_renderAttacks)
  graphicsMenu:add_button(loc("op_shakeIntensity"), increaseShakeIntensity, goEscape, decreaseShakeIntensity, increaseShakeIntensity)
  graphicsMenu:add_button(loc("back"), exitSettings, exitSettings)
  update_theme()
  updateScaleType(true)
  updateFixedScale(true)
  update_portrait_darkness()
  update_popfx(true)
  update_renderTelegraph(true)
  update_renderAttacks(true)
  updateShakeIntensity()

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
  local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
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
        local audio_test_ret = nil
        local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
        local soundTestMenu
        local loaded_track_index = 0
        local index = 1
        local normalMusic = {}
        local dangerMusic = {}
        local playing = false
        local tracks = {}
        local character_sounds = {}
        local current_sound_index = 0

        local ram_load = 0
        local max_ram_load = 20 --arbitrary number of characters/stages allowed to load before forcing a garbagecollection

        local music_type = "normal_music"
        local musics_to_use = nil

        -- stop main music
        stop_all_audio()

        -- disable the menu_validate sound and keep a copy of it to restore later
        local menu_validate_sound = themes[config.theme].sounds.menu_validate
        themes[config.theme].sounds.menu_validate = themes[config.theme].zero_sound

        gprint(loc("op_music_load"), unpack(themes[config.theme].main_menu_screen_pos))
        wait()

        -- temporarily load music for characters that are not fully loaded to build tracklist, bundle characters add their subcharacters as tracks instead
        for _, character_id in ipairs(characters_ids_for_current_theme) do
          if not characters[character_id].fully_loaded then
            characters[character_id]:sound_init(true, false)
          end
          local character = characters[character_id]
          if next(character.sub_characters) == nil then
            tracks[#tracks + 1] = {
              is_character = true,
              name = string.len(trim(character.display_name)) == 0 and character_id or character.display_name,
              id = character_id,
              parent_id = nil,
              has_music = character.musics.normal_music and true,
              has_danger = character.musics.danger_music and true,
              style = character.music_style or "normal"
            }
            ram_load = ram_load + 1
          else
            for _, sub_character_id in ipairs(character.sub_characters) do
              if not characters[sub_character_id].fully_loaded then
                characters[sub_character_id]:sound_init(true, false)
              end
              local subcharacter = characters[sub_character_id]
              tracks[#tracks + 1] = {
                is_character = true,
                name = (string.len(trim(character.display_name)) == 0 and character_id or character.display_name) .. " " .. (string.len(trim(subcharacter.display_name)) == 0 and sub_character_id or subcharacter.display_name),
                id = sub_character_id,
                parent_id = character_id,
                has_music = subcharacter.musics.normal_music and true,
                has_danger = subcharacter.musics.danger_music and true,
                style = subcharacter.music_style or "normal"
              }
              ram_load = ram_load + 1
              if not characters[sub_character_id].fully_loaded then
                characters[sub_character_id]:sound_uninit(true, false)
              end
            end
          end
          if not characters[character_id].fully_loaded then
            characters[character_id]:sound_uninit() -- give thanks to our memory bandwidth
          end
          if ram_load > max_ram_load then
            collectgarbage("collect") -- forced collection to prevent our RAM from spiking too high and crashing
            ram_load = 0
          end
        end

        -- temporarily load music for stages that are not fully loaded to continue building tracklist, stages without music are skipped
        for _, stage_id in ipairs(stages_ids_for_current_theme) do
          if not stages[stage_id].fully_loaded then
            stages[stage_id]:sound_init(true, false)
          end
          local stage = stages[stage_id]
          if stage.musics.normal_music then
            tracks[#tracks + 1] = {
              is_character = false,
              name = stage.display_name,
              id = stage_id,
              parent_id = nil,
              has_music = true,
              has_danger = stage.musics.danger_music and true,
              style = stage.music_style or "normal"
            }
            ram_load = ram_load + 1
          end
          if not stages[stage_id].fully_loaded then
            stages[stage_id]:sound_uninit()
          end
          if ram_load > max_ram_load then
            collectgarbage("collect")
            ram_load = 0
          end
        end

        local function unloadTrack()
          if loaded_track_index > 0 then
            stop_the_music()
            if tracks[loaded_track_index].is_character then
              for _, v in pairs(character_sounds) do
                v.sound:stop()
              end
              character_sounds = {}
              if not characters[tracks[loaded_track_index].id].fully_loaded then
                characters[tracks[loaded_track_index].id]:sound_uninit()
              end
              if tracks[index].parent_id then
                if not characters[tracks[loaded_track_index].parent_id].fully_loaded then
                  characters[tracks[loaded_track_index].parent_id]:sound_uninit(true, false)
                end
              end
            else
              if not stages[tracks[loaded_track_index].id].fully_loaded then
                stages[tracks[loaded_track_index].id]:sound_uninit()
              end
            end
            normalMusic = {}
            dangerMusic = {}
            character_sounds = {}
            loaded = false
            playing = false
            soundTestMenu:set_button_text(3, loc("op_music_play"))
            loaded_track_index = 0
          end
        end

        local function addSound(name, sound)
          if sound then
            character_sounds[#character_sounds + 1] = {name = name, sound = sound}
          end
        end

        local function addSounds(sound_name, sound_table, spacer)
          for i = 1, #sound_table do
            addSound(sound_name .. ((i == 1 and "") or (spacer .. i)), sound_table[i], i)
          end
        end

        local function addAttackSfx(character, key)
          for i = 1, #character.sounds[key] do
            if i == 1 then
              addSounds(key, character.sounds[key][i], " ")
            else
              addSounds(key .. i, character.sounds[key][i], " ")
            end
          end
          --per_chain
          if
            (key == "chain" and character.chain_style == 1) or --per_combo
              (key == "combo" and character.combo_style == 1)
           then
            addSounds(key .. " ?", character.sounds[key][0], " ")
          end
        end

        local function loadTrack()
          if loaded_track_index ~= index then
            unloadTrack()
          end
          if not loaded then
            if tracks[index].is_character then
              if not characters[tracks[index].id].fully_loaded then
                characters[tracks[index].id]:sound_init(true, false)
                if tracks[index].parent_id then
                  characters[tracks[index].parent_id]:sound_init(true, false)
                end
              end
              musics_to_use = characters[tracks[index].id].musics

              local parent = nil
              if tracks[index].parent_id then
                parent = characters[tracks[index].parent_id]
              end
              local attackSfx = {chain = true, combo = true, shock = true}
              for key, value in pairs(characters[tracks[index].id].sounds) do
                if not attackSfx[key] then
                  if (value == nil or #value == 0) and parent then
                    addSounds(key, parent[key], " ")
                  else
                    addSounds(key, value, " ")
                  end
                else
                  if (value[0] == nil or #value[0] == 0) then
                    if parent then
                      addAttackSfx(parent, key)
                    end
                  else
                    addAttackSfx(characters[tracks[index].id], key)
                  end
                end
              end

              table.sort(
                character_sounds,
                function(a, b)
                  return a.name < b.name
                end
              )
              soundTestMenu:set_button_setting(4, character_sounds[1].name)

              current_sound_index = 1
            else
              if not stages[tracks[index].id].fully_loaded then
                stages[tracks[index].id]:sound_init(true, false)
              end
              musics_to_use = stages[tracks[index].id].musics

              current_sound_index = 0
              character_sounds = {}
              soundTestMenu:set_button_setting(4, loc("op_none"))
            end
            if tracks[index].style == "dynamic" then
              normalMusic = {musics_to_use["normal_music"], musics_to_use["normal_music_start"]}
              dangerMusic = {musics_to_use["danger_music"], musics_to_use["danger_music_start"]}
            else
              normalMusic = {}
              dangerMusic = {}
            end
            if not tracks[index].has_music then
              soundTestMenu:set_button_setting(2, loc("op_none"))
            elseif not tracks[index].has_danger then
              music_type = "normal_music"
              soundTestMenu:set_button_setting(2, music_type)
            end
          end
          loaded = true
          loaded_track_index = index
        end

        local function switchDanger()
          if not loaded then
            loadTrack()
          end
          if tracks[index].has_music and tracks[index].has_danger then
            if music_type == "danger_music" then
              music_type = "normal_music"
            else
              music_type = "danger_music"
            end
            soundTestMenu:set_button_setting(2, music_type)
            if playing then
              if tracks[index].style == "dynamic" then
                if music_type == "danger_music" then
                  setFadePercentageForGivenTracks(0, normalMusic)
                  setFadePercentageForGivenTracks(1, dangerMusic)
                else
                  setFadePercentageForGivenTracks(0, dangerMusic)
                  setFadePercentageForGivenTracks(1, normalMusic)
                end
              else
                stop_the_music()
                find_and_add_music(musics_to_use, music_type)
              end
            end
            soundTestMenu:set_button_setting(2, music_type)
          end
        end

        local function nextTrack()
          unloadTrack()
          if index == #tracks then
            index = 1
          else
            index = index + 1
          end
          soundTestMenu:set_button_setting(1, tracks[index].name)
          if tracks[index].is_character then
            soundTestMenu:set_button_text(1, loc("character"))
            soundTestMenu:set_button_setting(4, "chain")
          else
            soundTestMenu:set_button_text(1, loc("stage"))
            soundTestMenu:set_button_setting(4, loc("op_none"))
          end
          if not tracks[index].has_music then
            soundTestMenu:set_button_setting(2, loc("op_none"))
          elseif not tracks[index].has_danger then
            soundTestMenu:set_button_setting(2, "normal_music")
          else
            soundTestMenu:set_button_setting(2, music_type)
          end
        end

        local function previousTrack()
          unloadTrack()
          if index == 1 then
            index = #tracks
          else
            index = index - 1
          end
          soundTestMenu:set_button_setting(1, tracks[index].name)
          if tracks[index].is_character then
            soundTestMenu:set_button_text(1, loc("character"))
            soundTestMenu:set_button_setting(4, "chain")
          else
            soundTestMenu:set_button_text(1, loc("stage"))
            soundTestMenu:set_button_setting(4, loc("op_none"))
          end
          if not tracks[index].has_music then
            soundTestMenu:set_button_setting(2, loc("op_none"))
          elseif not tracks[index].has_danger then
            soundTestMenu:set_button_setting(2, "normal_music")
          else
            soundTestMenu:set_button_setting(2, music_type)
          end
        end

        local function playOrStopMusic()
          if not loaded then
            loadTrack()
          end
          if tracks[index].has_music then
            if playing then
              stop_the_music()
              playing = false
              soundTestMenu:set_button_text(3, loc("op_music_play"))
            else
              if tracks[index].style == "dynamic" then
                find_and_add_music(musics_to_use, "normal_music")
                find_and_add_music(musics_to_use, "danger_music")
                if music_type == "danger_music" then
                  setFadePercentageForGivenTracks(0, normalMusic)
                  setFadePercentageForGivenTracks(1, dangerMusic)
                else
                  setFadePercentageForGivenTracks(0, dangerMusic)
                  setFadePercentageForGivenTracks(1, normalMusic)
                end
              else
                stop_the_music()
                find_and_add_music(musics_to_use, music_type)
              end
              playing = true
              soundTestMenu:set_button_text(3, loc("op_music_stop"))
            end
          end
        end

        local function nextSFX()
          if tracks[index].is_character then
            if not loaded then
              loadTrack()
            end
            if next(character_sounds) then
              if current_sound_index == #character_sounds then
                current_sound_index = 1
              else
                current_sound_index = current_sound_index + 1
              end
              soundTestMenu:set_button_setting(4, character_sounds[current_sound_index].name)
            end
          end
        end

        local function previousSFX()
          if tracks[index].is_character then
            if not loaded then
              loadTrack()
            end
            if next(character_sounds) then
              if current_sound_index == 1 then
                current_sound_index = #character_sounds
              else
                current_sound_index = current_sound_index - 1
              end
              soundTestMenu:set_button_setting(4, character_sounds[current_sound_index].name)
            end
          end
        end

        local function playSFX()
          if tracks[index].is_character then
            if not loaded then
              loadTrack()
            end
            for _, v in pairs(character_sounds) do
              v.sound:stop()
            end
            play_optional_sfx(character_sounds[current_sound_index].sound)
          end
        end

        local function goBack()
          soundTestMenu:set_active_idx(#soundTestMenu.buttons)
        end

        --fallback to main theme if nothing is playing or if dynamic music is playing, dynamic music cannot cleanly be "carried out" of the sound test due to the master volume reapplication in the audio options menu
        local function exitAudioTest()
          if (not playing) or (tracks[index].style == "dynamic") then
            if loaded then
              unloadTrack()
            end
            find_and_add_music(themes[config.theme].musics, "main")
          end
          themes[config.theme].sounds.menu_validate = menu_validate_sound
          audio_test_ret = {audio_menu, {6}}
        end

        soundTestMenu = Click_menu(menu_x, menu_y, nil, themes[config.theme].main_menu_max_height, 1)
        soundTestMenu:add_button(loc("character"), nextTrack, goBack, previousTrack, nextTrack)
        soundTestMenu:add_button(loc("op_music_type"), switchDanger, goBack, switchDanger, switchDanger)
        soundTestMenu:add_button(loc("op_music_play"), playOrStopMusic, goBack)
        soundTestMenu:add_button(loc("op_music_sfx"), playSFX, goBack, previousSFX, nextSFX)
        soundTestMenu:add_button(loc("back"), exitAudioTest, exitAudioTest)
        soundTestMenu:set_button_setting(1, tracks[index].name)
        if tracks[index].has_music then
          soundTestMenu:set_button_setting(2, music_type)
        else
          soundTestMenu:set_button_setting(2, loc("op_none"))
        end
        unloadTrack()
        loadTrack()
        unloadTrack()

        while true do
          soundTestMenu:draw()
          wait()
          variable_step(
            function()
              soundTestMenu:update()
            end
          )

          if audio_test_ret then
            soundTestMenu:remove_self()
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

  audioMenu = Click_menu(menu_x, menu_y, nil, themes[config.theme].main_menu_max_height, 1)
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

local function debug_menu(button_idx)
  local ret = nil
  local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
  local vsFramesBehind = config.debug_vsFramesBehind or 0
  local debugMenu

  local function update_debug(noToggle)
    if not noToggle then
      config.debug_mode = not config.debug_mode
    end
    debugMenu:set_button_setting(1, config.debug_mode and loc("op_on") or loc("op_off"))
  end

  local function updateVsFramesBehind()
    config.debug_vsFramesBehind = vsFramesBehind
    debugMenu:set_button_setting(2, vsFramesBehind)
  end

  local framesBehindLimit = 200

  local function increaseVsFramesBehind()
    vsFramesBehind = bound(-framesBehindLimit, vsFramesBehind + 1, framesBehindLimit)
    updateVsFramesBehind()
  end

  local function decreaseVsFramesBehind()
    vsFramesBehind = bound(-framesBehindLimit, vsFramesBehind - 1, framesBehindLimit)
    updateVsFramesBehind()
  end

  local function update_debugServers(noToggle)
    if not noToggle then
      config.debugShowServers = not config.debugShowServers
    end
    debugMenu:set_button_setting(3, config.debugShowServers and loc("op_on") or loc("op_off"))
  end

  local function nextMenu()
    debugMenu:selectNextIndex()
  end

  local function goEscape()
    debugMenu:set_active_idx(#debugMenu.buttons)
  end

  local function exitSettings()
    ret = {options.main, {5}}
  end

  debugMenu = Click_menu(menu_x, menu_y, nil, themes[config.theme].main_menu_max_height, 1)
  debugMenu:add_button(loc("op_debug"), update_debug, goEscape, update_debug, update_debug)
  debugMenu:add_button("VS Frames Behind", nextMenu, goEscape, decreaseVsFramesBehind, increaseVsFramesBehind)
  debugMenu:add_button("Show Debug Servers", update_debugServers, goEscape, update_debugServers, update_debugServers)
  debugMenu:add_button(loc("back"), exitSettings, exitSettings)
  update_debug(true)
  updateVsFramesBehind()
  update_debugServers(true)

  if button_idx then
    debugMenu:set_active_idx(button_idx)
  end

  while true do
    debugMenu:draw()
    wait()
    variable_step(
      function()
        debugMenu:update()
      end
    )

    if ret then
      debugMenu:remove_self()
      return unpack(ret)
    end
  end
end

local function about_menu(button_idx)
  local ret = nil
  local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
  GAME.backgroundImage = themes[config.theme].images.bg_main
  local aboutMenu

  local function show_readme(filename, returnIndex)
    GAME.backgroundImage = themes[config.theme].images.bg_readme
    reset_filters()

    local readme = read_txt_file(filename)
    local text = love.graphics.newText(get_global_font(), readme)
    local heightDiff = text:getHeight() - (canvas_height - 15)
    local offset = 0
    local scrollStep = 14
    while true do
      gfx_q:push({love.graphics.draw, {text, 15, 15, nil, nil, nil, nil, offset}})
      wait()
      local readmeRet = nil
      variable_step(
        function()
          if menu_escape() or menu_enter() then
            readmeRet = {about_menu, {returnIndex}}
          elseif heightDiff > 0 then
            if menu_up() then
              offset = math.max(0, offset - scrollStep)
            elseif menu_down() then
              offset = math.min(heightDiff + (scrollStep - (heightDiff % scrollStep)), offset + scrollStep)
            end
          end
        end
      )
      if readmeRet then
        return unpack(readmeRet)
      end
    end
  end

  local function show_themes_readme()
    if not love.filesystem.getInfo(Theme.themeDirectoryPath .. prefix_of_ignored_dirs .. consts.DEFAULT_THEME_DIRECTORY) then
      --print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
      gprint(loc("op_copy_files"), 280, 280)
      wait()
      recursive_copy(Theme.themeDirectoryPath .. consts.DEFAULT_THEME_DIRECTORY, Theme.themeDirectoryPath .. prefix_of_ignored_dirs .. consts.DEFAULT_THEME_DIRECTORY)

      -- Android can't easily copy into the save dir, so do it for them to help.
      recursive_copy("default_data/themes", "themes")
    end

    ret = {show_readme, {"readme_themes.md", 1}}
  end

  local function show_characters_readme()
    ret = {show_readme, {"readme_characters.md", 2}}
  end

  local function show_stages_readme()
    ret = {show_readme, {"readme_stages.md", 3}}
  end

  local function show_panels_readme()
    ret = {show_readme, {"readme_panels.txt", 4}}
  end

  local function show_attack_readme()
    ret = {show_readme, {"readme_training.txt", 5}}
  end

  local function show_installMods_readme()
    ret = {show_readme, {"readme_installmods.md"}}
  end

  local function show_system_info()
    ret = {
      function()
        GAME.backgroundImage = themes[config.theme].images.bg_readme
        reset_filters()
        local renderer_name, renderer_version, graphics_card_vendor, graphics_card_name = love.graphics.getRendererInfo()
        local sys_info = {}
        sys_info[#sys_info + 1] = {name = "Operating System", value = love.system.getOS()}
        sys_info[#sys_info + 1] = {name = "Renderer", value = renderer_name .. " " .. renderer_version}
        sys_info[#sys_info + 1] = {name = "Graphics Card", value = graphics_card_name}
        sys_info[#sys_info + 1] = {name = "LOVE Version", value = Game.loveVersionString()}
        sys_info[#sys_info + 1] = {name = "Panel Attack Engine Version", value = VERSION}
        sys_info[#sys_info + 1] = {name = "Panel Attack Release Version", value = GAME_UPDATER_GAME_VERSION}
        sys_info[#sys_info + 1] = {name = "Save Data Directory Path", value = love.filesystem.getSaveDirectory()}
        sys_info[#sys_info + 1] = {name = "Characters [Enabled/Total]", value = #characters_ids_for_current_theme .. "/" .. #characters_ids}
        sys_info[#sys_info + 1] = {name = "Stages [Enabled/Total]", value = #stages_ids_for_current_theme .. "/" .. #stages_ids}
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
                panels_ret = {about_menu, {6}}
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
    ret = {options.main, {6}}
  end

  aboutMenu = Click_menu(menu_x, menu_y, nil, themes[config.theme].main_menu_max_height, 1)
  aboutMenu:add_button(loc("op_about_themes"), show_themes_readme, goEscape)
  aboutMenu:add_button(loc("op_about_characters"), show_characters_readme, goEscape)
  aboutMenu:add_button(loc("op_about_stages"), show_stages_readme, goEscape)
  aboutMenu:add_button(loc("op_about_panels"), show_panels_readme, goEscape)
  aboutMenu:add_button("About Attack Files", show_attack_readme, goEscape)
  aboutMenu:add_button("Installing Mods", show_installMods_readme, goEscape)
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

local function userIDMenu(button_idx)
  local ret = nil
  local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
  local userIDDirectories = FileUtil.getFilteredDirectoryItems("servers")
  local userIDClickMenu
  local currentButtonIndex

  local function updateID()
    ret = {
      function()
        local updateIDRet = nil
        local id = read_user_id_file(userIDDirectories[currentButtonIndex]) or ""
        love.keyboard.setTextInput(true) -- enables user to type
        while true do
          local to_print = "Enter User ID (or paste from clipboard)"
          local line2 = id
          if (love.timer.getTime() * 3) % 2 > 1 then
            line2 = line2 .. "| "
          end
          gprintf(to_print, 0, canvas_height / 2, canvas_width, "center")
          gprintf(line2, (canvas_width / 2) - 120, (canvas_height / 2) + 20)
          wait()
          variable_step(
            function()
              if this_frame_keys["escape"] then
                updateIDRet = {userIDMenu, {currentButtonIndex}}
              end
              if menu_return_once() then
                write_user_id_file(id, userIDDirectories[currentButtonIndex])
                updateIDRet = {userIDMenu, {currentButtonIndex}}
              end
              if menu_backspace() then
                -- Remove the last character.
                -- This could be a UTF-8 character, so handle it properly.
                local utf8offset = utf8.offset(id, -1)
                if utf8offset then
                  id = string.sub(id, 1, utf8offset - 1)
                end
              end
              for _, v in ipairs(this_frame_unicodes) do
                if v:match("%d") then
                  id = id .. v
                end
              end
              if (love.keyboard.isDown("rctrl") or love.keyboard.isDown("lctrl")) and keys["v"] then
                local clipboardText = love.system.getClipboardText()
                if clipboardText:match("%d") then
                  id = clipboardText
                end
              end
            end
          )
          if updateIDRet then
            love.keyboard.setTextInput(false)
            return unpack(updateIDRet)
          end
        end
      end
    }
  end

  local function goEscape()
    userIDClickMenu:set_active_idx(#userIDClickMenu.buttons)
  end

  local function exitSettings()
    ret = {options.main, {7}}
  end

  userIDClickMenu = Click_menu(menu_x, menu_y, nil, themes[config.theme].main_menu_max_height, 1)
  for i = 1, #userIDDirectories do
    if userIDDirectories[i] == consts.SERVER_LOCATION then
      userIDClickMenu:add_button("Main Server ID", updateID, goEscape)
    else
      userIDClickMenu:add_button(userIDDirectories[i], updateID, goEscape)
    end
  end
  userIDClickMenu:add_button(loc("back"), exitSettings, exitSettings)

  if button_idx then
    userIDClickMenu:set_active_idx(button_idx)
  end

  while true do
    gprintf("Keep these numbers secret, they are your password to the server. Only change this number if you have a previous number backed up or a developer recovered it for you.", 0, menu_y, nil, "center")
    userIDClickMenu:draw()
    wait()
    variable_step(
      function()
        currentButtonIndex = userIDClickMenu.active_idx
        userIDClickMenu:update()
      end
    )

    if ret then
      userIDClickMenu:remove_self()
      return unpack(ret)
    end
  end
end

function options.main(button_idx)
  local ret = nil
  local menu_x, menu_y = unpack(themes[config.theme].main_menu_screen_pos)
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

  local function enter_debug_menu()
    ret = {debug_menu}
  end

  local function enter_about_menu()
    ret = {about_menu}
  end

  local function enterUserIDMenu()
    ret = {userIDMenu}
  end

  local function nextMenu()
    optionsMenu:selectNextIndex()
  end

  local function goEscape()
    optionsMenu:set_active_idx(#optionsMenu.buttons)
  end

  local function exitSettings()
    gprint("writing config to file...", unpack(themes[config.theme].main_menu_screen_pos))
    wait()

    local previousMenuPosition = themes[config.theme].main_menu_screen_pos
    config.theme = found_themes[theme_index]

    write_conf_file()

    local themeChanged = true
    if memory_before_options_menu ~= nil and config.theme == memory_before_options_menu.theme then
      themeChanged = false
    end

    if themeChanged then
      gprint(loc("op_reload_theme"), unpack(previousMenuPosition))
      wait()
      stop_the_music()
      theme_init()
      localization:set_language(language_choices[language_number]) -- Apply new font and font size if needed
      if themes[config.theme].musics["main"] then
        find_and_add_music(themes[config.theme].musics, "main")
      end

      -- stages before characters since they are part of their loading
      gprint(loc("op_reload_stages"), unpack(themes[config.theme].main_menu_screen_pos))
      wait()
      stages_init()

      gprint(loc("op_reload_characters"), unpack(themes[config.theme].main_menu_screen_pos))
      wait()
      CharacterLoader.initCharacters()
    end

    if memory_before_options_menu == nil or config.enable_analytics ~= memory_before_options_menu.enable_analytics then
      gprint(loc("op_reload_analytics"), unpack(themes[config.theme].main_menu_screen_pos))
      wait()
      analytics.init()
    end

    apply_config_volume()

    memory_before_options_menu = nil
    ret = {main_select_mode}
  end

  optionsMenu = Click_menu(menu_x, menu_y, nil, themes[config.theme].main_menu_max_height, 1)
  optionsMenu:add_button(loc("op_language"), nextMenu, goEscape, decrease_language, increase_language)
  optionsMenu:add_button(loc("op_general"), enter_general_menu, goEscape)
  optionsMenu:add_button(loc("op_graphics"), enter_graphics_menu, goEscape)
  optionsMenu:add_button(loc("op_audio"), enter_audio_menu, goEscape)
  optionsMenu:add_button(loc("op_debug"), enter_debug_menu, goEscape)
  optionsMenu:add_button(loc("op_about"), enter_about_menu, goEscape)
  optionsMenu:add_button("Modify User ID", enterUserIDMenu, goEscape)
  optionsMenu:add_button(loc("back"), exitSettings, exitSettings)
  update_language()

  if button_idx then
    optionsMenu:set_active_idx(button_idx)
  else
    found_themes = {}
    for _, v in ipairs(FileUtil.getFilteredDirectoryItems("themes")) do
      if love.filesystem.getInfo(Theme.themeDirectoryPath .. v) and love.filesystem.getInfo(Theme.themeDirectoryPath .. v .. "/config.json") then
        found_themes[#found_themes + 1] = v
        if config.theme == v then
          theme_index = #found_themes
        end
      end
    end
  end

  if memory_before_options_menu == nil then
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

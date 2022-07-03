local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local LevelSlider = require("ui.LevelSlider")
local scene_manager = require("scenes.scene_manager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local Stepper = require("ui.Stepper")
local input = require("input2")
local save = require("save")

--@module BasicMenu
local options_menu = Scene("options_menu")

local ret = nil
local menu_x, menu_y = unpack(main_menu_screen_pos)
menu_y = menu_y + 70
local language_number
local language_choices = {}
local language_names = {}
for k, v in ipairs(localization:get_list_codes()) do
  language_choices[k] = v
  language_names[#language_names + 1] = {v, localization.data[v]["LANG"]}
  if localization:get_language() == v then
    language_number = k
  end
end

local optionsMenu

local options_state
local active_menu_name = "base_menu"
local info_name

local menus = {
  base_menu = nil,
  general_menu = nil,
  graphics_menu = nil,
  audio_menu = nil,
  debug_menu = nil,
  about_menu = nil,
}

local found_themes = {}
local about_text = {}
local info_string

local font = love.graphics.getFont()

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end

local function updateMenuLanguage()
  for menu_name, menu in pairs(menus) do
    menu:updateLabel()
  end
end

local function switchMenu(menu_name)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  menus[menu_name]:setVisibility(true)
  menus[active_menu_name]:setVisibility(false)
  active_menu_name = menu_name
end

local function createToggleButtonGroup(config_field, on_change_fn)
  return ButtonGroup(
    {
      Button({width = 60, label = "op_off"}),
      Button({width = 60, label = "op_on"}),
    },
    {false, true},
    {
      selected_index = config[config_field] and 2 or 1,
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move) 
        config[config_field] = value
        if on_change_fn then
          on_change_fn()
        end
      end
    }
  )
end

local function createConfigSlider(config_field, min, max, on_value_change_fn)
  return Slider({
    min = min, 
    max = max, 
    value = config[config_field] or 20,
    tick_length = math.ceil(100 / max),
    onValueChange = function(slider)
      config[config_field] = slider.value
      if on_value_change_fn then
        on_value_change_fn(slider)
      end
    end
  })
end

local function setupDrawThemesInfo()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  GAME.backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()

  if not love.filesystem.getInfo("themes/" .. prefix_of_ignored_dirs .. default_theme_dir) then
    --print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
    gprint(loc("op_copy_files"), 280, 280)
    recursive_copy("themes/" .. default_theme_dir, "themes/" .. prefix_of_ignored_dirs .. default_theme_dir)

    -- Android can't easily copy into the save dir, so do it for them to help.
    recursive_copy("default_data/themes", "themes")
  end
  options_state = "info"
  info_name = "themes"
  menus["about_menu"]:setVisibility(false)
end

local function setupInfo(info_type)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  GAME.backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()
  options_state = "info"
  info_name = info_type
  menus["about_menu"]:setVisibility(false)
end

local function setupSystemInfo()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  GAME.backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()
  local renderer_name, renderer_version, graphics_card_vendor, graphics_card_name = love.graphics.getRendererInfo()
  local sys_info = {}
  sys_info[#sys_info + 1] = {name = "Operating System", value = love.system.getOS()} 
  sys_info[#sys_info + 1] = {name = "Renderer", value = renderer_name.." "..renderer_version}
  sys_info[#sys_info + 1] = {name = "Graphics Card", value = graphics_card_name}
  sys_info[#sys_info + 1] = {name = "LOVE Version", value = GAME:loveVersionString()} 
  sys_info[#sys_info + 1] = {name = "Panel Attack Engine Version", value = VERSION} 
  sys_info[#sys_info + 1] = {name = "Panel Attack Release Version", value = GAME_UPDATER_GAME_VERSION} 
  sys_info[#sys_info + 1] = {name = "Save Data Directory Path", value = love.filesystem.getSaveDirectory()}  
  sys_info[#sys_info + 1] = {name = "Characters [Enabled/Total]", value = #characters_ids_for_current_theme.."/"..#characters_ids} 
  sys_info[#sys_info + 1] = {name = "Stages [Enabled/Total]", value = #stages_ids_for_current_theme.."/"..#stages_ids} 
  sys_info[#sys_info + 1] = {name = "Total Panel Sets", value = #panels_ids} 
  sys_info[#sys_info + 1] = {name = "Total Themes", value = #found_themes}

  info_string = ""
  for index, info in ipairs(sys_info) do
    info_string = info_string .. info.name .. ": " .. (info.value or "Unknown") .. "\n"
  end
  options_state = "system_info"
  menus["about_menu"]:setVisibility(false)
end

local function drawSystemInfo()
  gprint(info_string, 15, 15)
  if input.isDown["Swap2"] then
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    GAME.backgroundImage = themes[config.theme].images.bg_main
    reset_filters()
    options_state = "menus"
    menus["about_menu"]:setVisibility(true)
  end
end

local function drawInfo(text)
  gprint(about_text[text], 15, 15)
  if input.isDown["Swap2"] then
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    GAME.backgroundImage = themes[config.theme].images.bg_main
    reset_filters()
    options_state = "menus"
    menus["about_menu"]:setVisibility(true)
  end
end

function options_menu:init()
  scene_manager:addScene(self)
  about_text["themes"] = save.read_txt_file("readme_themes.txt")
  about_text["characters"] = save.read_txt_file("readme_characters.txt")
  about_text["stages"] = save.read_txt_file("readme_stages.txt")
  about_text["panels"] = save.read_txt_file("readme_panels.txt")
  about_text["attackFiles"] = save.read_txt_file("readme_training.txt")

  local language_labels = {}
  for k, v in ipairs(language_names) do
    language_labels[#language_labels + 1] = Label({
        label = v[2],
        translate = false,
        width = 70,
        height = 25})
  end
  local language_stepper = Stepper(
    language_labels,
    language_names,
    {
      selected_index = language_number,
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move) 
        localization:set_language(value[1])
        updateMenuLanguage() 
      end
    }
  )
  
  
  local label_width = 130
  local base_menu_options = {
    --{Label({width = label_width, label = "op_language"}), language_button_group},
    {Label({width = label_width, label = "op_language"}), language_stepper},
    {Button({width = label_width, label = "op_general", onClick = function() switchMenu("general_menu") end})},
    {Button({width = label_width, label = "op_graphics", onClick = function() switchMenu("graphics_menu") end})},
    {Button({width = label_width, label = "op_audio", onClick = function() switchMenu("audio_menu") end})},
    {Button({width = label_width, label = "op_debug", onClick = function() switchMenu("debug_menu") end})},
    {Button({width = label_width, label = "op_about", onClick = function() switchMenu("about_menu") end})},
    {Button({width = label_width, label = "back", onClick = exitMenu})},
  }

  local save_replays_publicly_index_map = {["with my name"] = 1, ["anonymously"] = 2, ["not at all"] = 3}
  local public_replay_button_group = ButtonGroup(
    {
      Button({label = "op_replay_public_with_name"}),
      Button({label = "op_replay_public_anonymously"}),
      Button({label = "op_replay_public_no"}),
    },
    {"with my name", "anonymously", "not at all"},
    {
      selected_index = save_replays_publicly_index_map[config.save_replays_publicly],
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move) 
        config.save_replays_publicly = value
      end
    }
  )

  local general_menu_options = {
    {Label({width = label_width, label = "op_vsync"}), createToggleButtonGroup("vsync", function() love.window.setVSync(config.vsync) end)},
    {Label({width = label_width, label = "op_countdown"}), createToggleButtonGroup("ready_countdown_1P")},
    {Label({width = label_width, label = "op_fps"}), createToggleButtonGroup("show_fps")},
    {Label({width = label_width, label = "op_ingame_infos"}), createToggleButtonGroup("show_ingame_infos")},
    {Label({width = label_width, label = "op_analytics"}), createToggleButtonGroup("enable_analytics")},
    {Label({width = label_width, label = "op_input_delay"}), createConfigSlider("input_repeat_delay", 0, 50)},
    {Label({width = label_width, label = "op_replay_public"}), public_replay_button_group},
    {Button({width = label_width, label = "back", onClick = function() switchMenu("base_menu") end})},
  }

  local theme_index
  local theme_buttons = {}
  for k, v in ipairs(love.filesystem.getDirectoryItems("themes")) do
    if love.filesystem.getInfo("themes/" .. v) and v:sub(0, prefix_of_ignored_dirs:len()) ~= prefix_of_ignored_dirs then
      found_themes[#found_themes + 1] = v
      theme_buttons[#theme_buttons + 1] = Button({label = v, translate = false})
      if config.theme == v then
        theme_index = #found_themes
      end
    end
  end
  
  local theme_button_group = ButtonGroup(
    theme_buttons,
    found_themes,
    {
      selected_index = theme_index,
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move) 
        config.theme = value
        stop_the_music()
        theme_init()
        GAME.backgroundImage = themes[config.theme].images.bg_main
        if themes[config.theme].musics["main"] then
          find_and_add_music(themes[config.theme].musics, "main")
        end
      end
    }
  )
  
  local graphics_menu_options = {
    {Label({width = label_width, label = "op_theme"}), theme_button_group},
    {Label({width = label_width, label = "op_portrait_darkness"}), createConfigSlider("portrait_darkness", 0, 100)},
    {Label({width = label_width, label = "op_popfx"}), createToggleButtonGroup("popfx")},
    {Label({width = label_width, label = "op_renderTelegraph"}), createToggleButtonGroup("renderTelegraph")},
    {Label({width = label_width, label = "op_renderAttacks"}), createToggleButtonGroup("renderAttacks")},
    {Button({width = label_width, label = "back", onClick = function() switchMenu("base_menu") end})},
  }
  
  local sound_test_menu_options = {
    {Label({width = label_width, label = "character"})},
    {Label({width = label_width, label = "op_music_type"})},
    {Label({width = label_width, label = "op_music_play"})},
    {Label({width = label_width, label = "op_music_sfx"})},
    {Button({width = label_width, label = "back", onClick = function() switchMenu("audio_menu") end})},
  }
        
  local music_frequency_index_map = {["stage"] = 1, ["often_stage"] = 2, ["either"] = 3, ["often_characters"] = 4, ["characters"] = 5}
  local music_frequency_stepper = Stepper(
    {
      Label({label = "op_only_stage"}),
      Label({label = "op_often_stage"}),
      Label({label = "op_stage_characters"}),
      Label({label = "op_often_characters"}),
      Label({label = "op_only_characters"}),
    },
    {"stage", "often_stage", "either", "often_characters", "characters"},
    {
      selected_index = music_frequency_index_map[config.use_music_from],
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        config.use_music_from = value
      end
    }
  )
  
  local audio_menu_options = {
    {Label({width = label_width, label = "op_vol"}), createConfigSlider("master_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = label_width, label = "op_vol_sfx"}), createConfigSlider("SFX_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = label_width, label = "op_vol_music"}), createConfigSlider("music_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = label_width, label = "op_use_music_from"}), music_frequency_stepper},
    {Label({width = label_width, label = "op_music_delay"}), createToggleButtonGroup("danger_music_changeback_delay")},
    {Button({width = label_width, label = "mm_music_test", onClick = function() scene_manager:switchScene("sound_test") end})},
    {Button({width = label_width, label = "back", onClick = function() switchMenu("base_menu") end})},
  }
  
  local debut_menu_options = {
    {Label({width = label_width, label = "op_debug"}), createToggleButtonGroup("debug_mode")},
    {Label({width = label_width, label = "VS Frames Behind", translate = false}), createConfigSlider("debug_vsFramesBehind", -200, 200)},
    {Button({width = label_width, label = "back", onClick = function() switchMenu("base_menu") end})},
  }
  
  local about_menu_options = {
    {Button({width = label_width, label = "op_about_themes", onClick = setupDrawThemesInfo})},
    {Button({width = label_width, label = "op_about_characters", onClick = function() setupInfo("characters") end})},
    {Button({width = label_width, label = "op_about_stages", onClick = function() setupInfo("stages") end})},
    {Button({width = label_width, label = "op_about_panels", onClick = function() setupInfo("panels") end})},
    {Button({width = label_width, label = "About Attack Files", translate = false, onClick = function() setupInfo("attackFiles") end})},
    {Button({width = label_width, label = "System Info", translate = false, onClick = setupSystemInfo})},
    {Button({width = label_width, label = "back", onClick = function() switchMenu("base_menu") end})},
  }
  
  local x, y = unpack(main_menu_screen_pos)
  x = x - 70--- 400
  y = y + 10
  menus["base_menu"] = Menu(base_menu_options, {x = x, y = y})
  menus["general_menu"] = Menu(general_menu_options, {x = x, y = y})
  menus["graphics_menu"] = Menu(graphics_menu_options, {x = x, y = y})
  menus["sound_test_menu"] = Menu(sound_test_menu_options, {x = x, y = y})
  menus["audio_menu"] = Menu(audio_menu_options, {x = x, y = y})
  menus["debug_menu"] = Menu(debut_menu_options, {x = x, y = y})
  menus["about_menu"] = Menu(about_menu_options, {x = x, y = y})

  for menu_name, menu in pairs(menus) do
    menu:setVisibility(false)
  end
end

function options_menu:load()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  options_state = "menus"
  menus[active_menu_name]:setVisibility(true)
end

function options_menu:update()
  if options_state == "menus" then
    menus[active_menu_name]:update()
    menus[active_menu_name]:draw()
  elseif options_state == "info" then
    drawInfo(info_name)
  elseif options_state == "system_info" then
    drawSystemInfo()
  end
end

function options_menu:unload()
  menus[active_menu_name]:setVisibility(false)
end

return options_menu
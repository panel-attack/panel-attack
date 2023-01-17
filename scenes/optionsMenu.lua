local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local LevelSlider = require("ui.LevelSlider")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local Stepper = require("ui.Stepper")
local input = require("inputManager")
local save = require("save")
local consts = require("consts")
local GraphicsUtil = require("graphics_util")

--@module BasicMenu
local optionsMenu = Scene("optionsMenu")

local ret = nil
local languageNumber
local languageChoices = {}
local languageName = {}
local backgroundImage = nil
for k, v in ipairs(localization:get_list_codes()) do
  languageChoices[k] = v
  languageName[#languageName + 1] = {v, localization.data[v]["LANG"]}
  if localization:get_language() == v then
    languageNumber = k
  end
end

local optionsState
local activeMenuName = "baseMenu"
local infoName

local menus = {
  baseMenu = nil,
  generalMenu = nil,
  graphicsMenu = nil,
  audioMenu = nil,
  debugMenu = nil,
  aboutMenu = nil,
}

local foundThemes = {}
local aboutText = {}
local infoString

local font = GraphicsUtil.getGlobalFont()

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  sceneManager:switchToScene("mainMenu")
end

local function updateMenuLanguage()
  for _, menu in pairs(menus) do
    menu:updateLabel()
  end
end

local function switchMenu(menuName)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  menus[menuName]:setVisibility(true)
  menus[activeMenuName]:setVisibility(false)
  activeMenuName = menuName
end

local function createToggleButtonGroup(configField, onChangeFn)
  return ButtonGroup(
    {
      buttons = {
        Button({width = 60, label = "op_off"}),
        Button({width = 60, label = "op_on"}),
      },
      values = {false, true},
      selectedIndex = config[configField] and 2 or 1,
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move) 
        config[configField] = value
        if onChangeFn then
          onChangeFn()
        end
      end
    }
  )
end

local function createConfigSlider(configField, min, max, onValueChangeFn)
  return Slider({
    min = min, 
    max = max, 
    value = config[configField] or 20,
    tickLength = math.ceil(100 / max),
    onValueChange = function(slider)
      config[configField] = slider.value
      if onValueChangeFn then
        onValueChangeFn(slider)
      end
    end
  })
end

local function setupDrawThemesInfo()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()

  if not love.filesystem.getInfo("themes/" .. prefix_of_ignored_dirs .. consts.DEFAULT_THEME_DIRECTORY) then
    --print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
    gprint(loc("op_copy_files"), 280, 280)
    recursive_copy("themes/" .. consts.DEFAULT_THEME_DIRECTORY, "themes/" .. prefix_of_ignored_dirs .. consts.DEFAULT_THEME_DIRECTORY)

    -- Android can't easily copy into the save dir, so do it for them to help.
    recursive_copy("default_data/themes", "themes")
  end
  optionsState = "info"
  infoName = "themes"
  menus["aboutMenu"]:setVisibility(false)
end

local function setupInfo(infoType)
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()
  optionsState = "info"
  infoName = infoType
  menus["aboutMenu"]:setVisibility(false)
end

local function setupSystemInfo()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()
  local rendererName, rendererVersion, graphicsCardVender, graphicsCardName = love.graphics.getRendererInfo()
  local sysInfo = {}
  sysInfo[#sysInfo + 1] = {name = "Operating System", value = love.system.getOS()} 
  sysInfo[#sysInfo + 1] = {name = "Renderer", value = rendererName.." "..rendererVersion}
  sysInfo[#sysInfo + 1] = {name = "Graphics Card", value = graphicsCardName}
  sysInfo[#sysInfo + 1] = {name = "LOVE Version", value = GAME:loveVersionString()} 
  sysInfo[#sysInfo + 1] = {name = "Panel Attack Engine Version", value = VERSION} 
  sysInfo[#sysInfo + 1] = {name = "Panel Attack Release Version", value = GAME_UPDATER_GAME_VERSION} 
  sysInfo[#sysInfo + 1] = {name = "Save Data Directory Path", value = love.filesystem.getSaveDirectory()}  
  sysInfo[#sysInfo + 1] = {name = "Characters [Enabled/Total]", value = #characters_ids_for_current_theme.."/"..#characters_ids} 
  sysInfo[#sysInfo + 1] = {name = "Stages [Enabled/Total]", value = #stages_ids_for_current_theme.."/"..#stages_ids} 
  sysInfo[#sysInfo + 1] = {name = "Total Panel Sets", value = #panels_ids} 
  sysInfo[#sysInfo + 1] = {name = "Total Themes", value = #foundThemes}

  infoString = ""
  for index, info in ipairs(sysInfo) do
    infoString = infoString .. info.name .. ": " .. (info.value or "Unknown") .. "\n"
  end
  optionsState = "system_info"
  menus["aboutMenu"]:setVisibility(false)
end

local function drawSystemInfo()
  gprint(infoString, 15, 15)
  if input.isDown["Swap2"] then
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    backgroundImage = themes[config.theme].images.bg_main
    reset_filters()
    optionsState = "menus"
    menus["aboutMenu"]:setVisibility(true)
  end
end

local function drawInfo(text)
  gprint(aboutText[text], 15, 15)
  if input.isDown["Swap2"] then
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    backgroundImage = themes[config.theme].images.bg_main
    reset_filters()
    optionsState = "menus"
    menus["aboutMenu"]:setVisibility(true)
  end
end

function optionsMenu:init()
  sceneManager:addScene(self)
  aboutText["themes"] = save.read_txt_file("readme_themes.txt")
  aboutText["characters"] = save.read_txt_file("readme_characters.txt")
  aboutText["stages"] = save.read_txt_file("readme_stages.txt")
  aboutText["panels"] = save.read_txt_file("readme_panels.txt")
  aboutText["attackFiles"] = save.read_txt_file("readme_training.txt")

  local languageLabels = {}
  for k, v in ipairs(languageName) do
    languageLabels[#languageLabels + 1] = Label({
        label = v[2],
        translate = false,
        width = 70,
        height = 25})
  end
  local languageStepper = Stepper(
    {
      labels = languageLabels,
      values = languageName,
      selectedIndex = languageNumber,
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move) 
        localization:set_language(value[1])
        updateMenuLanguage() 
      end
    }
  )
  
  
  local labelWidth = 130
  local baseMenuOptions = {
    {Label({width = labelWidth, label = "op_language"}), languageStepper},
    {Button({width = labelWidth, label = "op_general", onClick = function() switchMenu("generalMenu") end})},
    {Button({width = labelWidth, label = "op_graphics", onClick = function() switchMenu("graphicsMenu") end})},
    {Button({width = labelWidth, label = "op_audio", onClick = function() switchMenu("audioMenu") end})},
    {Button({width = labelWidth, label = "op_debug", onClick = function() switchMenu("debugMenu") end})},
    {Button({width = labelWidth, label = "op_about", onClick = function() switchMenu("aboutMenu") end})},
    {Button({width = labelWidth, label = "back", onClick = exitMenu})},
  }

  local saveReplaysPubliclyIndexMap = {["with my name"] = 1, ["anonymously"] = 2, ["not at all"] = 3}
  local publicReplayButtonGroup = ButtonGroup(
    {
      buttons = {
        Button({label = "op_replay_public_with_name"}),
        Button({label = "op_replay_public_anonymously"}),
        Button({label = "op_replay_public_no"}),
      },
      values = {"with my name", "anonymously", "not at all"},
      selectedIndex = saveReplaysPubliclyIndexMap[config.save_replays_publicly],
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move) 
        config.save_replays_publicly = value
      end
    }
  )

  local generalMenuOptions = {
    {Label({width = labelWidth, label = "op_countdown"}), createToggleButtonGroup("ready_countdown_1P")},
    {Label({width = labelWidth, label = "op_fps"}), createToggleButtonGroup("show_fps")},
    {Label({width = labelWidth, label = "op_ingame_infos"}), createToggleButtonGroup("show_ingame_infos")},
    {Label({width = labelWidth, label = "op_analytics"}), createToggleButtonGroup("enable_analytics")},
    {Label({width = labelWidth, label = "op_input_delay"}), createConfigSlider("input_repeat_delay", 0, 50)},
    {Label({width = labelWidth, label = "op_replay_public"}), publicReplayButtonGroup},
    {Button({width = labelWidth, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }

  local themeIndex
  local themeButtons = {}
  for k, v in ipairs(love.filesystem.getDirectoryItems("themes")) do
    if love.filesystem.getInfo("themes/" .. v) and v:sub(0, prefix_of_ignored_dirs:len()) ~= prefix_of_ignored_dirs then
      foundThemes[#foundThemes + 1] = v
      themeButtons[#themeButtons + 1] = Button({label = v, translate = false})
      if config.theme == v then
        themeIndex = #foundThemes
      end
    end
  end
  
  local themeButtonGroup = ButtonGroup(
    {
      buttons = themeButtons,
      values = foundThemes,
      selectedIndex = themeIndex,
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move) 
        config.theme = value
        stop_the_music()
        theme_init()
        backgroundImage = themes[config.theme].images.bg_main
        if themes[config.theme].musics["main"] then
          find_and_add_music(themes[config.theme].musics, "main")
        end
      end
    }
  )
  
  local graphicsMenuOptions = {
    {Label({width = labelWidth, label = "op_theme"}), themeButtonGroup},
    {Label({width = labelWidth, label = "op_portrait_darkness"}), createConfigSlider("portrait_darkness", 0, 100)},
    {Label({width = labelWidth, label = "op_popfx"}), createToggleButtonGroup("popfx")},
    {Label({width = labelWidth, label = "op_renderTelegraph"}), createToggleButtonGroup("renderTelegraph")},
    {Label({width = labelWidth, label = "op_renderAttacks"}), createToggleButtonGroup("renderAttacks")},
    {Button({width = labelWidth, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }
  
  local soundTestMenuOptions = {
    {Label({width = labelWidth, label = "character"})},
    {Label({width = labelWidth, label = "op_music_type"})},
    {Label({width = labelWidth, label = "op_music_play"})},
    {Label({width = labelWidth, label = "op_music_sfx"})},
    {Button({width = labelWidth, label = "back", onClick = function() switchMenu("audioMenu") end})},
  }
        
  local musicFrequencyIndexMap = {["stage"] = 1, ["often_stage"] = 2, ["either"] = 3, ["often_characters"] = 4, ["characters"] = 5}
  local musicFrequencyStepper = Stepper(
    {
      labels = {
        Label({label = "op_only_stage"}),
        Label({label = "op_often_stage"}),
        Label({label = "op_stage_characters"}),
        Label({label = "op_often_characters"}),
        Label({label = "op_only_characters"}),
      },
      values = {"stage", "often_stage", "either", "often_characters", "characters"},
      selectedIndex = musicFrequencyIndexMap[config.use_music_from],
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        config.use_music_from = value
      end
    }
  )
  
  local audioMenuOptions = {
    {Label({width = labelWidth, label = "op_vol"}), createConfigSlider("master_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = labelWidth, label = "op_vol_sfx"}), createConfigSlider("SFX_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = labelWidth, label = "op_vol_music"}), createConfigSlider("music_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = labelWidth, label = "op_use_music_from"}), musicFrequencyStepper},
    {Label({width = labelWidth, label = "op_music_delay"}), createToggleButtonGroup("danger_music_changeback_delay")},
    {Button({width = labelWidth, label = "mm_music_test", onClick = function() sceneManager:switchToScene("soundTest") end})},
    {Button({width = labelWidth, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }
  
  local debugMenuOptions = {
    {Label({width = labelWidth, label = "op_debug"}), createToggleButtonGroup("debug_mode")},
    {Label({width = labelWidth, label = "VS Frames Behind", translate = false}), createConfigSlider("debug_vsFramesBehind", -200, 200)},
    {Button({width = labelWidth, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }
  
  local aboutMenuOptions = {
    {Button({width = labelWidth, label = "op_about_themes", onClick = setupDrawThemesInfo})},
    {Button({width = labelWidth, label = "op_about_characters", onClick = function() setupInfo("characters") end})},
    {Button({width = labelWidth, label = "op_about_stages", onClick = function() setupInfo("stages") end})},
    {Button({width = labelWidth, label = "op_about_panels", onClick = function() setupInfo("panels") end})},
    {Button({width = labelWidth, label = "About Attack Files", translate = false, onClick = function() setupInfo("attackFiles") end})},
    {Button({width = labelWidth, label = "System Info", translate = false, onClick = setupSystemInfo})},
    {Button({width = labelWidth, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }
  
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  x = x - 70--- 400
  y = y + 10
  menus["baseMenu"] = Menu({menuItems = baseMenuOptions, x = x, y = y})
  menus["generalMenu"] = Menu({menuItems = generalMenuOptions, x = x, y = y})
  menus["graphicsMenu"] = Menu({menuItems = graphicsMenuOptions, x = x, y = y})
  menus["soundTestMenu"] = Menu({menuItems = soundTestMenuOptions, x = x, y = y})
  menus["audioMenu"] = Menu({menuItems = audioMenuOptions, x = x, y = y})
  menus["debugMenu"] = Menu({menuItems = debugMenuOptions, x = x, y = y})
  menus["aboutMenu"] = Menu({menuItems = aboutMenuOptions, x = x, y = y})

  for _, menu in pairs(menus) do
    menu:setVisibility(false)
  end
end

function optionsMenu:load()
  backgroundImage = themes[config.theme].images.bg_main
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  optionsState = "menus"
  menus[activeMenuName]:setVisibility(true)
end

function optionsMenu:drawBackground()
  backgroundImage:draw()
end

function optionsMenu:update()
  if optionsState == "menus" then
    menus[activeMenuName]:update()
    menus[activeMenuName]:draw()
  elseif optionsState == "info" then
    drawInfo(infoName)
  elseif optionsState == "system_info" then
    drawSystemInfo()
  end
end

function optionsMenu:unload()
  menus[activeMenuName]:setVisibility(false)
end

return optionsMenu
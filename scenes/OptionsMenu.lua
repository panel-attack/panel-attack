local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local LevelSlider = require("ui.LevelSlider")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local Stepper = require("ui.Stepper")
local inputManager = require("inputManager")
local save = require("save")
local consts = require("consts")
local GraphicsUtil = require("graphics_util")
local fileUtils = require("FileUtils")
local analytics = require("analytics")
local class = require("class")

--@module optionsMenu
-- Scene for the options menu
local OptionsMenu = class(
  function (self, sceneParams)
    self:load(sceneParams)
  end,
  Scene
)

OptionsMenu.name = "OptionsMenu"
sceneManager:addScene(OptionsMenu)

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

local LABEL_WIDTH = 130
local SCROLL_STEP = 14
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
local infoOffset = 0

local font = GraphicsUtil.getGlobalFont()

local function exitMenu()
  Menu.playValidationSfx()
  sceneManager:switchToScene("MainMenu")
end

local function updateMenuLanguage()
  for _, menu in pairs(menus) do
    menu:updateLabel()
  end
end

local function switchMenu(menuName)
  Menu.playValidationSfx()
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
        Menu.playMoveSfx()
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
  Menu.playValidationSfx()
  backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()

  if not love.filesystem.getInfo("themes/" .. prefix_of_ignored_dirs .. consts.DEFAULT_THEME_DIRECTORY) then
    --print("Hold on. Copying example folders to make this easier...\n This make take a few seconds.")
    gprint(loc("op_copy_files"), 280, 280)
    fileUtils.recursiveCopy("themes/" .. consts.DEFAULT_THEME_DIRECTORY, "themes/" .. prefix_of_ignored_dirs .. consts.DEFAULT_THEME_DIRECTORY)

    -- Android can't easily copy into the save dir, so do it for them to help.
    fileUtils.recursiveCopy("default_data/themes", "themes")
  end
  infoOffset = 0
  optionsState = "info"
  infoName = "themes"
  menus["aboutMenu"]:setVisibility(false)
end

local function setupInfo(infoType)
  Menu.playValidationSfx()
  backgroundImage = themes[config.theme].images.bg_readme
  reset_filters()
  infoOffset = 0
  optionsState = "info"
  infoName = infoType
  menus["aboutMenu"]:setVisibility(false)
end

local function setupSystemInfo()
  Menu.playValidationSfx()
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
  if inputManager.isDown["MenuEsc"] then
    Menu.playCancelSfx()
    backgroundImage = themes[config.theme].images.bg_main
    reset_filters()
    optionsState = "menus"
    menus["aboutMenu"]:setVisibility(true)
  end
end

local function drawInfo(text)
  gfx_q:push({love.graphics.draw, {aboutText[text], 15, 15, nil, nil, nil, nil, infoOffset}})
  if inputManager.isDown["MenuEsc"] then
    Menu.playCancelSfx()
    backgroundImage = themes[config.theme].images.bg_main
    reset_filters()
    optionsState = "menus"
    menus["aboutMenu"]:setVisibility(true)
  end
  if inputManager:isPressedWithRepeat("MenuUp", .25, 30/1000.0) then
    Menu.playMoveSfx()
    infoOffset = math.max(0, infoOffset - SCROLL_STEP)
  end
  if inputManager:isPressedWithRepeat("MenuDown", .25, 30/1000.0) then
    Menu.playMoveSfx()
    local textWidth, textHeight = aboutText[text]:getDimensions()
    if textHeight > canvas_height - 15 then
      infoOffset = math.min(infoOffset + SCROLL_STEP, textHeight - (canvas_height - 15))
    end
  end
end

function OptionsMenu:repositionMenus()
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  x = x - 20
  y = y + 10
  menus["baseMenu"].x = x
  menus["baseMenu"].y = y
  menus["generalMenu"].x = x
  menus["generalMenu"].y = y
  menus["graphicsMenu"].x = x
  menus["graphicsMenu"].y = y
  menus["soundTestMenu"].x = x
  menus["soundTestMenu"].y = y
  menus["audioMenu"].x = x
  menus["audioMenu"].y = y
  menus["debugMenu"].x = x
  menus["debugMenu"].y = y
  menus["aboutMenu"].x = x
  menus["aboutMenu"].y = y
end

function OptionsMenu:load()
  aboutText["themes"] = love.graphics.newText(GraphicsUtil.getGlobalFont(), save.read_txt_file("readme_themes.md"))
  aboutText["characters"] = love.graphics.newText(GraphicsUtil.getGlobalFont(), save.read_txt_file("readme_characters.md"))
  aboutText["stages"] = love.graphics.newText(GraphicsUtil.getGlobalFont(), save.read_txt_file("readme_stages.md"))
  aboutText["panels"] = love.graphics.newText(GraphicsUtil.getGlobalFont(), save.read_txt_file("readme_panels.txt"))
  aboutText["attackFiles"] = love.graphics.newText(GraphicsUtil.getGlobalFont(), save.read_txt_file("readme_training.txt"))
  aboutText["installingMods"] = love.graphics.newText(GraphicsUtil.getGlobalFont(), save.read_txt_file("readme_installmods.md"))

  local languageLabels = {}
  for k, v in ipairs(languageName) do
    local lang = config.language_code
    localization:set_language(v[1])
    languageLabels[#languageLabels + 1] = Label({
        label = v[2],
        translate = false,
        width = 70,
        height = 25})
    localization:set_language(lang)
  end
  
  local languageStepper = Stepper(
    {
      labels = languageLabels,
      values = languageName,
      selectedIndex = languageNumber,
      onChange = function(value)
        Menu.playMoveSfx()
        localization:set_language(value[1])
        updateMenuLanguage()
      end
    }
  )

  local baseMenuOptions = {
    {Label({width = LABEL_WIDTH, label = "op_language"}), languageStepper},
    {Button({width = LABEL_WIDTH, label = "op_general", onClick = function() switchMenu("generalMenu") end})},
    {Button({width = LABEL_WIDTH, label = "op_graphics", onClick = function() switchMenu("graphicsMenu") end})},
    {Button({width = LABEL_WIDTH, label = "op_audio", onClick = function() switchMenu("audioMenu") end})},
    {Button({width = LABEL_WIDTH, label = "op_debug", onClick = function() switchMenu("debugMenu") end})},
    {Button({width = LABEL_WIDTH, label = "op_about", onClick = function() switchMenu("aboutMenu") end})},
    {Button({width = LABEL_WIDTH, label = "back", onClick = exitMenu})},
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
        Menu.playMoveSfx() 
        config.save_replays_publicly = value
      end
    }
  )

  local generalMenuOptions = {
    {Label({width = LABEL_WIDTH, label = "op_countdown"}), createToggleButtonGroup("ready_countdown_1P")},
    {Label({width = LABEL_WIDTH, label = "op_fps"}), createToggleButtonGroup("show_fps")},
    {Label({width = LABEL_WIDTH, label = "op_ingame_infos"}), createToggleButtonGroup("show_ingame_infos")},
    {Label({width = LABEL_WIDTH, label = "op_analytics"}), createToggleButtonGroup("enable_analytics", function() analytics.init() end)},
    {Label({width = LABEL_WIDTH, label = "op_input_delay"}), createConfigSlider("input_repeat_delay", 0, 50)},
    {Label({width = LABEL_WIDTH, label = "op_replay_public"}), publicReplayButtonGroup},
    {Button({width = LABEL_WIDTH, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }

  local themeIndex
  local themeLabels = {}
  foundThemes = {}
  for i, v in ipairs(fileUtils.getFilteredDirectoryItems("themes")) do
    foundThemes[#foundThemes + 1] = v
    themeLabels[#themeLabels + 1] = Label({label = v, translate = false})
    if config.theme == v then
      themeIndex = #foundThemes
    end
  end
  local themeStepper = Stepper(
    {
      labels = themeLabels,
      values = foundThemes,
      selectedIndex = themeIndex,
      onChange = function(value) 
        Menu.playMoveSfx() 
        config.theme = value
        stop_the_music()
        theme_init()
        stages_init()
        characters_init()
        backgroundImage = themes[config.theme].images.bg_main
        if themes[config.theme].musics["main"] then
          find_and_add_music(themes[config.theme].musics, "main")
        end
        OptionsMenu:repositionMenus()
      end
    }
  )

  local graphicsMenuOptions = {
    {Label({width = LABEL_WIDTH, label = "op_theme"}), themeStepper},
    {Label({width = LABEL_WIDTH, label = "op_portrait_darkness"}), createConfigSlider("portrait_darkness", 0, 100)},
    {Label({width = LABEL_WIDTH, label = "op_popfx"}), createToggleButtonGroup("popfx")},
    {Label({width = LABEL_WIDTH, label = "op_renderTelegraph"}), createToggleButtonGroup("renderTelegraph")},
    {Label({width = LABEL_WIDTH, label = "op_renderAttacks"}), createToggleButtonGroup("renderAttacks")},
    {Button({width = LABEL_WIDTH, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }

  local soundTestMenuOptions = {
    {Label({width = LABEL_WIDTH, label = "character"})},
    {Label({width = LABEL_WIDTH, label = "op_music_type"})},
    {Label({width = LABEL_WIDTH, label = "op_music_play"})},
    {Label({width = LABEL_WIDTH, label = "op_music_sfx"})},
    {Button({width = LABEL_WIDTH, label = "back", onClick = function() switchMenu("audioMenu") end})},
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
        Menu.playMoveSfx()
        config.use_music_from = value
      end
    }
  )

  local audioMenuOptions = {
    {Label({width = LABEL_WIDTH, label = "op_vol"}), createConfigSlider("master_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = LABEL_WIDTH, label = "op_vol_sfx"}), createConfigSlider("SFX_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = LABEL_WIDTH, label = "op_vol_music"}), createConfigSlider("music_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = LABEL_WIDTH, label = "op_use_music_from"}), musicFrequencyStepper},
    {Label({width = LABEL_WIDTH, label = "op_music_delay"}), createToggleButtonGroup("danger_music_changeback_delay")},
    {Button({width = LABEL_WIDTH, label = "mm_music_test", onClick = function() sceneManager:switchToScene("SoundTest") end})},
    {Button({width = LABEL_WIDTH, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }
  
  local debugMenuOptions = {
    {Label({width = LABEL_WIDTH, label = "op_debug"}), createToggleButtonGroup("debug_mode")},
    {Label({width = LABEL_WIDTH, label = "VS Frames Behind", translate = false}), createConfigSlider("debug_vsFramesBehind", -200, 200)},
    {Label({width = LABEL_WIDTH, label = "Show Debug Servers", translate = false}), createToggleButtonGroup("debugShowServers")},
    {Button({width = LABEL_WIDTH, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }
  
  local aboutMenuOptions = {
    {Button({width = LABEL_WIDTH, label = "op_about_themes", onClick = setupDrawThemesInfo})},
    {Button({width = LABEL_WIDTH, label = "op_about_characters", onClick = function() setupInfo("characters") end})},
    {Button({width = LABEL_WIDTH, label = "op_about_stages", onClick = function() setupInfo("stages") end})},
    {Button({width = LABEL_WIDTH, label = "op_about_panels", onClick = function() setupInfo("panels") end})},
    {Button({width = LABEL_WIDTH, label = "About Attack Files", translate = false, onClick = function() setupInfo("attackFiles") end})},
    {Button({width = LABEL_WIDTH, label = "Installing Mods", translate = false, onClick = function() setupInfo("installingMods") end})},
    {Button({width = LABEL_WIDTH, label = "System Info", translate = false, onClick = setupSystemInfo})},
    {Button({width = LABEL_WIDTH, label = "back", onClick = function() switchMenu("baseMenu") end})},
  }
  
  menus["baseMenu"] = Menu({menuItems = baseMenuOptions, maxHeight = themes[config.theme].main_menu_max_height})
  menus["generalMenu"] = Menu({menuItems = generalMenuOptions, maxHeight = themes[config.theme].main_menu_max_height})
  menus["graphicsMenu"] = Menu({menuItems = graphicsMenuOptions, maxHeight = themes[config.theme].main_menu_max_height})
  menus["soundTestMenu"] = Menu({menuItems = soundTestMenuOptions, maxHeight = themes[config.theme].main_menu_max_height})
  menus["audioMenu"] = Menu({menuItems = audioMenuOptions, maxHeight = themes[config.theme].main_menu_max_height})
  menus["debugMenu"] = Menu({menuItems = debugMenuOptions, maxHeight = themes[config.theme].main_menu_max_height})
  menus["aboutMenu"] = Menu({menuItems = aboutMenuOptions, maxHeight = themes[config.theme].main_menu_max_height})

  for _, menu in pairs(menus) do
    menu:setVisibility(false)
  end
  
  self:repositionMenus()
  
  backgroundImage = themes[config.theme].images.bg_main
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  optionsState = "menus"
  menus[activeMenuName]:setVisibility(true)
end

function OptionsMenu:drawBackground()
  backgroundImage:draw()
end

function OptionsMenu:update(dt)
  backgroundImage:update(dt)
  if optionsState == "menus" then
    menus[activeMenuName]:update()
    menus[activeMenuName]:draw()
  elseif optionsState == "info" then
    drawInfo(infoName)
  elseif optionsState == "system_info" then
    drawSystemInfo()
  end
end

function OptionsMenu:unload()
  menus[activeMenuName]:setVisibility(false)
end

return OptionsMenu
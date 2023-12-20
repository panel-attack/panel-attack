local Scene = require("scenes.Scene")
local TextButton = require("ui.TextButton")
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
local tableUtils = require("tableUtils")
local utf8 = require("utf8")
local SoundTest = require("scenes.SoundTest")
local SetUserIdMenu = require("scenes.SetUserIdMenu")

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

local MENU_WIDTH = 130
local ITEM_HEIGHT = 30
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
  modifyUserIdMenu = nil
}

local foundThemes = {}
local aboutText = {}
local infoString
local infoOffset = 0

local function exitMenu()
  Menu.playValidationSfx()
  sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
end

local function updateMenuLanguage()
  for _, menu in pairs(menus) do
    menu:refreshLocalization()
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
        TextButton({width = 60, label = Label({text = "op_off"})}),
        TextButton({width = 60, label = Label({text = "op_on"})}),
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
  infoOffset = 0
  optionsState = "info"
  infoName = infoType
  menus["aboutMenu"]:setVisibility(false)
end

local function setupSystemInfo()
  Menu.playValidationSfx()
  backgroundImage = themes[config.theme].images.bg_readme
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
    optionsState = "menus"
    menus["aboutMenu"]:setVisibility(true)
  end
end

local function drawInfo(text)
  love.graphics.draw(aboutText[text], 15, 15, nil, nil, nil, nil, infoOffset)
  if inputManager.isDown["MenuEsc"] then
    Menu.playCancelSfx()
    backgroundImage = themes[config.theme].images.bg_main
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
  menus["modifyUserIdMenu"].x = x
  menus["modifyUserIdMenu"].y = y
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
        text = v[2],
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
    {Label({width = MENU_WIDTH, text = "op_language"}), languageStepper},
    {TextButton({width = MENU_WIDTH, label = Label({text = "op_general"}), onClick = function() switchMenu("generalMenu") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "op_graphics"}), onClick = function() switchMenu("graphicsMenu") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "op_audio"}), onClick = function() switchMenu("audioMenu") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "op_debug"}), onClick = function() switchMenu("debugMenu") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "op_about"}), onClick = function() switchMenu("aboutMenu") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "Modify User ID", translate = false}), onClick = function() switchMenu("modifyUserIdMenu") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "back"}), onClick = exitMenu})},
  }

  local saveReplaysPubliclyIndexMap = {["with my name"] = 1, ["anonymously"] = 2, ["not at all"] = 3}
  local publicReplayButtonGroup = ButtonGroup(
    {
      buttons = {
        TextButton({label = Label({text = "op_replay_public_with_name"})}),
        TextButton({label = Label({text = "op_replay_public_anonymously"})}),
        TextButton({label = Label({text = "op_replay_public_no"})}),
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
    {Label({width = MENU_WIDTH, text = "op_countdown"}), createToggleButtonGroup("ready_countdown_1P")},
    {Label({width = MENU_WIDTH, text = "op_fps"}), createToggleButtonGroup("show_fps")},
    {Label({width = MENU_WIDTH, text = "op_ingame_infos"}), createToggleButtonGroup("show_ingame_infos")},
    {Label({width = MENU_WIDTH, text = "op_analytics"}), createToggleButtonGroup("enable_analytics", function() analytics.init() end)},
    {Label({width = MENU_WIDTH, text = "op_input_delay"}), createConfigSlider("input_repeat_delay", 0, 50)},
    {Label({width = MENU_WIDTH, text = "op_replay_public"}), publicReplayButtonGroup},
    {TextButton({width = MENU_WIDTH, label = Label({text = "back"}), onClick = function() switchMenu("baseMenu") end})},
  }

  local themeIndex
  local themeLabels = {}
  foundThemes = {}
  for i, v in ipairs(fileUtils.getFilteredDirectoryItems("themes")) do
    foundThemes[#foundThemes + 1] = v
    themeLabels[#themeLabels + 1] = Label({text = v, translate = false})
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
        CharacterLoader.initCharacters()
        backgroundImage = themes[config.theme].images.bg_main
        if themes[config.theme].musics["main"] then
          find_and_add_music(themes[config.theme].musics, "main")
        end
        OptionsMenu:repositionMenus()
      end
    }
  )

  local function scaleSettingsChanged()
    GAME.showGameScaleUntil = GAME.timer + 1000
    local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local previousXScale = GAME.canvasXScale
    GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
    if previousXScale ~= GAME.canvasXScale then
      GAME:refreshCanvasAndImagesForNewScale()
    end
  end

  local fixedScaleData = {}
  for _, value in ipairs(GAME.availableScales) do
    fixedScaleData[#fixedScaleData+1] = {}
    fixedScaleData[#fixedScaleData].value = value
    fixedScaleData[#fixedScaleData].label = value
  end
  for index, value in ipairs(fixedScaleData) do
    value.index = index
  end
  local function updateFixedScale(fixedScale)
    assert(config.gameScaleType == "fixed")
    config.gameScaleFixedValue = fixedScale
    scaleSettingsChanged()
  end

  local fixedScaleButtonGroup = ButtonGroup(
    {
      buttons = tableUtils.map(fixedScaleData,
        function(scaleType)
          return TextButton({label = Label({text = scaleType.label}), translate = false})
        end
      ),
      values = tableUtils.map(fixedScaleData,
        function(scaleType)
          return scaleType.value
        end
      ),
      selectedIndex = tableUtils.first(fixedScaleData, function(scaleType) return scaleType.value == config.gameScaleFixedValue end).index or 1,
      onChange = function(value) 
        Menu.playMoveSfx() 
        updateFixedScale(value)
      end
    }
  )

  local fixedScaleGroup = nil
  function updateFixedButtonGroupVisibility()
    local graphicsMenu = menus["graphicsMenu"]
    if config.gameScaleType ~= "fixed" then
      graphicsMenu:removeMenuItem(fixedScaleGroup[1].id)
    else
      if graphicsMenu:containsMenuItemID(fixedScaleGroup[1].id) == false then 
        graphicsMenu:addMenuItem(3,fixedScaleGroup)
      end
    end
  end

  local scaleTypeData = {{value = "auto", text = "op_scale_auto"},
                             {value = "fit", text = "op_scale_fit"},
                             {value = "fixed", text = "op_scale_fixed"}}
  for index, value in ipairs(scaleTypeData) do
    value.index = index
  end

  local scaleButtonGroup = ButtonGroup(
    {
      buttons = tableUtils.map(scaleTypeData,
        function(scaleType)
          return TextButton({label = Label({text = scaleType.text})})
        end
      ),
      values = tableUtils.map(scaleTypeData,
        function(scaleType)
          return scaleType.value
        end
      ),
      selectedIndex = tableUtils.first(scaleTypeData, function(scaleType) return scaleType.value == config.gameScaleType end).index,
      onChange = function(value) 
        Menu.playMoveSfx() 
        config.gameScaleType = value
        updateFixedButtonGroupVisibility()
        scaleSettingsChanged()
      end
    }
  )

  fixedScaleGroup = {Label({width = MENU_WIDTH, text = "op_scale_fixed_value"}), fixedScaleButtonGroup}
  graphicsMenuOptions = {
    {Label({width = MENU_WIDTH, text = "op_theme"}), themeStepper},
    {Label({width = MENU_WIDTH, text = "op_scale"}), scaleButtonGroup},
    fixedScaleGroup,
    {Label({width = MENU_WIDTH, text = "op_portrait_darkness"}), createConfigSlider("portrait_darkness", 0, 100)},
    {Label({width = MENU_WIDTH, text = "op_popfx"}), createToggleButtonGroup("popfx")},
    {Label({width = MENU_WIDTH, text = "op_renderTelegraph"}), createToggleButtonGroup("renderTelegraph")},
    {Label({width = MENU_WIDTH, text = "op_renderAttacks"}), createToggleButtonGroup("renderAttacks")},
    {TextButton({width = MENU_WIDTH, label = Label({text = "back"}), onClick = function()
      GAME.showGameScaleUntil = GAME.timer
      switchMenu("baseMenu")
    end})},
  }

  local soundTestMenuOptions = {
    {Label({width = MENU_WIDTH, text = "character"})},
    {Label({width = MENU_WIDTH, text = "op_music_type"})},
    {Label({width = MENU_WIDTH, text = "op_music_play"})},
    {Label({width = MENU_WIDTH, text = "op_music_sfx"})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "back"}), onClick = function() switchMenu("audioMenu") end})},
  }

  local musicFrequencyIndexMap = {["stage"] = 1, ["often_stage"] = 2, ["either"] = 3, ["often_characters"] = 4, ["characters"] = 5}
  local musicFrequencyStepper = Stepper(
    {
      labels = {
        Label({text = "op_only_stage"}),
        Label({text = "op_often_stage"}),
        Label({text = "op_stage_characters"}),
        Label({text = "op_often_characters"}),
        Label({text = "op_only_characters"}),
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
    {Label({width = MENU_WIDTH, text = "op_vol"}), createConfigSlider("master_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = MENU_WIDTH, text = "op_vol_sfx"}), createConfigSlider("SFX_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = MENU_WIDTH, text = "op_vol_music"}), createConfigSlider("music_volume", 0, 100, function() apply_config_volume() end)},
    {Label({width = MENU_WIDTH, text = "op_use_music_from"}), musicFrequencyStepper},
    {Label({width = MENU_WIDTH, text = "op_music_delay"}), createToggleButtonGroup("danger_music_changeback_delay")},
    {TextButton({width = MENU_WIDTH, label = Label({text = "mm_music_test"}), onClick = function() sceneManager:switchToScene(sceneManager:createScene("SoundTest")) end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "back"}), onClick = function() switchMenu("baseMenu") end})},
  }
  
  local debugMenuOptions = {
    {Label({width = MENU_WIDTH, text = "op_debug"}), createToggleButtonGroup("debug_mode")},
    {Label({width = MENU_WIDTH, text = "VS Frames Behind", translate = false}), createConfigSlider("debug_vsFramesBehind", -200, 200)},
    {Label({width = MENU_WIDTH, text = "Show Debug Servers", translate = false}), createToggleButtonGroup("debugShowServers")},
    {Label({width = MENU_WIDTH, text = "Show Design Helper", translate = false}), createToggleButtonGroup("debugShowDesignHelper")},
    {TextButton({width = MENU_WIDTH, label = Label({text = "back"}), onClick = function() switchMenu("baseMenu") end})},
  }
  
  local aboutMenuOptions = {
    {TextButton({width = MENU_WIDTH, label = Label({text = "op_about_themes"}), onClick = setupDrawThemesInfo})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "op_about_characters"}), onClick = function() setupInfo("characters") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "op_about_stages"}), onClick = function() setupInfo("stages") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "op_about_panels"}), onClick = function() setupInfo("panels") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "About Attack Files"}), translate = false, onClick = function() setupInfo("attackFiles") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "Installing Mods"}), translate = false, onClick = function() setupInfo("installingMods") end})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "System Info"}), translate = false, onClick = setupSystemInfo})},
    {TextButton({width = MENU_WIDTH, label = Label({text = "back"}), onClick = function() switchMenu("baseMenu") end})},
  }

  local modifyUserIdOptions = {}
  local userIDDirectories = fileUtils.getFilteredDirectoryItems("servers")
  for i = 1, #userIDDirectories do
    modifyUserIdOptions[#modifyUserIdOptions+1] = {TextButton({width = MENU_WIDTH, label = Label({text = userIDDirectories[i], translate = false}), onClick = function() sceneManager:switchToScene(SetUserIdMenu({serverIp = userIDDirectories[i]})) end})}
  end
  modifyUserIdOptions[#modifyUserIdOptions + 1] = {TextButton({width = MENU_WIDTH, label = Label({text = "back"}), onClick = function() switchMenu("baseMenu") end})}

  menus["baseMenu"] = Menu({menuItems = baseMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  menus["generalMenu"] = Menu({menuItems = generalMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  menus["graphicsMenu"] = Menu({menuItems = graphicsMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  menus["soundTestMenu"] = Menu({menuItems = soundTestMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  menus["audioMenu"] = Menu({menuItems = audioMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  menus["debugMenu"] = Menu({menuItems = debugMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  menus["aboutMenu"] = Menu({menuItems = aboutMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  menus["modifyUserIdMenu"] = Menu({menuItems = modifyUserIdOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})

  for _, menu in pairs(menus) do
    menu:setVisibility(false)
  end
  updateFixedButtonGroupVisibility()
  
  self:repositionMenus()
  
  backgroundImage = themes[config.theme].images.bg_main
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  optionsState = "menus"
  menus[activeMenuName]:setVisibility(true)
end

function OptionsMenu:update(dt)
  backgroundImage:update(dt)
  if optionsState == "menus" then
    menus[activeMenuName]:update()
  end
end

function OptionsMenu:draw()
  backgroundImage:draw()

  if optionsState == "menus" then
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
local Scene = require("scenes.Scene")
local TextButton = require("ui.TextButton")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local Stepper = require("ui.Stepper")
local inputManager = require("inputManager")
local save = require("save")
local consts = require("consts")
local fileUtils = require("FileUtils")
local analytics = require("analytics")
local class = require("class")
local tableUtils = require("tableUtils")
local SoundTest = require("scenes.SoundTest")
local SetUserIdMenu = require("scenes.SetUserIdMenu")
local UiElement = require("ui.UIElement")

-- @module optionsMenu
-- Scene for the options menu
local OptionsMenu = class(function(self, sceneParams)
  self.activeMenuName = "baseMenu"
  self:load(sceneParams)
end, Scene)

OptionsMenu.name = "OptionsMenu"
sceneManager:addScene(OptionsMenu)

local languageNumber
local languageName = {}
for k, v in ipairs(localization:get_list_codes()) do
  languageName[#languageName + 1] = {v, localization.data[v]["LANG"]}
  if localization:get_language() == v then
    languageNumber = k
  end
end

local MENU_WIDTH = 130
local ITEM_HEIGHT = 30
local SCROLL_STEP = 14

function OptionsMenu:loadScreens()
  local menus = {}

  menus.baseMenu = self:loadBaseMenu()
  menus.generalMenu = self:loadGeneralMenu()
  menus.graphicsMenu = self:loadGraphicsMenu()
  menus.soundTestMenu = self:loadSoundTestMenu()
  menus.audioMenu = self:loadSoundMenu()
  menus.debugMenu = self:loadDebugMenu()
  menus.aboutMenu = self:loadAboutMenu()
  menus.modifyUserIdMenu = self:loadModifyUserIdMenu()
  menus.systemInfo = self:loadInfoScreen(self:getSystemInfo())
  menus.aboutThemes = self:loadInfoScreen(save.read_txt_file("readme_themes.md"))
  menus.aboutCharacters = self:loadInfoScreen(save.read_txt_file("readme_characters.md"))
  menus.aboutStages = self:loadInfoScreen(save.read_txt_file("readme_stages.md"))
  menus.aboutPanels = self:loadInfoScreen(save.read_txt_file("readme_panels.md"))
  menus.aboutAttackFiles = self:loadInfoScreen(save.read_txt_file("readme_training.md"))
  menus.installingMods = self:loadInfoScreen(save.read_txt_file("readme_installmods.md"))

  return menus
end

local foundThemes = {}

function OptionsMenu.exit()
  Menu.playValidationSfx()
  sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
end

function OptionsMenu:updateMenuLanguage()
  for _, menu in pairs(self.menus) do
    menu:refreshLocalization()
  end
end

function OptionsMenu:switchToScreen(screenName)
  Menu.playValidationSfx()
  self.menus[self.activeMenuName]:detach()
  self.uiRoot:addChild(self.menus[screenName])
  self.activeMenuName = screenName
end

local function createToggleButtonGroup(configField, onChangeFn)
  return ButtonGroup({
    buttons = {TextButton({width = 60, label = Label({text = "op_off"})}), TextButton({width = 60, label = Label({text = "op_on"})})},
    values = {false, true},
    selectedIndex = config[configField] and 2 or 1,
    onChange = function(value)
      Menu.playMoveSfx()
      config[configField] = value
      if onChangeFn then
        onChangeFn()
      end
    end
  })
end

local function createConfigSlider(configField, min, max, onValueChangeFn)
  return Slider({
    min = min,
    max = max,
    value = config[configField] or 0,
    tickLength = math.ceil(100 / max),
    onValueChange = function(slider)
      config[configField] = slider.value
      if onValueChangeFn then
        onValueChangeFn(slider)
      end
    end
  })
end

function OptionsMenu:getSystemInfo()
  Menu.playValidationSfx()
  self.backgroundImage = themes[config.theme].images.bg_readme
  local rendererName, rendererVersion, graphicsCardVendor, graphicsCardName = love.graphics.getRendererInfo()
  local sysInfo = {}
  sysInfo[#sysInfo + 1] = {name = "Operating System", value = love.system.getOS()}
  sysInfo[#sysInfo + 1] = {name = "Renderer", value = rendererName .. " " .. rendererVersion}
  sysInfo[#sysInfo + 1] = {name = "Graphics Card", value = graphicsCardName}
  sysInfo[#sysInfo + 1] = {name = "LOVE Version", value = GAME:loveVersionString()}
  sysInfo[#sysInfo + 1] = {name = "Panel Attack Engine Version", value = VERSION}
  sysInfo[#sysInfo + 1] = {name = "Panel Attack Release Version", value = GAME_UPDATER_GAME_VERSION}
  sysInfo[#sysInfo + 1] = {name = "Save Data Directory Path", value = love.filesystem.getSaveDirectory()}
  sysInfo[#sysInfo + 1] = {name = "Characters [Enabled/Total]", value = #characters_ids_for_current_theme .. "/" .. #characters_ids}
  sysInfo[#sysInfo + 1] = {name = "Stages [Enabled/Total]", value = #stages_ids_for_current_theme .. "/" .. #stages_ids}
  sysInfo[#sysInfo + 1] = {name = "Total Panel Sets", value = #panels_ids}
  sysInfo[#sysInfo + 1] = {name = "Total Themes", value = #foundThemes}

  local infoString = ""
  for index, info in ipairs(sysInfo) do
    infoString = infoString .. info.name .. ": " .. (info.value or "Unknown") .. "\n"
  end
  return infoString
end

function OptionsMenu:loadInfoScreen(text)
  local infoScreen = UiElement({hFill = true, vFill = true})
  local label = Label({text = text, translate = false, vAlign = "top", x = 6, y = 6})
  infoScreen.update = function()
    if inputManager.isDown["MenuEsc"] then
      Menu.playCancelSfx()
      self.backgroundImage = themes[config.theme].images.bg_main
      self:switchToScreen("aboutMenu")
    end
    if inputManager:isPressedWithRepeat("MenuUp", .25, 30 / 1000.0) then
      Menu.playMoveSfx()
      if label.height > consts.CANVAS_HEIGHT - 15 then
        label.y = math.max(0, label.y + SCROLL_STEP)
      end
    end
    if inputManager:isPressedWithRepeat("MenuDown", .25, 30 / 1000.0) then
      Menu.playMoveSfx()
      if label.height > consts.CANVAS_HEIGHT - 15 then
        label.y = math.min(label.y - SCROLL_STEP, label.height - (consts.CANVAS_HEIGHT - 15))
      end
    end
  end

  infoScreen:addChild(label)
  return infoScreen
end

function OptionsMenu:repositionMenus()
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  x = x - 20
  y = y + 10
  self.menus["baseMenu"].x = x
  self.menus["baseMenu"].y = y
  self.menus["generalMenu"].x = x
  self.menus["generalMenu"].y = y
  self.menus["graphicsMenu"].x = x
  self.menus["graphicsMenu"].y = y
  self.menus["soundTestMenu"].x = x
  self.menus["soundTestMenu"].y = y
  self.menus["audioMenu"].x = x
  self.menus["audioMenu"].y = y
  self.menus["debugMenu"].x = x
  self.menus["debugMenu"].y = y
  self.menus["aboutMenu"].x = x
  self.menus["aboutMenu"].y = y
  self.menus["modifyUserIdMenu"].x = x
  self.menus["modifyUserIdMenu"].y = y
end

function OptionsMenu:loadBaseMenu()
  local languageLabels = {}
  for k, v in ipairs(languageName) do
    local lang = config.language_code
    localization:set_language(v[1])
    languageLabels[#languageLabels + 1] = Label({text = v[2], translate = false, width = 70, height = 25})
    localization:set_language(lang)
  end

  local languageStepper = Stepper({
    labels = languageLabels,
    values = languageName,
    selectedIndex = languageNumber,
    onChange = function(value)
      Menu.playMoveSfx()
      localization:set_language(value[1])
      self:updateMenuLanguage()
    end
  })

  local baseMenuOptions = {
    {Label({width = MENU_WIDTH, text = "op_language"}), languageStepper}, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "op_general"}),
        onClick = function()
          self:switchToScreen("generalMenu")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "op_graphics"}),
        onClick = function()
          self:switchToScreen("graphicsMenu")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "op_audio"}),
        onClick = function()
          self:switchToScreen("audioMenu")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "op_debug"}),
        onClick = function()
          self:switchToScreen("debugMenu")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "op_about"}),
        onClick = function()
          self:switchToScreen("aboutMenu")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "Modify User ID", translate = false}),
        onClick = function()
          self:switchToScreen("modifyUserIdMenu")
        end
      })
    }, {TextButton({width = MENU_WIDTH, label = Label({text = "back"}), onClick = self.exit})}
  }

  local menu = Menu({menuItems = baseMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  return menu
end

function OptionsMenu:loadGeneralMenu()
  local saveReplaysPubliclyIndexMap = {["with my name"] = 1, ["anonymously"] = 2, ["not at all"] = 3}
  local publicReplayButtonGroup = ButtonGroup({
    buttons = {
      TextButton({label = Label({text = "op_replay_public_with_name"})}),
      TextButton({label = Label({text = "op_replay_public_anonymously"})}), TextButton({label = Label({text = "op_replay_public_no"})})
    },
    values = {"with my name", "anonymously", "not at all"},
    selectedIndex = saveReplaysPubliclyIndexMap[config.save_replays_publicly],
    onChange = function(value)
      Menu.playMoveSfx()
      config.save_replays_publicly = value
    end
  })

  local generalMenuOptions = {
    {Label({width = MENU_WIDTH, text = "op_countdown"}), createToggleButtonGroup("ready_countdown_1P")},
    {Label({width = MENU_WIDTH, text = "op_fps"}), createToggleButtonGroup("show_fps")},
    {Label({width = MENU_WIDTH, text = "op_ingame_infos"}), createToggleButtonGroup("show_ingame_infos")}, {
      Label({width = MENU_WIDTH, text = "op_analytics"}), createToggleButtonGroup("enable_analytics", function()
        analytics.init()
      end)
    }, {Label({width = MENU_WIDTH, text = "op_input_delay"}), createConfigSlider("input_repeat_delay", 0, 50)},
    {Label({width = MENU_WIDTH, text = "op_replay_public"}), publicReplayButtonGroup}, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "back"}),
        onClick = function()
          self:switchToScreen("baseMenu")
        end
      })
    }
  }

  local menu = Menu({menuItems = generalMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  return menu
end

function OptionsMenu:loadGraphicsMenu()
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
  local themeStepper = Stepper({
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
      self.backgroundImage = themes[config.theme].images.bg_main
      if themes[config.theme].musics["main"] then
        find_and_add_music(themes[config.theme].musics, "main")
      end
      OptionsMenu:repositionMenus()
    end
  })

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
    fixedScaleData[#fixedScaleData + 1] = {}
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

  local fixedScaleButtonGroup = ButtonGroup({
    buttons = tableUtils.map(fixedScaleData, function(scaleType)
      return TextButton({label = Label({text = scaleType.label}), translate = false})
    end),
    values = tableUtils.map(fixedScaleData, function(scaleType)
      return scaleType.value
    end),
    selectedIndex = tableUtils.first(fixedScaleData, function(scaleType)
      return scaleType.value == config.gameScaleFixedValue
    end).index or 1,
    onChange = function(value)
      Menu.playMoveSfx()
      updateFixedScale(value)
    end
  })

  local fixedScaleGroup = {Label({width = MENU_WIDTH, text = "op_scale_fixed_value"}), fixedScaleButtonGroup}
  local function updateFixedButtonGroupVisibility()
    if config.gameScaleType ~= "fixed" then
      self.menus.graphicsMenu:removeMenuItem(fixedScaleGroup[1].id)
    else
      if self.menus.graphicsMenu:containsMenuItemID(fixedScaleGroup[1].id) == false then
        self.menus.graphicsMenu:addMenuItem(3, fixedScaleGroup)
      end
    end
  end

  local scaleTypeData = {
    {value = "auto", text = "op_scale_auto"}, {value = "fit", text = "op_scale_fit"}, {value = "fixed", text = "op_scale_fixed"}
  }
  for index, value in ipairs(scaleTypeData) do
    value.index = index
  end

  local scaleButtonGroup = ButtonGroup({
    buttons = tableUtils.map(scaleTypeData, function(scaleType)
      return TextButton({label = Label({text = scaleType.text})})
    end),
    values = tableUtils.map(scaleTypeData, function(scaleType)
      return scaleType.value
    end),
    selectedIndex = tableUtils.first(scaleTypeData, function(scaleType)
      return scaleType.value == config.gameScaleType
    end).index,
    onChange = function(value)
      Menu.playMoveSfx()
      config.gameScaleType = value
      updateFixedButtonGroupVisibility()
      scaleSettingsChanged()
    end
  })

  local graphicsMenuOptions = {
    {Label({width = MENU_WIDTH, text = "op_theme"}), themeStepper}, {Label({width = MENU_WIDTH, text = "op_scale"}), scaleButtonGroup},
    {Label({width = MENU_WIDTH, text = "op_portrait_darkness"}), createConfigSlider("portrait_darkness", 0, 100)},
    {Label({width = MENU_WIDTH, text = "op_popfx"}), createToggleButtonGroup("popfx")},
    {Label({width = MENU_WIDTH, text = "op_renderTelegraph"}), createToggleButtonGroup("renderTelegraph")},
    {Label({width = MENU_WIDTH, text = "op_renderAttacks"}), createToggleButtonGroup("renderAttacks")}, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "back"}),
        onClick = function()
          GAME.showGameScaleUntil = GAME.timer
          self:switchToScreen("baseMenu")
        end
      })
    }
  }

  local menu = Menu({menuItems = graphicsMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  if config.gameScaleType == "fixed" then
    menu:addMenuItem(3, fixedScaleGroup)
  end
  return menu
end

function OptionsMenu:loadSoundTestMenu()
  local soundTestMenuOptions = {
    {Label({width = MENU_WIDTH, text = "character"})}, {Label({width = MENU_WIDTH, text = "op_music_type"})},
    {Label({width = MENU_WIDTH, text = "op_music_play"})}, {Label({width = MENU_WIDTH, text = "op_music_sfx"})}, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "back"}),
        onClick = function()
          self:switchToScreen("audioMenu")
        end
      })
    }
  }

  return Menu({menuItems = soundTestMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
end

function OptionsMenu:loadSoundMenu()
  local musicFrequencyIndexMap = {["stage"] = 1, ["often_stage"] = 2, ["either"] = 3, ["often_characters"] = 4, ["characters"] = 5}
  local musicFrequencyStepper = Stepper({
    labels = {
      Label({text = "op_only_stage"}), Label({text = "op_often_stage"}), Label({text = "op_stage_characters"}),
      Label({text = "op_often_characters"}), Label({text = "op_only_characters"})
    },
    values = {"stage", "often_stage", "either", "often_characters", "characters"},
    selectedIndex = musicFrequencyIndexMap[config.use_music_from],
    onChange = function(value)
      Menu.playMoveSfx()
      config.use_music_from = value
    end
  })

  local audioMenuOptions = {
    {
      Label({width = MENU_WIDTH, text = "op_vol"}), createConfigSlider("master_volume", 0, 100, function()
        apply_config_volume()
      end)
    }, {
      Label({width = MENU_WIDTH, text = "op_vol_sfx"}), createConfigSlider("SFX_volume", 0, 100, function()
        apply_config_volume()
      end)
    }, {
      Label({width = MENU_WIDTH, text = "op_vol_music"}), createConfigSlider("music_volume", 0, 100, function()
        apply_config_volume()
      end)
    }, {Label({width = MENU_WIDTH, text = "op_use_music_from"}), musicFrequencyStepper},
    {Label({width = MENU_WIDTH, text = "op_music_delay"}), createToggleButtonGroup("danger_music_changeback_delay")}, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "mm_music_test"}),
        onClick = function()
          sceneManager:switchToScene(SoundTest())
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "back"}),
        onClick = function()
          self:switchToScreen("baseMenu")
        end
      })
    }
  }

  local menu = Menu({menuItems = audioMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  return menu
end

function OptionsMenu:loadDebugMenu()
  local debugMenuOptions = {
    {Label({width = MENU_WIDTH, text = "op_debug"}), createToggleButtonGroup("debug_mode")},
    {Label({width = MENU_WIDTH, text = "VS Frames Behind", translate = false}), createConfigSlider("debug_vsFramesBehind", 0, 200)},
    {Label({width = MENU_WIDTH, text = "Show Debug Servers", translate = false}), createToggleButtonGroup("debugShowServers")},
    {Label({width = MENU_WIDTH, text = "Show Design Helper", translate = false}), createToggleButtonGroup("debugShowDesignHelper")}, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "back"}),
        onClick = function()
          self:switchToScreen("baseMenu")
        end
      })
    }
  }

  return Menu({menuItems = debugMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
end

function OptionsMenu:loadAboutMenu()
  local aboutMenuOptions = {
    {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "op_about_themes"}),
        onClick = function()
          self:switchToScreen("aboutThemes")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "op_about_characters"}),
        onClick = function()
          self:switchToScreen("aboutCharacters")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "op_about_stages"}),
        onClick = function()
          self:switchToScreen("aboutStages")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "op_about_panels"}),
        onClick = function()
          self:switchToScreen("aboutPanels")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "About Attack Files"}),
        translate = false,
        onClick = function()
          self:switchToScreen("aboutAttackFiles")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "Installing Mods"}),
        translate = false,
        onClick = function()
          self:switchToScreen("installingMods")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "System Info"}),
        translate = false,
        onClick = function()
          self:switchToScreen("systemInfo")
        end
      })
    }, {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = "back"}),
        onClick = function()
          self:switchToScreen("baseMenu")
        end
      })
    }
  }

  local menu = Menu({menuItems = aboutMenuOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
  return menu
end

function OptionsMenu:loadModifyUserIdMenu()
  local modifyUserIdOptions = {}
  local userIDDirectories = fileUtils.getFilteredDirectoryItems("servers")
  for i = 1, #userIDDirectories do
    modifyUserIdOptions[#modifyUserIdOptions + 1] = {
      TextButton({
        width = MENU_WIDTH,
        label = Label({text = userIDDirectories[i], translate = false}),
        onClick = function()
          sceneManager:switchToScene(SetUserIdMenu({serverIp = userIDDirectories[i]}))
        end
      })
    }
  end
  modifyUserIdOptions[#modifyUserIdOptions + 1] = {
    TextButton({
      width = MENU_WIDTH,
      label = Label({text = "back"}),
      onClick = function()
        self:switchToScreen("baseMenu")
      end
    })
  }

  return Menu({menuItems = modifyUserIdOptions, maxHeight = themes[config.theme].main_menu_max_height, itemHeight = ITEM_HEIGHT})
end

function OptionsMenu:load()
  self.menus = self:loadScreens()
  self:repositionMenus()

  self.backgroundImage = themes[config.theme].images.bg_main
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end
  self.uiRoot:addChild(self.menus.baseMenu)
end

function OptionsMenu:update(dt)
  self.backgroundImage:update(dt)
  self.menus[self.activeMenuName]:update()
end

function OptionsMenu:draw()
  self.backgroundImage:draw()
  self.uiRoot:draw()
end

return OptionsMenu

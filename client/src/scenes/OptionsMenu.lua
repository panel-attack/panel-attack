local Scene = require("client.src.scenes.Scene")
local TextButton = require("client.src.ui.TextButton")
local Slider = require("client.src.ui.Slider")
local Label = require("client.src.ui.Label")
local Menu = require("client.src.ui.Menu")
local MenuItem = require("client.src.ui.MenuItem")
local ButtonGroup = require("client.src.ui.ButtonGroup")
local Stepper = require("client.src.ui.Stepper")
local inputManager = require("common.lib.inputManager")
local save = require("client.src.save")
local consts = require("common.engine.consts")
local fileUtils = require("client.src.FileUtils")
local analytics = require("client.src.analytics")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local SoundTest = require("client.src.scenes.SoundTest")
local SetUserIdMenu = require("client.src.scenes.SetUserIdMenu")
local UiElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local ScrollText = require("client.src.ui.ScrollText")
local util = require("common.lib.util")

-- @module optionsMenu
-- Scene for the options menu
local OptionsMenu = class(function(self, sceneParams)
  self.music = "main"
  self.activeMenuName = "baseMenu"
  self:load(sceneParams)
end, Scene)

OptionsMenu.name = "OptionsMenu"

local SCROLL_STEP = 14

function OptionsMenu:loadScreens()
  local menus = {}

  menus.baseMenu = self:loadBaseMenu()
  menus.generalMenu = self:loadGeneralMenu()
  menus.graphicsMenu = self:loadGraphicsMenu()
  menus.audioMenu = self:loadSoundMenu()
  menus.debugMenu = self:loadDebugMenu()
  menus.aboutMenu = self:loadAboutMenu()
  menus.modifyUserIdMenu = self:loadModifyUserIdMenu()
  menus.systemInfo = self:loadInfoScreen(self:getSystemInfo())
  menus.aboutThemes = self:loadInfoScreen(save.read_txt_file("docs/themes.md"))
  menus.aboutCharacters = self:loadInfoScreen(save.read_txt_file("docs/characters.md"))
  menus.aboutStages = self:loadInfoScreen(save.read_txt_file("docs/stages.md"))
  menus.aboutPanels = self:loadInfoScreen(save.read_txt_file("docs/panels.md"))
  menus.aboutAttackFiles = self:loadInfoScreen(save.read_txt_file("docs/training.md"))
  menus.installingMods = self:loadInfoScreen(save.read_txt_file("docs/installMods.md"))

  return menus
end

function OptionsMenu.exit()
  if not themes[config.theme].fullyLoaded then
    themes[config.theme]:load()
    for _, theme in pairs(themes) do
      if theme.name ~= config.theme and theme.fullyLoaded then
        -- unload previous theme to free resources
        theme:preload()
      end
    end
  end
  GAME.theme:playValidationSfx()
  GAME.navigationStack:pop()
end

function OptionsMenu:updateMenuLanguage()
  for _, menu in pairs(self.menus) do
    menu:refreshLocalization()
  end
  for _, scene in ipairs(GAME.navigationStack.scenes) do
    scene:refreshLocalization()
  end
end

function OptionsMenu:switchToScreen(screenName)
  self.menus[self.activeMenuName]:detach()
  self.uiRoot:addChild(self.menus[screenName])
  self.activeMenuName = screenName
end

local function createToggleButtonGroup(configField, onChangeFn)
  return ButtonGroup({
    buttons = {TextButton({width = 60, label = Label({text = "op_off"})}), TextButton({width = 60, label = Label({text = "op_on"})})},
    values = {false, true},
    selectedIndex = config[configField] and 2 or 1,
    onChange = function(group, value)
      GAME.theme:playMoveSfx()
      config[configField] = value
      if onChangeFn then
        onChangeFn()
      end
    end
  })
end

local function createConfigSlider(configField, min, max, onValueChangeFn, precision)
  return Slider({
    min = min,
    max = max,
    value = config[configField] or 0,
    tickLength = math.ceil(100 / max),
    precision = precision,
    onValueChange = function(slider)
      config[configField] = slider.value
      if onValueChangeFn then
        onValueChangeFn(slider)
      end
    end
  })
end

function OptionsMenu:getSystemInfo()
  self.backgroundImage = themes[config.theme].images.bg_readme
  local rendererName, rendererVersion, graphicsCardVendor, graphicsCardName = love.graphics.getRendererInfo()
  local sysInfo = {}
  sysInfo[#sysInfo + 1] = {name = "Operating System", value = love.system.getOS()}
  sysInfo[#sysInfo + 1] = {name = "Renderer", value = rendererName .. " " .. rendererVersion}
  sysInfo[#sysInfo + 1] = {name = "Graphics Card", value = graphicsCardName}
  sysInfo[#sysInfo + 1] = {name = "LOVE Version", value = GAME:loveVersionString()}
  sysInfo[#sysInfo + 1] = {name = "Panel Attack Engine Version", value = consts.ENGINE_VERSION}
  sysInfo[#sysInfo + 1] = {name = "Panel Attack Release Version", value = GAME.updater and tostring(GAME.updater.activeVersion.version) or nil}
  sysInfo[#sysInfo + 1] = {name = "Save Data Directory Path", value = love.filesystem.getSaveDirectory()}
  sysInfo[#sysInfo + 1] = {name = "Characters [Enabled/Total]", value = #characters_ids_for_current_theme .. "/" .. #characters_ids}
  sysInfo[#sysInfo + 1] = {name = "Stages [Enabled/Total]", value = #stages_ids_for_current_theme .. "/" .. #stages_ids}
  sysInfo[#sysInfo + 1] = {name = "Total Panel Sets", value = #panels_ids}
  sysInfo[#sysInfo + 1] = {name = "Total Themes", value = #themeIds}

  local infoString = ""
  for index, info in ipairs(sysInfo) do
    infoString = infoString .. info.name .. ": " .. (info.value or "Unknown") .. "\n"
  end
  return infoString
end

function OptionsMenu:loadInfoScreen(text)
  local label = Label({text = text, translate = false, vAlign = "top", x = 6, y = 6})
  local infoScreen = ScrollText({hFill = true, vFill = true, label = label})
  infoScreen.onBackCallback = function()
    GAME.theme:playCancelSfx()
    self.backgroundImage = themes[config.theme].images.bg_main
    self:switchToScreen("aboutMenu")
  end
  infoScreen.yieldFocus = function() end

  return infoScreen
end

function OptionsMenu:loadBaseMenu()
  local languageNumber
  local languageName = {}
  for k, v in ipairs(Localization:get_list_codes()) do
    languageName[#languageName + 1] = {v, Localization.data[v]["LANG"]}
    if Localization:get_language() == v then
      languageNumber = k
    end
  end
  local languageLabels = {}
  for k, v in ipairs(languageName) do
    local lang = config.language_code
    GAME.setLanguage(v[1])
    languageLabels[#languageLabels + 1] = Label({text = v[2], translate = false, width = 70, height = 25})
    GAME.setLanguage(lang)
  end

  local languageStepper = Stepper({
    labels = languageLabels,
    values = languageName,
    selectedIndex = languageNumber,
    onChange = function(value)
      GAME.theme:playMoveSfx()
      GAME.setLanguage(value[1])
      self:updateMenuLanguage()
    end
  })

  local baseMenuOptions = {
      MenuItem.createStepperMenuItem("op_language", nil, nil, languageStepper),
      MenuItem.createButtonMenuItem("op_general", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("generalMenu")
        end), 
      MenuItem.createButtonMenuItem("op_graphics", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("graphicsMenu")
        end),
      MenuItem.createButtonMenuItem("op_audio", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("audioMenu")
        end),
      MenuItem.createButtonMenuItem("op_debug", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("debugMenu")
        end),
      MenuItem.createButtonMenuItem("op_about", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("aboutMenu")
        end),
      MenuItem.createButtonMenuItem("Modify User ID", nil, false, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("modifyUserIdMenu")
        end),
      MenuItem.createButtonMenuItem("back", nil, nil, self.exit)
    }

  local menu = Menu.createCenteredMenu(baseMenuOptions)
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
    onChange = function(group, value)
      GAME.theme:playMoveSfx()
      config.save_replays_publicly = value
    end
  })

  local performanceSlider = createConfigSlider("activeGarbageCollectionPercent", 20, 80)
  performanceSlider.onValueChange = function(slider)
    config.activeGarbageCollectionPercent = slider.value / 100
    GAME.theme:playMoveSfx()
  end

  local releaseStreamSelection

  if GAME.updater and GAME.updater.releaseStreams and GAME_UPDATER_STATES then
    local releaseStreams = {}

    for name, _ in pairs(GAME.updater.releaseStreams) do
      releaseStreams[#releaseStreams+1] = name
    end

    -- in case the version was changed earlier and we return to options again, reset to the currently launched version
    -- this is so whatever the user leaves the setting on when quitting options that will be what is launched with next time
    GAME.updater:writeLaunchConfig(GAME.updater.activeVersion)

    local buttons = {}

    for i = 1, #releaseStreams do
      buttons[#buttons+1] = TextButton({label = Label({text = releaseStreams[i], translate = false})})
    end

    local function updateReleaseStreamConfig(releaseStreamName)
      local releaseStream = GAME.updater.releaseStreams[releaseStreamName]
      local version = GAME.updater.getLatestInstalledVersion(releaseStream)
      if not version then
        if not GAME.updater:updateAvailable(releaseStream) then
          GAME.updater:getAvailableVersions(releaseStream)
          while GAME.updater.state ~= GAME_UPDATER_STATES.idle do
            GAME.updater:update()
          end
        end
        if GAME.updater:updateAvailable(releaseStream) then
          table.sort(releaseStream.availableVersions, function(a,b) return a.version > b.version end)
          version = releaseStream.availableVersions[1]
        else
          return false
        end
      end
      GAME.updater:writeLaunchConfig(version)

      return true
    end

    releaseStreamSelection = ButtonGroup({
      buttons = buttons,
      values = releaseStreams,
      selectedIndex = tableUtils.indexOf(releaseStreams, GAME.updater.activeVersion.releaseStream.name),
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        local success = updateReleaseStreamConfig(value)
        if not success then
          -- there are no versions for the picked stream
          -- for safety reasons remove the option for that button so the updater does not start in a potentially unsalvageable configuration
          local index = tableUtils.indexOf(releaseStreams, value)
          group:removeButtonByValue(value)
          index = util.bound(1, index, #group.buttons)
          -- simulate changing to the button that replaces the one that got removed due to no attached versions
          group.buttons[index]:onClick(nil, 0)
        end
      end
    })
  end

  local generalMenuOptions = {
    MenuItem.createToggleButtonGroupMenuItem("op_fps", nil, nil, createToggleButtonGroup("show_fps")),
    MenuItem.createToggleButtonGroupMenuItem("op_ingame_infos", nil, nil, createToggleButtonGroup("show_ingame_infos")),
    MenuItem.createToggleButtonGroupMenuItem("op_analytics", nil, nil, createToggleButtonGroup("enable_analytics", function()
      analytics.init()
    end)),
    MenuItem.createToggleButtonGroupMenuItem("op_replay_public", nil, nil, publicReplayButtonGroup),
    MenuItem.createSliderMenuItem("op_performance_drain", nil, nil, performanceSlider),
  }

  if releaseStreamSelection then
    generalMenuOptions[#generalMenuOptions+1] = MenuItem.createToggleButtonGroupMenuItem("Release Stream", nil, false, releaseStreamSelection)
  end

  generalMenuOptions[#generalMenuOptions + 1] = MenuItem.createButtonMenuItem("back", nil, nil,
  function()
    GAME.theme:playCancelSfx()
    self:switchToScreen("baseMenu")
    if GAME.updater and GAME.updater.releaseStreams then
      if releaseStreamSelection.value ~= GAME.updater.activeReleaseStream.name then
        love.window.showMessageBox("Changing Release Stream", "Please restart the game to launch the selected release stream")
      end
    end
  end)

  local menu = Menu.createCenteredMenu(generalMenuOptions)
  return menu
end

function OptionsMenu:loadGraphicsMenu()
  local themeIndex
  local themeLabels = {}
  for i, v in ipairs(themeIds) do
    themeLabels[#themeLabels + 1] = Label({text = v, translate = false})
    if config.theme == v then
      themeIndex = i
    end
  end
  local themeStepper = Stepper({
    labels = themeLabels,
    values = themeIds,
    selectedIndex = themeIndex,
    onChange = function(value)
      GAME.theme:playMoveSfx()
      themes[value]:preload()
      config.theme = value
      GAME.theme = themes[value]
      SoundController:stopMusic()
      GraphicsUtil.setGlobalFont(themes[config.theme].font.path, themes[config.theme].font.size)
      self.backgroundImage = themes[config.theme].images.bg_main
      SoundController:playMusic(themes[config.theme].stageTracks.main)
    end
  })

  local function scaleSettingsChanged()
    GAME.showGameScaleUntil = GAME.timer + 10
    local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local previousXScale = GAME.canvasXScale
    GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
    if previousXScale ~= GAME.canvasXScale then
      GAME:refreshCanvasAndImagesForNewScale()
    end
  end

  local function getFixedScaleSlider()
    local slider = Slider({
      min = 50,
      max = 300,
      value = (config.gameScaleFixedValue * 100) or 100,
      tickLength = 1,
      onValueChange = function(slider)
        config.gameScaleFixedValue = slider.value / 100
        scaleSettingsChanged()
      end
    })
    slider.minText:set(slider.min / 100)
    slider.maxText:set(slider.max / 100)
    slider.valueText:set(slider.value / 100)
    slider.setValue = function(s, value)
      if value ~= s.value then
        s.value = util.bound(s.min, value, s.max)
        s.valueText:set(s.value / 100)
        s:onValueChange()
      end
    end
    slider.receiveInputs = function(s, input)
      if input:isPressedWithRepeat("Left") then
        s:setValue(s.value - 10)
      elseif input:isPressedWithRepeat("Right") then
        s:setValue(s.value + 10)
      end
    end
    local function touchDrag(s, x, y)
      local screenX, screenY = s:getScreenPos()
      s.valueText:set((math.floor((x - screenX) / s.tickLength) + s.min) / 100)
    end
    slider.onTouch = touchDrag
    slider.onDrag = touchDrag
    return slider
  end

  local fixedScaleSlider = MenuItem.createSliderMenuItem("op_scale_fixed_value", nil, true,
    getFixedScaleSlider())
  local function updateFixedButtonGroupVisibility()
    if config.gameScaleType ~= "fixed" then
      self.menus.graphicsMenu:removeMenuItem(fixedScaleSlider.id)
    else
      if self.menus.graphicsMenu:containsMenuItemID(fixedScaleSlider.id) == false then
        self.menus.graphicsMenu:addMenuItem(3, fixedScaleSlider)
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
    onChange = function(group, value)
      GAME.theme:playMoveSfx()
      config.gameScaleType = value
      updateFixedButtonGroupVisibility()
      scaleSettingsChanged()
    end
  })

  local function getShakeIntensitySlider()
    local slider = Slider({
      min = 50,
      max = 100,
      value = (config.shakeIntensity * 100) or 100,
      tickLength = 2,
      onValueChange = function(slider)
        config.shakeIntensity = slider.value / 100
      end
    })
    slider.receiveInputs = function(s, input)
      if input:isPressedWithRepeat("Left") then
        s:setValue(s.value - 5)
      elseif input:isPressedWithRepeat("Right") then
        s:setValue(s.value + 5)
      end
    end
    return slider
  end

  local graphicsMenuOptions = {
    MenuItem.createStepperMenuItem("op_theme", nil, nil, themeStepper),
    MenuItem.createToggleButtonGroupMenuItem("op_scale", nil, nil, scaleButtonGroup),
    MenuItem.createSliderMenuItem("op_portrait_darkness", nil, nil, createConfigSlider("portrait_darkness", 0, 100)),
    MenuItem.createToggleButtonGroupMenuItem("op_popfx", nil, nil, createToggleButtonGroup("popfx")),
    MenuItem.createToggleButtonGroupMenuItem("op_renderTelegraph", nil, nil, createToggleButtonGroup("renderTelegraph")),
    MenuItem.createToggleButtonGroupMenuItem("op_renderAttacks", nil, nil, createToggleButtonGroup("renderAttacks")),
    MenuItem.createSliderMenuItem("op_shakeIntensity", nil, nil, getShakeIntensitySlider()),
    MenuItem.createButtonMenuItem("back", nil, nil, function()
          GAME.showGameScaleUntil = GAME.timer
          GAME.theme:playCancelSfx()
          self:switchToScreen("baseMenu")
        end)
  }

  local menu = Menu.createCenteredMenu(graphicsMenuOptions)
  if config.gameScaleType == "fixed" then
    menu:addMenuItem(3, fixedScaleSlider)
  end
  return menu
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
    onChange = function(group, value)
      GAME.theme:playMoveSfx()
      config.use_music_from = value
    end
  })

  local audioMenuOptions = {
    MenuItem.createSliderMenuItem("op_vol", nil, nil, createConfigSlider("master_volume", 0, 100, function(slider)
        SoundController:setMasterVolume(slider.value)
      end)),
    MenuItem.createSliderMenuItem("op_vol_sfx", nil, nil, createConfigSlider("SFX_volume", 0, 100, function()
        SoundController:applyConfigVolumes()
      end)),
    MenuItem.createSliderMenuItem("op_vol_music", nil, nil, createConfigSlider("music_volume", 0, 100, function()
        SoundController:applyConfigVolumes()
      end)),
      MenuItem.createStepperMenuItem("op_use_music_from", nil, nil, musicFrequencyStepper),
      MenuItem.createToggleButtonGroupMenuItem("op_music_delay", nil, nil, createToggleButtonGroup("danger_music_changeback_delay")),
    MenuItem.createButtonMenuItem("mm_music_test", nil, nil, function()
        GAME.navigationStack:push(SoundTest())
      end),
    MenuItem.createButtonMenuItem("back", nil, nil, function()
        GAME.theme:playCancelSfx()
        self:switchToScreen("baseMenu")
      end)
  }

  local menu = Menu.createCenteredMenu(audioMenuOptions)
  return menu
end

function OptionsMenu:loadDebugMenu()
  local debugMenuOptions = {
    MenuItem.createToggleButtonGroupMenuItem("op_debug", nil, nil, createToggleButtonGroup("debug_mode")),
    MenuItem.createSliderMenuItem("VS Frames Behind", nil, false, createConfigSlider("debug_vsFramesBehind", 0, 200)),
    MenuItem.createToggleButtonGroupMenuItem("Show Debug Servers", nil, false, createToggleButtonGroup("debugShowServers")),
    MenuItem.createToggleButtonGroupMenuItem("Show Design Helper", nil, false, createToggleButtonGroup("debugShowDesignHelper")),
    MenuItem.createButtonMenuItem("Window Size Tester", nil, false, function()
      GAME.navigationStack:push(require("client.src.scenes.WindowSizeTester")())
    end),
    MenuItem.createButtonMenuItem("back", nil, nil, function()
          GAME.theme:playCancelSfx()
          self:switchToScreen("baseMenu")
        end),
  }

  return Menu.createCenteredMenu(debugMenuOptions)
end

function OptionsMenu:loadAboutMenu()
  local aboutMenuOptions = {
    MenuItem.createButtonMenuItem("op_about_themes", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("aboutThemes")
        end),
    MenuItem.createButtonMenuItem("op_about_characters", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("aboutCharacters")
        end),
    MenuItem.createButtonMenuItem("op_about_stages", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("aboutStages")
        end),
    MenuItem.createButtonMenuItem("op_about_panels", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("aboutPanels")
        end),
    MenuItem.createButtonMenuItem("About Attack Files", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("aboutAttackFiles")
        end),
    MenuItem.createButtonMenuItem("Installing Mods", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("installingMods")
        end),
    MenuItem.createButtonMenuItem("System Info", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("systemInfo")
        end),
    MenuItem.createButtonMenuItem("back", nil, nil, function()
          GAME.theme:playCancelSfx()
          self:switchToScreen("baseMenu")
        end)
  }

  local menu = Menu.createCenteredMenu(aboutMenuOptions)
  return menu
end

function OptionsMenu:loadModifyUserIdMenu()
  local modifyUserIdOptions = {}
  local userIDDirectories = fileUtils.getFilteredDirectoryItems("servers")
  for i = 1, #userIDDirectories do
    if love.filesystem.getInfo("servers/" .. userIDDirectories[i] .. "/user_id.txt", "file") then
      modifyUserIdOptions[#modifyUserIdOptions + 1] = MenuItem.createButtonMenuItem(userIDDirectories[i], nil, false, function()
          GAME.navigationStack:push(SetUserIdMenu({serverIp = userIDDirectories[i]}))
        end)
    end
  end
  modifyUserIdOptions[#modifyUserIdOptions + 1] = MenuItem.createButtonMenuItem("back", nil, nil, function()
        GAME.theme:playCancelSfx()
        self:switchToScreen("baseMenu")
      end)

  return Menu.createCenteredMenu(modifyUserIdOptions)
end

function OptionsMenu:load()
  self.menus = self:loadScreens()

  self.backgroundImage = themes[config.theme].images.bg_main
  self.uiRoot:addChild(self.menus.baseMenu)
end

function OptionsMenu:update(dt)
  self.backgroundImage:update(dt)
  self.menus[self.activeMenuName]:receiveInputs(inputManager)
end

function OptionsMenu:draw()
  self.backgroundImage:draw()
  self.uiRoot:draw()
end

return OptionsMenu

local Scene = require("client.src.scenes.Scene")
local Stepper = require("client.src.ui.Stepper")
local Label = require("client.src.ui.Label")
local TextButton = require("client.src.ui.TextButton")
local ButtonGroup = require("client.src.ui.ButtonGroup")
local Menu = require("client.src.ui.Menu")
local MenuItem = require("client.src.ui.MenuItem")
local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

--@module soundTest
-- Scene for the sound test
local SoundTest = class(
  function (self, sceneParams)
    self:load(sceneParams)
  end,
  Scene
)

SoundTest.name = "SoundTest"

local BUTTON_WIDTH = 70
local BUTTON_HEIGHT = 25

local soundTestMenu

local menuValidateSound

local function playMusic(source, id, musicType)
  local musicSource
  if source == "character" then
    if not characters[id].fully_loaded and not characters[id].musics[musicType] then
      characters[id]:sound_init(true, false)
    end
    musicSource = characters[id]
  elseif source == "stage" then
    if not stages[id].fully_loaded and not stages[id].musics[musicType] then
      stages[id]:sound_init(true, false)
    end
    musicSource = stages[id]
  end

  if musicSource.stageTrack then
    musicSource.stageTrack:changeMusic(musicType == "danger_music")
    SoundController:playMusic(musicSource.stageTrack)
  else
    SoundController:stopMusic()
  end
end

local function createSfxMenuInfo(characterId)
  local characterFiles = love.filesystem.getDirectoryItems(characters[characterId].path)
  local musicFiles = {normal_music = true, normal_music_start = true, danger_music = true, danger_music_start = true}
  local supportedSoundFormats = {mp3 = true, ogg = true, wav = true, it = true, flac = true}
  local soundFiles = tableUtils.filter(characterFiles, function(fileName) return not musicFiles[string.match(fileName, "(.*)[.]")] and supportedSoundFormats[string.match(fileName, "[.](.*)")] end)
  local sfxLabels = {}
  local sfxValues = {}
  for _, sfx in ipairs(soundFiles) do
    sfxLabels[#sfxLabels + 1] = Label({
        text = string.match(sfx, "(.*)[.]"),
        translate = false,
        width = BUTTON_WIDTH,
        height = BUTTON_HEIGHT,
        isVisible = false})
    sfxValues[#sfxValues + 1] = sfx
  end
  return sfxLabels, sfxValues
end

function SoundTest:load()
  local characterLabels = {}
  local characterIds = {}
  for _, character in pairs(characters) do
    characterLabels[#characterLabels + 1] = Label({
        text = character.display_name,
        translate = false,
        width = BUTTON_WIDTH,
        height = BUTTON_HEIGHT})
    characterIds[#characterIds + 1] = character.id
  end
  
  local playButtonGroup
  local musicTypeButtonGroup
  local sfxStepper
  local characterStepper = Stepper(
    {
      labels = characterLabels,
      values = characterIds,
      selectedIndex = 1,
      onChange = function(value)
        GAME.theme:playMoveSfx()

        local labels, values = createSfxMenuInfo(value)
        sfxStepper:setLabels(labels, values, 1)

        if playButtonGroup.value == "character" then
          playMusic("character", value, musicTypeButtonGroup.value)
        end
      end
    }
  )
  
  
  local stageLabels = {}
  local stageIds = {}
  for _, stage in pairs(stages) do
    stageLabels[#stageLabels + 1] = Label({
        text = stage.display_name,
        translate = false,
        width = BUTTON_WIDTH,
        height = BUTTON_HEIGHT})
    stageIds[#stageIds + 1] = stage.id
  end
  local stageStepper = Stepper(
    {
      labels = stageLabels,
      values = stageIds,
      selectedIndex = 1,
      onChange = function(value) 
        GAME.theme:playMoveSfx()
        if playButtonGroup.value == "stage" then
          playMusic("stage", value, musicTypeButtonGroup.value)
        end
      end
    }
  )
  
  musicTypeButtonGroup = ButtonGroup(
    {
      buttons = {
        TextButton({label = Label({text = "Normal", translate = false})}),
        TextButton({label = Label({text = "Danger", translate = false})}),
      },
      values = {"normal_music", "danger_music"},
      selectedIndex = 1,
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        if playButtonGroup.value == "character" then
          playMusic(playButtonGroup.value, characterStepper.value, value)
        elseif playButtonGroup.value == "stage" then
          playMusic(playButtonGroup.value, stageStepper.value, value)
        end
      end
    }
  )
  
  playButtonGroup = ButtonGroup(
    {
      buttons = {
        TextButton({label = Label({text = "op_off"})}),
        TextButton({label = Label({text = "character"})}),
        TextButton({label = Label({text = "stage"})}),
      },
      values = {"", "character", "stage"},
      selectedIndex = 1,
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        if value == "character" then
          playMusic(value, characterStepper.value, musicTypeButtonGroup.value)
        elseif value == "stage" then
          playMusic(value, stageStepper.value, musicTypeButtonGroup.value)
        else
          SoundController:stopMusic()
        end
      end
    }
  )
  
  local labels, values = createSfxMenuInfo(characterStepper.value)
  
  sfxStepper = Stepper(
    {
      labels = labels,
      values = values,
      selectedIndex = 1,
      onChange = function(value)
        GAME.theme:playMoveSfx()
      end
    }
  )
  
  local playCharacterSFXFn = function() 
    if #sfxStepper.labels > 0 then
      love.audio.play(love.audio.newSource(characters[characterStepper.value].path.."/"..sfxStepper.value, "static"))
    end
  end

  local menuLabelWidth = 120
  local soundTestMenuOptions = {
    MenuItem.createStepperMenuItem("character", nil, nil, characterStepper),
    MenuItem.createStepperMenuItem("stage", nil, nil, stageStepper),
    MenuItem.createToggleButtonGroupMenuItem("op_music_type", nil, nil, musicTypeButtonGroup),
    MenuItem.createToggleButtonGroupMenuItem("Background", nil, false, playButtonGroup),
    MenuItem.createStepperMenuItem("op_music_sfx", nil, nil, sfxStepper),
    MenuItem.createButtonMenuItem("op_music_play", nil, nil, playCharacterSFXFn),
    MenuItem.createButtonMenuItem("back", nil, nil, function()
      love.audio.stop()
      SoundController:stopMusic()
      themes[config.theme].sounds.menu_validate = menuValidateSound
      GAME.navigationStack:pop()
    end)
  }
  
  soundTestMenu = Menu.createCenteredMenu(soundTestMenuOptions)

  self.uiRoot:addChild(soundTestMenu)
  
  self.backgroundImg = themes[config.theme].images.bg_main

  -- stop main music
  SoundController:stopMusic()

  -- disable the menu_validate sound and keep a copy of it to restore later
  menuValidateSound = themes[config.theme].sounds.menu_validate
  themes[config.theme].sounds.menu_validate = zero_sound

  GraphicsUtil.print(loc("op_music_load"), unpack(themes[config.theme].main_menu_screen_pos))
end

function SoundTest:update(dt)
  soundTestMenu:receiveInputs()
  self.backgroundImg:update(dt)
end

function SoundTest:draw()
  self.backgroundImg:draw()
  self.uiRoot:draw()
end

return SoundTest
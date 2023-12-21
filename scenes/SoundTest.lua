local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Stepper = require("ui.Stepper")
local Label = require("ui.Label")
local TextButton = require("ui.TextButton")
local ButtonGroup = require("ui.ButtonGroup")
local Menu = require("ui.Menu")
local tableUtils = require("tableUtils")
local class = require("class")

--@module soundTest
-- Scene for the sound test
local SoundTest = class(
  function (self, sceneParams)
    self:load(sceneParams)
  end,
  Scene
)

SoundTest.name = "SoundTest"
sceneManager:addScene(SoundTest)

local BUTTON_WIDTH = 70
local BUTTON_HEIGHT = 25

local soundTestMenu

local menuValidateSound

local function playMusic(source, id, musicType)
  local musicToUse
  local musicStyle
  if source == "character" then
    if not characters[id].fully_loaded and not characters[id].musics[musicType] then
      characters[id]:sound_init(true, false)
    end
    musicToUse = characters[id].musics
    musicStyle = characters[id].music_style
  elseif source == "stage" then
    if not stages[id].fully_loaded and not stages[id].musics[musicType] then
      stages[id]:sound_init(true, false)
    end
    musicToUse = stages[id].musics
    musicStyle = stages[id].music_style
  end
          
  if musicStyle == "dynamic" then
    find_and_add_music(musicToUse, "normal_music")
    find_and_add_music(musicToUse, "danger_music")
    if musicType == "danger_music" then
      setFadePercentageForGivenTracks(0, {musicToUse["normal_music"], musicToUse["normal_music_start"]})
      setFadePercentageForGivenTracks(1, {musicToUse["danger_music"], musicToUse["danger_music_start"]})
    else
      setFadePercentageForGivenTracks(1, {musicToUse["normal_music"], musicToUse["normal_music_start"]})
      setFadePercentageForGivenTracks(0, {musicToUse["danger_music"], musicToUse["danger_music_start"]})
    end
  else
    stop_the_music()
    find_and_add_music(musicToUse, musicType)
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
        Menu.playMoveSfx()

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
        Menu.playMoveSfx()
        if playButtonGroup.value == "stage" then
          playMusic("stage", value, musicTypeButtonGroup.value)
        end
      end
    }
  )
  
  musicTypeButtonGroup = ButtonGroup(
    {
      buttons = {
        TextButton({label = Label({text = "Normal"}), translate = false}),
        TextButton({label = Label({text = "Danger"}), translate = false}),
      },
      values = {"normal_music", "danger_music"},
      selectedIndex = 1,
      onChange = function(value)
        Menu.playMoveSfx()
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
      onChange = function(value)
        Menu.playMoveSfx()
        if value == "character" then
          playMusic(value, characterStepper.value, musicTypeButtonGroup.value)
        elseif value == "stage" then
          playMusic(value, stageStepper.value, musicTypeButtonGroup.value)
        else
          stop_the_music()
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
        Menu.playMoveSfx()
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
    {Label({width = menuLabelWidth, text = "character"}), characterStepper},
    {Label({width = menuLabelWidth, text = "stage"}), stageStepper},
    {Label({width = menuLabelWidth, text = "op_music_type"}), musicTypeButtonGroup},
    {Label({width = menuLabelWidth, text = "Background", translate = false}), playButtonGroup},
    {TextButton({width = menuLabelWidth, label = Label({text = "op_music_sfx"}), onClick = playCharacterSFXFn}), sfxStepper},
    {TextButton({width = menuLabelWidth, label = Label({text = "back"}), onClick = function() sceneManager:switchToScene(sceneManager:createScene("OptionsMenu")) end})},
  }
  
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  soundTestMenu = Menu({
    x = x - 20,
    y = y + 10,
    menuItems = soundTestMenuOptions, 
    maxHeight = themes[config.theme].main_menu_max_height
  })
  
  self.backgroundImg = themes[config.theme].images.bg_main

  -- stop main music
  stop_all_audio()

  -- disable the menu_validate sound and keep a copy of it to restore later
  menuValidateSound = themes[config.theme].sounds.menu_validate
  themes[config.theme].sounds.menu_validate = zero_sound

  gprint(loc("op_music_load"), unpack(themes[config.theme].main_menu_screen_pos))
end

function SoundTest:update(dt)
  soundTestMenu:update(dt)
  self.backgroundImg:update(dt)
end

function SoundTest:draw()
  self.backgroundImg:draw()
  soundTestMenu:draw()
end

--fallback to main theme if nothing is playing or if dynamic music is playing, dynamic music cannot cleanly be "carried out" of the sound test due to the master volume reapplication in the audio options menu
function SoundTest:unload()
  stop_all_audio()
  themes[config.theme].sounds.menu_validate = menuValidateSound
  soundTestMenu:setVisibility(false)
end

return SoundTest
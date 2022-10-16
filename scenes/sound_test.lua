local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Stepper = require("ui.Stepper")
local Label = require("ui.Label")
local Button = require("ui.Button")
local ButtonGroup = require("ui.ButtonGroup")
local Menu = require("ui.Menu")
local tableUtils = require("tableUtils")

--@module sound_test
local sound_test = Scene("sound_test")

local audio_test_ret = nil
local menu_x, menu_y = unpack(main_menu_screen_pos)
local soundTestMenu
local loaded_track_index = 0
local index = 1
local normalMusic = {}
local dangerMusic = {}
local playing = false
local tracks = {}
local character_sounds = {}
local character_sounds_keys = {}
local current_sound_index = 0

local ram_load = 0
local max_ram_load = 20 --arbitrary number of characters/stages allowed to load before forcing a garbagecollection

local music_type = "normal_music"
local current_music = nil
local menu_validate_sound

local sound_test_menu

local function playMusic(source, id, music_type)
  local music_to_use
  local music_style
  if source == "character" then
    if not characters[id].fully_loaded and not characters[id].musics[music_type] then
      characters[id]:sound_init(true, false)
    end
    music_to_use = characters[id].musics
    music_style = characters[id].music_style
  elseif source == "stage" then
    if not stages[id].fully_loaded and not stages[id].musics[music_type] then
      stages[id]:sound_init(true, false)
    end
    music_to_use = stages[id].musics
    music_style = stages[id].music_style
  end
          
  if music_style == "dynamic" then
    find_and_add_music(music_to_use, "normal_music")
    find_and_add_music(music_to_use, "danger_music")
    if music_type == "danger_music" then
      setFadePercentageForGivenTracks(0, {music_to_use["normal_music"], music_to_use["normal_music_start"]})
      setFadePercentageForGivenTracks(1, {music_to_use["danger_music"], music_to_use["danger_music_start"]})
    else
      setFadePercentageForGivenTracks(1, {music_to_use["normal_music"], music_to_use["normal_music_start"]})
      setFadePercentageForGivenTracks(0, {music_to_use["danger_music"], music_to_use["danger_music_start"]})
    end
  else
    stop_the_music()
    find_and_add_music(music_to_use, music_type)
  end
end

local function createSfxMenuInfo(characterId)
  local characterFiles = love.filesystem.getDirectoryItems(characters[characterId].path)
  local music_files = {normal_music = true, normal_music_start = true, danger_music = true, danger_music_start = true}
  local supported_sound_formats = {mp3 = true, ogg = true, wav = true, it = true, flac = true}
  local soundFiles = tableUtils.filter(characterFiles, function(fileName) return not music_files[string.match(fileName, "(.*)[.]")] and supported_sound_formats[string.match(fileName, "[.](.*)")] end)
  local sfxLabels = {}
  local sfxValues = {}
  for _, sfx in ipairs(soundFiles) do
    sfxLabels[#sfxLabels + 1] = Label({
        label = string.match(sfx, "(.*)[.]"),
        translate = false,
        width = 70,
        height = 25,
        isVisible = false})
    sfxValues[#sfxValues + 1] = sfx
  end
  return sfxLabels, sfxValues
end

function sound_test:init()
  sceneManager:addScene(self)
  
  local character_labels = {}
  local character_ids = {}
  for _, character in pairs(characters) do
    character_labels[#character_labels + 1] = Label({
        label = character.display_name,
        translate = false,
        width = 70,
        height = 25})
    character_ids[#character_ids + 1] = character.id
  end
  
  local play_button_group
  local music_type_button_group
  local sfxStepper
  local character_stepper = Stepper(
    {
      labels = character_labels,
      values = character_ids,
      selectedIndex = 1,
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move)

        local labels, values = createSfxMenuInfo(value)
        sfxStepper:setLabels(labels, values, 1)

        if play_button_group.value == "character" then
          playMusic("character", value, music_type_button_group.value)
        end
      end
    }
  )
  
  
  local stage_labels = {}
  local stage_ids = {}
  for _, stage in pairs(stages) do
    stage_labels[#stage_labels + 1] = Label({
        label = stage.display_name,
        translate = false,
        width = 70,
        height = 25})
    stage_ids[#stage_ids + 1] = stage.id
  end
  local stage_stepper = Stepper(
    {
      labels = stage_labels,
      values = stage_ids,
      selectedIndex = 1,
      onChange = function(value) 
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        if play_button_group.value == "stage" then
          playMusic("stage", value, music_type_button_group.value)
        end
      end
    }
  )
  
  music_type_button_group = ButtonGroup(
    {
      buttons = {
        Button({label = "Normal", translate = false}),
        Button({label = "Danger", translate = false}),
      },
      values = {"normal_music", "danger_music"},
      selected_index = 1,
      onChange = function(value)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        if play_button_group.value == "character" then
          playMusic(play_button_group.value, character_stepper.value, value)
        elseif play_button_group.value == "stage" then
          playMusic(play_button_group.value, stage_stepper.value, value)
        end
      end
    }
  )
  
  play_button_group = ButtonGroup(
    {
      buttons = {
        Button({label = "op_off"}),
        Button({label = "character"}),
        Button({label = "stage"}),
      },
      values = {"", "character", "stage"},
      selected_index = 1,
      onChange = function(value)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
        if value == "character" then
          playMusic(value, character_stepper.value, music_type_button_group.value)
        elseif value == "stage" then
          playMusic(value, stage_stepper.value, music_type_button_group.value)
        else
          stop_the_music()
        end
      end
    }
  )
  
  local labels, values = createSfxMenuInfo(character_stepper.value)
  
  sfxStepper = Stepper(
    {
      labels = labels,
      values = values,
      selectedIndex = 1,
      onChange = function(value)
        play_optional_sfx(themes[config.theme].sounds.menu_move)
      end
    }
  )
  
  local menu_label_width = 120
  local sound_test_menu_options = {
    {Label({width = menu_label_width, label = "character"}), character_stepper},
    {Label({width = menu_label_width, label = "stage"}), stage_stepper},
    {Label({width = menu_label_width, label = "op_music_type"}), music_type_button_group},
    {Label({width = menu_label_width, label = "Background", translate = false}), play_button_group},
    {Button({width = menu_label_width, label = "op_music_sfx", onClick = function() love.audio.play(love.audio.newSource(characters[character_stepper.value].path.."/"..sfxStepper.value, "static")) end}), sfxStepper},
    {Button({width = menu_label_width, label = "back", onClick = function() sceneManager:switchToScene("options_menu") end})},
  }
  
  local x, y = unpack(main_menu_screen_pos)
  x = x - 70--- 400
  y = y + 10
  sound_test_menu = Menu({menuItems = sound_test_menu_options, x = x, y = y})
  sound_test_menu:setVisibility(false)
end

function sound_test:load()
  -- stop main music
  stop_all_audio()

  -- disable the menu_validate sound and keep a copy of it to restore later
  menu_validate_sound = themes[config.theme].sounds.menu_validate
  themes[config.theme].sounds.menu_validate = zero_sound

  gprint(loc("op_music_load"), unpack(main_menu_screen_pos))
  sound_test_menu:setVisibility(true)
end

function sound_test:update()
  sound_test_menu:update()
  sound_test_menu:draw()
end

--fallback to main theme if nothing is playing or if dynamic music is playing, dynamic music cannot cleanly be "carried out" of the sound test due to the master volume reapplication in the audio options menu
function sound_test:unload()
  stop_all_audio()
  themes[config.theme].sounds.menu_validate = menu_validate_sound
  sound_test_menu:setVisibility(false)
end

return sound_test
supported_sound_formats = { ".mp3",".ogg", ".it" }

--sets the volume of a single source or table of sources
function set_volume(source, new_volume)
  if type(source) == "table" then
    for _,v in pairs(source) do
      set_volume(v, new_volume)
    end
  elseif type(source) ~= "number" then
    source:setVolume(new_volume)
  end
end

-- returns a new sound effect if it can be found, else returns nil
local function find_sound(sound_name, dirs_to_check, streamed)
  streamed = streamed or false
  local found_source
  for k,dir in ipairs(dirs_to_check) do
    found_source = get_from_supported_extensions(dir..sound_name,streamed)
    if found_source then
      return found_source
    end
  end
  return nil
end

local function find_generic_SFX(SFX_name)
  local dirs_to_check = {"sounds/"..config.sounds_dir.."/SFX/",
                         "sounds/"..default_sounds_dir.."/SFX/"}
  return find_sound(SFX_name, dirs_to_check)
end

--returns a source, or nil if it could not find a file
function get_from_supported_extensions(path_and_filename,streamed)
  for k, extension in ipairs(supported_sound_formats) do
    if love.filesystem.getInfo(path_and_filename..extension) then
      if streamed then
        return love.audio.newSource(path_and_filename..extension, "stream")
      else
        return love.audio.newSource(path_and_filename..extension, "static")
      end
    end
  end
  return nil
end

--check whether a sound file exists
function any_supported_extension(path_and_filename)
  for k, extension in ipairs(supported_sound_formats) do
    if love.filesystem.getInfo(path_and_filename..extension) then
      return true
    end
  end
  return false
end

function assert_requirements_met()
  --assert we have all required generic sound effects
  local SFX_requirements =  {"cur_move", "swap", "fanfare1", "fanfare2", "fanfare3", "game_over", "countdown", "go"}
  for k,v in ipairs(SFX_requirements) do
    assert(sounds.SFX[v], "SFX \""..v.."\"was not loaded")
  end
  local NUM_REQUIRED_GARBAGE_THUDS = 3
  for i=1, NUM_REQUIRED_GARBAGE_THUDS do
    assert(sounds.SFX.garbage_thud[i], "SFX garbage_thud "..i.."was not loaded")
  end
  for popLevel=1,4 do
      for popIndex=1,10 do
          assert(sounds.SFX.pops[popLevel][popIndex], "SFX pop"..popLevel.."-"..popIndex.." was not loaded")
      end
  end

  --assert we have the required SFX and music for each character
  for _,character in pairs(characters) do
    character:assert_requirements_met()
  end
end

function play_optional_sfx(sfx)
  if not SFX_mute and sfx ~= nil then
    sfx:stop()
    sfx:play()
  end
end

function sound_init()
  --sounds: SFX, music
  SFX_Fanfare_Play = 0
  SFX_GameOver_Play = 0
  SFX_GarbageThud_Play = 0
  sounds = {
    SFX = {
      cur_move = find_generic_SFX("move"),
      swap = find_generic_SFX("swap"),
      land = find_generic_SFX("land"),
      fanfare1 = find_generic_SFX("fanfare1"),
      fanfare2 = find_generic_SFX("fanfare2"),
      fanfare3 = find_generic_SFX("fanfare3"),
      game_over = find_generic_SFX("gameover"),
      countdown = find_generic_SFX("countdown"),
      go = find_generic_SFX("go"),
      menu_move = find_generic_SFX("menu_move"),
      menu_validate = find_generic_SFX("menu_validate"),
      menu_cancel = find_generic_SFX("menu_cancel"),
      garbage_thud = {
        find_generic_SFX("thud_1"),
        find_generic_SFX("thud_2"),
        find_generic_SFX("thud_3")
      },
      pops = {}
    },
    music = {
    }
  }
  zero_sound = get_from_supported_extensions("zero_music")
  
  for popLevel=1,4 do
    sounds.SFX.pops[popLevel] = {}
    for popIndex=1,10 do
      sounds.SFX.pops[popLevel][popIndex] = find_generic_SFX("pop"..popLevel.."-"..popIndex)
    end
  end

  for _,character in pairs(characters) do
    character:sound_init()
  end
  
  assert_requirements_met()
  apply_config_volume()
end

function apply_config_volume()
  love.audio.setVolume(config.master_volume/100)
  set_volume(sounds.SFX, config.SFX_volume/100)
  set_volume(sounds.music, config.music_volume/100)
  for _,character in pairs(characters) do
    set_volume(character.sounds, config.SFX_volume/100)
    set_volume(character.musics, config.SFX_volume/100)
  end
end

-- New music engine stuff here
music_t = {}
currently_playing_tracks = {} -- needed because we clone the tracks below
function stop_the_music()
  for k, v in pairs(currently_playing_tracks) do
    v:stop()
    currently_playing_tracks[k] = nil
  end
  music_t = {}
end

function find_and_add_music(character_id, musicType)
  local start_music = characters[character_id].musics[musicType .. "_start"] or zero_sound
  local loop_music = characters[character_id].musics[musicType]
  music_t[love.timer.getTime()] = make_music_t(
          start_music
  )
  music_t[love.timer.getTime() + start_music:getDuration()] = make_music_t(
          loop_music, true
  )
end

function make_music_t(source, loop)
    return {t = source, l = loop or false}
end

require("sound_util")

local function find_generic_SFX(SFX_name)
  local dirs_to_check = {"sounds/"..config.sounds_dir.."/SFX/",
                         "sounds/"..default_sounds_dir.."/SFX/"}
  return find_sound(SFX_name, dirs_to_check)
end

local function assert_requirements_met()
  --assert we have all required generic sound effects
  local SFX_requirements =  {"cur_move", "swap", "fanfare1", "fanfare2", "fanfare3", "game_over", "countdown", "go"}
  for k,v in ipairs(SFX_requirements) do
    assert(sounds.SFX[v], "SFX \""..v.."\" was not loaded")
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
  
  assert_requirements_met()
  apply_config_volume()
end

function apply_config_volume()
  love.audio.setVolume(config.master_volume/100)
  set_volume(sounds.SFX, config.SFX_volume/100)
  set_volume(sounds.music, config.music_volume/100)
  for _,character in pairs(characters) do
    character:apply_config_volume()
  end
end

function play_optional_sfx(sfx)
  if not SFX_mute and sfx ~= nil then
    sfx:stop()
    sfx:play()
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

function find_and_add_music(character_id, music_type)
  local start_music = characters[character_id].musics[music_type .. "_start"] or zero_sound
  local loop_music = characters[character_id].musics[music_type]
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

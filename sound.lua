require("sound_util")

function apply_config_volume()
  love.audio.setVolume(config.master_volume/100)
  set_volume(sounds, config.SFX_volume/100)
  for _,character in pairs(characters) do
    set_volume(character.sounds, config.SFX_volume/100)
    set_volume(character.musics, config.music_volume/100)
  end
  for _,stage in pairs(stages) do
    stage:apply_config_volume()
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

function find_and_add_music(musics, music_type)
  local start_music = musics[music_type .. "_start"] or zero_sound
  local loop_music = musics[music_type]
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

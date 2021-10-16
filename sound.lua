require("sound_util")
-- sets the configuration volume
function apply_config_volume()
  love.audio.setVolume(config.master_volume / 100)
  themes[config.theme]:apply_config_volume()
  for _, character in pairs(characters) do
    character:apply_config_volume()
  end
  for _, stage in pairs(stages) do
    stage:apply_config_volume()
  end
end
-- plays sfx
function play_optional_sfx(sfx)
  if not SFX_mute and sfx ~= nil then
    sfx:stop()
    sfx:play()
  end
end

-- New music engine stuff here
music_t = {}
currently_playing_tracks = {} -- needed because we clone the tracks below

function update_music()
  for k, v in pairs(music_t) do
    if v and k - love.timer.getTime() < 0.007 then
      if not v.t:isPlaying() then
        v.t:play()
        currently_playing_tracks[#currently_playing_tracks + 1] = v.t
      end
      music_t[k] = nil
    end
  end
end
-- stops all audio playing
function stop_all_audio()
  love.audio.stop()
  stop_the_music()
end
-- stops all songs currently playing
function stop_the_music()
  --print("musics have been stopped")
  for k, v in pairs(currently_playing_tracks) do
    v:stop()
    currently_playing_tracks[k] = nil
  end
  music_t = {}
end
-- sets the volume for use of fading out music over time
function set_music_fade_percentage(percentage)
  --print(debug.traceback(""))
  --print(percentage * config.music_volume / 100)
  for k, v in pairs(currently_playing_tracks) do
    v:setVolume(percentage * config.music_volume / 100)
  end
end
-- creates a music track
local function make_music_t(source, loop)
  return {t = source, l = loop or false}
end

-- locates a song of the specified type and adds it
function find_and_add_music(musics, music_type)
  print("music " .. music_type .. " is now playing")
  local start_music = musics[music_type .. "_start"] or zero_sound
  local loop_music = musics[music_type]
  if loop_music:isPlaying() or start_music:isPlaying() then
    return
  end
  music_t[love.timer.getTime()] = make_music_t(start_music)
  music_t[love.timer.getTime() + start_music:getDuration()] = make_music_t(loop_music, true)
end

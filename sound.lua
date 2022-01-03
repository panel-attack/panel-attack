require("sound_util")
local logger = require("logger")

-- Sets the volumes based on the current player configuration settings
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

-- Play the sound if sounds aren't muted
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

-- Takes all queued music and starts playing it
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

-- Stop all audio and music
function stop_all_audio()
  love.audio.stop()
  stop_the_music()
end

-- Stop just music files
function stop_the_music()
  --logger.trace("musics have been stopped")
  for k, v in pairs(currently_playing_tracks) do
    v:stop()
    currently_playing_tracks[k] = nil
  end
  music_t = {}
end


-- Set the given music files to the given percentage from their normal config volume
function setFadePercentageForGivenTracks(percentage, tracks)
  for _, v in pairs(tracks) do
    v:setVolume(percentage * config.music_volume / 100)
  end
end

-- Set all the playing music files to the given percentage from their normal config volume
function setMusicFadePercentage(percentage)
  setFadePercentageForGivenTracks(percentage, currently_playing_tracks)
end

-- creates a music track
local function make_music_t(source, loop)
  return {t = source, l = loop or false}
end

-- Finds the given music file with the given type and adds it to the queue
function find_and_add_music(musics, music_type)
  logger.trace("music " .. music_type .. " is now playing")
  local start_music = musics[music_type .. "_start"] or zero_sound
  local loop_music = musics[music_type]
  if not loop_music or not start_music or loop_music:isPlaying() or start_music:isPlaying() then
    return
  end
  music_t[love.timer.getTime()] = make_music_t(start_music)
  music_t[love.timer.getTime() + start_music:getDuration()] = make_music_t(loop_music, true)
end

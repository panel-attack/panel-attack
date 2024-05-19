local tableUtils = require("common.lib.tableUtils")

local function stopIfPlaying(audioSource)
  if audioSource:isPlaying() then
    audioSource:stop()
  end
end

-- global soundcontroller that controls music playback 
SoundController = {
  -- the active Music or StageTrack
  activeTrack = nil
}

-- applies the sfx volume setting to the passed sfx which can be a table of sources or a source itself
function SoundController:applySfxVolume(sfx)
  if type(sfx) == "table" then
    for _, v in pairs(sfx) do
      SoundController:applySfxVolume(v)
    end
  elseif type(sfx) == "userdata" and sfx:typeOf("Source") then
    sfx:setVolume(config.SFX_volume / 100)
  end
end

-- applies the music volume setting to the passed music which can be a table of sources or a source itself
function SoundController:applyMusicVolume(music)
  if type(music) == "table" then
    for _, v in pairs(music) do
      SoundController:applyMusicVolume(v)
    end
  elseif type(music) == "userdata" and music:typeOf("Source") then
    music:setVolume(config.music_volume / 100)
  end
end

-- Sets the volumes based on the current player configuration settings
function SoundController:applyConfigVolumes()
  GAME.muteSound = (config.master_volume == 0 or (config.SFX_volume == 0 and config.music_volume == 0))

  love.audio.setVolume(config.master_volume / 100)
  themes[config.theme]:applyConfigVolume()
  for _, character in pairs(characters) do
    character:applyConfigVolume()
  end
  for _, stage in pairs(stages) do
    stage:applyConfigVolume()
  end
end

function SoundController:setMasterVolume(volume)
  config.master_volume = volume
  GAME.muteSound = (config.master_volume == 0 or (config.SFX_volume == 0 and config.music_volume == 0))
  love.audio.setVolume(volume / 100)
end

-- stops all sources in a table of integer indexed sources or a single sfx from playing
function SoundController:stopSfx(sfx)
  if type(sfx) == "table" then
    for _, s in ipairs(sfx) do
      stopIfPlaying(s)
    end
  elseif type(sfx) == "userdata" and sfx:typeOf("Source") then
    stopIfPlaying(sfx)
  end
end

-- stops all on-going SFX in the SFX table and then randomly picks one to play
-- if the sfxTable is empty, the fallback sound is played instead
-- fallback can be another sfxTable or a single sound
function SoundController:playRandomSfx(sfxTable, fallback)
  if not GAME.muteSound then
    if sfxTable and #sfxTable > 0 then
      local sfx = tableUtils.getRandomElement(sfxTable)
      self:playSfx(sfx)
    elseif fallback then
      if type(fallback) == "table" then
        self:playRandomSfx(fallback)
      elseif type(fallback) == "userdata" and fallback:typeOf("Source") then
        self:playSfx(fallback)
      end
    end
  end
end

function SoundController:playSfx(sfx)
  if not GAME.muteSound then
    if sfx then
      stopIfPlaying(sfx)
      sfx:play()
    end
  end
end

-- fades out the active music over the next `fadeOutDuration` seconds
function SoundController:fadeOutActiveTrack(fadeOutDuration)
  assert(fadeOutDuration > 0, "fade out duration must be greater than 0")
  if self.activeTrack then
    self.fadeOutDuration = fadeOutDuration
    self.fadeOutStartTime = love.timer.getTime()
    self.fadeOutStartVolume = self.activeTrack:getVolume()
  end
end

function SoundController:updateFadeOut()
  if self.fadeOutStartTime and not GAME.muteSound then
    local time = love.timer.getTime()
    local percentage = (time - self.fadeOutStartTime) / self.fadeOutDuration
    if percentage >= 1 then
      self.fadeOutStartTime = nil
      self.fadeOutDuration = nil
      self.fadeOutStartVolume = nil
      self.activeTrack:setVolume(0)
    else
      self.activeTrack:setVolume(self.fadeOutStartVolume * (1 - percentage))
    end
  end
end

function SoundController:cancelFadeOut()
  self.fadeOutStartTime = nil
  self.fadeOutDuration = nil
  self.fadeOutStartVolume = nil
end

-- starts playing the music, resetting its volume to config.music_volume and stops the currently playing track if any
function SoundController:playMusic(music)
  if not GAME.muteSound and music then
    self:cancelFadeOut()
    if self.activeTrack then
      if music ~= self.activeTrack then
        self.activeTrack:stop()
        self.activeTrack = music
        self.activeTrack:play()
        self.activeTrack:setVolume(config.music_volume / 100)
      elseif not music:isPlaying() then
        self.activeTrack:play()
      end
    else
      self.activeTrack = music
      self.activeTrack:play()
      self.activeTrack:setVolume(config.music_volume / 100)
    end
  end
end

-- stops the currently playing track
function SoundController:stopMusic()
  if self.activeTrack then
    self:cancelFadeOut()
    self.activeTrack:stop()
  end
end

-- pauses the currently playing track
function SoundController:pauseMusic()
  if self.activeTrack then
    self.activeTrack:pause()
  end
end

function SoundController:update()
  if self.activeTrack then
    self.activeTrack:update()
    self:updateFadeOut()
  end
end

return SoundController
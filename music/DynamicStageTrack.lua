local class = require("class")
local StageTrack = require("music.StageTrack")

local CROSSFADE_DURATION = 60

local DynamicStageTrack = class(function(stageTrack, normalMusic, dangerMusic)
  assert(dangerMusic, "Dynamic tracks need danger music!")
  stageTrack.crossfadeTimer = 0
  stageTrack.volume = config.music_volume
end,
StageTrack)

function DynamicStageTrack:changeMusic(useDangerMusic)
  if useDangerMusic then
    self.state = "danger"
  else
    self.state = "normal"
  end

  if self.crossfadeTimer == 0 then
    self.crossfadeTimer = CROSSFADE_DURATION
  else
    -- basically reversing an on-going fade
    self.crossfadeTimer = CROSSFADE_DURATION - self.crossfadeTimer
  end
end

function DynamicStageTrack:update()
  self.normalMusic:update()
  self.dangerMusic:update()
  if self.crossfadeTimer > 0 then
    self.crossfadeTimer = self.crossfadeTimer - 1
    self:updateTrackVolumes()
  end
end

function DynamicStageTrack:play()
  self.normalMusic:play()
  self.dangerMusic:play()
end

function DynamicStageTrack:isPlaying()
  return self.normalMusic:isPlaying()
end

function DynamicStageTrack:pause()
  self.normalMusic:pause()
  self.dangerMusic:pause()
end

function DynamicStageTrack:setVolume(volume)
  self.volume = volume
  self:updateTrackVolumes()
end

function DynamicStageTrack:updateTrackVolumes()
  local percentage = self.crossfadeTimer / CROSSFADE_DURATION

  if self.state == "danger" then
    self.dangerMusic:setVolume(self.volume * (1 - percentage))
    self.normalMusic:setVolume(self.volume * percentage)
  else
    self.dangerMusic:setVolume(self.volume * percentage)
    self.normalMusic:setVolume(self.volume * (1 - percentage))
  end
end

function DynamicStageTrack:getVolume()
  local v1, v2 = self.normalMusic:getVolume(), self.dangerMusic:getVolume()
  return v1 + v2
end

return DynamicStageTrack
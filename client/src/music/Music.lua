local class = require("class")

-- construct a music object with a looping `main` music and an optional `start` played as the intro
local Music = class(function(music, main, start)
  assert(main, "Music needs at least a main audio source!")
  music.main = main
  main:setLooping(true)
  music.start = start
  music.currentSource = nil
  music.mainStartTime = nil
  music.paused = false
end)


function Music:play()
  if not self.currentSource then
    if self.start then
      self.currentSource = self.start
    else
      self.currentSource = self.main
    end
  end

  if self.currentSource == self.start then
    local duration = self.start:getDuration()
    local position = self.start:tell()
    self.mainStartTime = love.timer.getTime() + duration - position
  end

  self.currentSource:play()
  self.paused = false
end

function Music:isPlaying()
  return self.currentSource and self.currentSource:isPlaying()
end

function Music:stop()
  self.currentSource = nil
  self.mainStartTime = nil
  self.paused = false
  self.main:stop()
  if self.start then
    self.start:stop()
  end
end

function Music:pause()
  self.paused = true
  if self.currentSource then
    self.currentSource:pause()
  end
end

function Music:isPaused()
  return self.paused
end

function Music:setVolume(volume)
  if self.start then
    self.start:setVolume(volume)
  end
  self.main:setVolume(volume)
end

function Music:getVolume()
  return self.main:getVolume()
end

function Music:setLooping(loop)
  self.main:setLooping(loop)
end

function Music:isLooping()
  return self.main:isLooping()
end

function Music:update()
  if not self.paused then
    if self.start and self.currentSource == self.start then
      if self.mainStartTime - love.timer.getTime() < 0.007 then
        self.currentSource = self.main
        self.currentSource:play()
        self.mainStartTime = nil
      end
    end
  end
end

return Music
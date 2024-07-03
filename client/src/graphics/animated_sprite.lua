local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
--local Signal = require("common.lib.signal")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")

local quad = love.graphics.newQuad
local tableInsert = table.insert
local floor = math.floor

Animation =
class(
  function (self, dur)
    self.frames = {}
    self.frameDuration = dur or 2
    self.loop = false
    self.loopStartFrame = 1
  end
)

function Animation:beginLoop()
  self.loop = true
  self.loopStartFrame = #self.frames+1
end

AnimatedSprite =
class(
  function(self, image, width, height, animations)
    --Signal.turnIntoEmitter(self)
    --self:createSignal("animSwitched")
    --self:createSignal("animEnded")
    --self:createSignal("animLooped")
    --self:createSignal("animStarted")

    self.image = image
    self.spriteSheet = love.graphics.newSpriteBatch(image)
    self.frameSize = {width = width, height = height}
    self.frameTime = 0
    self.currentFrame = 1
    self.loopCount = 0
    self.playing = false
    self.finished = false
    self.animations = animations or {}
    self.currentAnim = nil
    self.switchFunction = function() end
  end
)
function AnimatedSprite:addFrame(name, frame, duration)
  local imgW, imgH = self.image:getDimensions()
  local w = self.frameSize.width
  local h = self.frameSize.height
  local x = w*(frame-1)%imgW
  local y = h*floor(w*(frame-1)/imgW)
  tableInsert(self.animations[name].frames, {quad(x, y, w, h, imgW, imgH), duration})
end

function AnimatedSprite:setSwitchFunction(func)
  self.switchFunction = func
end

function AnimatedSprite:play()
  self.playing = true;
end
function AnimatedSprite:pause()
  self.playing = false;
end
function AnimatedSprite:stop()
  self.playing = false;
  self.currentFrame = 1;
  self.frameTime = 0;
  self.loopCount = 0;
end
function AnimatedSprite:goToFrame(frame)
  self.currentFrame = frame;
  self.frameTime = 0;
  self.loopCount = 0;
end

function AnimatedSprite:addAnimationPlayer(obj)
  obj.animation = self:clone()
end

function AnimatedSprite:update()
  self.switchFunction()
  local anim = self.animations[self.currentAnim]
  if anim.loop and self.finished then
    self.frameTime = 0
    self.currentFrame = anim.loopStartFrame
    self.loopCount = self.loopCount + 1
    self.finished = false
  end
  if (self.playing and not self.finished) then
    if (self.frameTime <= anim.frames[self.currentFrame][2]) then
      self.frameTime = self.frameTime + 1/anim.frameDuration
    elseif (self.currentFrame < #anim.frames) then
      self.frameTime = 0
      self.currentFrame = self.currentFrame + 1
    else
      self.finished = true
    end
  end
end

  function AnimatedSprite:draw(x, y, rot, x_scale, y_scale)
    GraphicsUtil.drawBatch(self.spriteSheet, self.animations[self.currentAnim].frames[self.currentFrame][1], x, y, rot, x_scale, y_scale)
  end
  
  function AnimatedSprite:qdraw(x, y, rot, x_scale, y_scale)
    GraphicsUtil.drawQuad(self.image, self.animations[self.currentAnim].frames[self.currentFrame][1], x, y, rot, x_scale, y_scale)
  end
  
  function AnimatedSprite:switchAnimation(selected, finish, frame)
    if self.currentAnim == selected then
        return
    end
    if (not finish) or self.finished then
      self.currentAnim = selected;
      self.currentFrame = (frame or 1);
      self.frameTime = 0;
      self.loopCount = 0;
    end
    --self:emitSignal("animSwitched", self.currentAnim)
  end

function AnimatedSprite.loadSpriteFromConfig(path, image)
  local config, msg = love.filesystem.read(path)
  if not config then return nil, msg end

  local width, height = string.match(config, "frameSize: %((%d+), (%d+)%)")
  local sprite = AnimatedSprite(image, tonumber(width), tonumber(height))
  for anim, name, duration in string.gmatch(config, "(%[(%a+)%,? ?(%d*)%].-end)") do
    sprite.animations[name] = Animation(tonumber(duration) or 2)
    for func, frame, dur in string.gmatch(anim, "(%a+)%(?(%d*),? ?(%d*)%)?") do
      if (func == "beginLoop") then
        sprite.animations[name]:beginLoop()
      end
      if (func == "addFrame") then
        sprite:addFrame(name, tonumber(frame), tonumber(dur) or 1)
      end
    end
  end
  return sprite
end

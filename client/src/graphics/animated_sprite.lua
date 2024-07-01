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
  function (self, width, height, imgW, imgH, dur)
    self.frames = {}
    self.frameSize = {width = width, height = height}
    self.imageSize = {width = imgW, height = imgH}
    self.frameDuration = dur or 2
    self.loop = false
    self.loopStartFrame = 1
    self.addFrame = function(frame, duration)
      local imW = self.imageSize.width
      local imH = self.imageSize.height
      local w = self.frameSize.width
      local h = self.frameSize.height
      local x = w*(frame-1)%imW
      local y = h*floor(w*(frame-1)/imW)
      tableInsert(self.frames, {quad(x, y, w, h, imW, imH), duration})
    end
    
    self.setLoopStart = function()
      self.loop = true;
      self.loopStartFrame = #self.frames
    end
    self.setLoopEnd = function()
      self.loop = true;
    end
    self.createAnimation = function(code)
      local env = {
        addFrame = self.addFrame,
        setLoopStart = self.setLoopStart,
        setLoopEnd = self.setLoopEnd,
      }
      local untrusted_function, message = load(code, nil, 't', env)
      if not untrusted_function then return nil, message end
        pcall(untrusted_function)
    end
  end
)

AnimatedSprite =
class(
  function(self, image, animations)
    --Signal.turnIntoEmitter(self)
    --self:createSignal("animSwitched")
    --self:createSignal("animEnded")
    --self:createSignal("animLooped")
    --self:createSignal("animStarted")

    self.image = image
    self.spriteSheet = love.graphics.newSpriteBatch(image)
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
  if (self.playing and not self.finished) then
    self.frameTime = self.frameTime + 1/anim.frameDuration

    if (self.frameTime > anim.frames[self.currentFrame][2]) then
      self.frameTime = 0
      self.currentFrame = self.currentFrame + 1
    end
    if (self.currentFrame > #anim.frames)  then
      if anim.loop then
        self.currentFrame = anim.loopStartFrame
        self.loopCount = self.loopCount + 1
        --self:emitSignal("animLooped", anim.loopCount)
      else
        self.finished = true
        self.currentFrame = #anim.frames
        --self:emitSignal("animEnded", self.finished)
      end
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
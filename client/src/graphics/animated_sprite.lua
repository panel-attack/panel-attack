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
  function (self, image, width, height, dur)
    self.image = image
    self.frameSize = {width = width, height = height}
    self.frames = {}
    self.frameDuration = dur or 2
    self.loop = false
    self.loopStartFrame = 1
  end
)

function Animation.addFrame(self, frame, length)
  local imgW, imgH = self.image:getDimensions()
  local w = self.frameSize.width
  local h = self.frameSize.height
  local x = w*(frame-1)%imgW
  local y = h*floor(w*(frame-1)/imgW)
  tableInsert(self.frames, {quad(x, y, w, h, imgW, imgH), length})
end
function Animation:beginLoop()
  self.loop = true
  self.loopStartFrame = #self.frames+1
end

AnimatedSprite =
class(
  function(self, animations, switchFunc)
    --Signal.turnIntoEmitter(self)
    --self:createSignal("animSwitched")
    --self:createSignal("animEnded")
    --self:createSignal("animLooped")
    --self:createSignal("animStarted")

    self.frameTime = 0
    self.currentFrame = 1
    self.loopCount = 0
    self.playing = false
    self.finished = false
    self.animations = animations or {}
    self.currentAnim = nil
    self.switchFunction = switchFunc or function() end
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

function AnimatedSprite:clone()
  return AnimatedSprite(self.animations, self.switchFunction)
end

function AnimatedSprite:update()
  local anim = self.animations[self.currentAnim]
  if not anim then return end;
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
  
  function AnimatedSprite:qdraw(x, y, rot, x_scale, y_scale)
    GraphicsUtil.drawQuad(self.animations[self.currentAnim].image, self.animations[self.currentAnim].frames[self.currentFrame][1], x, y, rot, x_scale, y_scale)
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

function AnimatedSprite.loadSpriteFromConfig(file)
  local config, msg = love.filesystem.read(file)
  if not config then return nil, msg end
  local dir = file:gsub("(.+)/.-$", "%1")
  local sprite = AnimatedSprite()
  local repeatHold = {}
  local repeatCount = nil
  for set, path, width, height in config:gmatch("(spritePath: *(%w+)%..-frameSize: *%((%d+), *(%d+)%).-})") do
    local image = GraphicsUtil.loadImageFromSupportedExtensions(dir.."/"..path)
    for anim, name, duration in set:gmatch("(%[(%a+),? *(%d*)%].-end)") do
      sprite.animations[name] = Animation(image, tonumber(width), tonumber(height), tonumber(duration) or 2)
      for func, frame, length in anim:gmatch("(%a+)%(?(%d*),? *(%d*)%)?") do
        if (func == "beginLoop") then
          sprite.animations[name]:beginLoop()
        end
        if (func == "addFrame") then
          if repeatCount then
            repeatHold[#repeatHold+1] = {tonumber(frame), tonumber(length) or 1}
          else
            sprite.animations[name]:addFrame(tonumber(frame), tonumber(length) or 1)
          end
        end
        if (func == "repeat") then
          repeatCount = tonumber(frame)
          repeatHold = {}
        end
        if (func == "closeRepeat") then
          for i = 1, repeatCount, 1 do
            for _, args in ipairs(repeatHold) do
              sprite.animations[name]:addFrame(args[1], args[2])
            end
          end
          repeatCount = nil
          repeatHold = {}
        end
      end
    end
  end
  return sprite
end

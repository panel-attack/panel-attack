local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")

local quad = love.graphics.newQuad
local tableInsert = table.insert
local floor = math.floor
local function createAnim(img, w, h, props)
  local newAnim = {
    durationPerFrame = (props.durationPerFrame or 2),
    loop = props.loop or true,
    frames = {}
  }
  local y = h*(props.row or 1) - h
  local x = 0
  for i in props.frames do
      if type(i) == "table" then
        x = w * i[1]
        for f = 1, i[2] do
          tableInsert(newAnim.quads, quad(x, y, w, h, img:getDimensions()))
        end
      else
        x = w * i
        tableInsert(newAnim.quads, quad(x, y, w, h, img:getDimensions()))
      end
      
  end
  return newAnim
end

AnimatedSprite =
class(
    function(self, image, color, panelSet, width, height)
        self.spriteSheet = love.graphics.newSpriteBatch(image)
        self.color = color
        self.size = {width = width, height = height}
        self.animations = {}
        for name, anim in pairs(panelSet) do
            if name ~= "filter" and name ~= "size" then
                self.animations[name] = createAnim(image, width, height, anim)
            end
        end
    end
)

function AnimatedSprite:getFrameQuad(name, frame)
    return self.animations[name].quads[frame]
end

function AnimatedSprite:getFrameSize()
    return self.size.width, self.size.height
end

function Animation(obj, animation)
  obj.currentAnim = "normal"
  obj.currentTime = 0
  obj.frame = 1
  obj.loop = true
  obj.finished = false
  obj.animation = animation
end

function AnimatedSprite:update(obj)
    obj.switchFunction()
    local anim = self.animations[obj.currentAnim]
    if ((obj.finished == false) or anim.loop) then
      if obj.finished then
        obj.currentTime = 0
        obj.finished = false
      end

      obj.currentTime = obj.currentTime + 1
  
      obj.frame = floor((obj.currentTime) / anim.durationPerFrame)
      if (obj.frame > #anim.frames)  then
        obj.finished = true;
      end
    end
  end

  function AnimatedSprite:draw(obj, x, y, rot, x_scale, y_scale)
    GraphicsUtil.drawBatch(self.spriteSheet, self.animations[obj.currentAnim].quads[obj.frame], x, y, rot, x_scale, y_scale)
  end
  
  function AnimatedSprite:qdraw(obj, x, y, rot, x_scale, y_scale)
    GraphicsUtil.drawQuad(self.spriteSheet:getTexture(), self.animations[obj.currentAnim].quads[obj.frame], x, y, rot, x_scale, y_scale)
  end
  
  function AnimatedSprite:switchAnimation(obj, selected, finish, frame)
    if obj.currentAnim == selected then
        return
    end
    if (finish ~= true) or obj.finished then
      obj.currentAnim = selected

      obj.currentTime = (frame or 1);
      obj.finished = false
    end
  end
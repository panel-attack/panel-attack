require("graphics_util")
require("util")
local consts = require("consts")
AnimatedSprite =
class(
    function(self, image, color, panelSet, width, height)
        local quad = love.graphics.newQuad
        local tabInsert = table.insert
        local function createAnim(img, w, h, props)
            local newAnim = {
                speed = (props.fps or 30)*consts.FRAME_RATE,
                loop = props.loop or true,
                quads = {}
            }
            local y = h*(props.row or 1) - h
            for i = 1, (props.frames or 1) do
                local x = w*(i) - w
                tabInsert(newAnim.quads, quad(x, y, w, h, img:getDimensions()))
            end
            return newAnim
        end

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
    obj.currentTime = 1
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
        obj.currentTime = 1
        obj.finished = false
      end
      obj.currentTime = obj.currentTime + anim.speed
  
      obj.frame = math.floor(wrap(1, obj.currentTime, #anim.quads))
      if (math.floor(obj.currentTime) > #anim.quads)  then
        obj.finished = true;
      end
    end
  end
  
  function AnimatedSprite:draw(obj, x, y, rot, x_scale, y_scale)
    drawBatch(self.spriteSheet, self.animations[obj.currentAnim].quads[obj.frame], x, y, rot, x_scale, y_scale)
  end
  
  function AnimatedSprite:qdraw(obj, x, y, rot, x_scale, y_scale)
    qdraw(self.spriteSheet:getTexture(), self.animations[obj.currentAnim].quads[obj.frame], x, y, rot, x_scale, y_scale)
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
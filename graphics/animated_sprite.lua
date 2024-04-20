require("graphics_util")
require("util")
local consts = require("consts")
AnimatedSprite = {}
function AnimatedSprite.newAnimation(image, data, color, panelSet, width, height)
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

    local newSprite =
    {
        spriteSheet = love.graphics.newSpriteBatch(image),
        spriteData = data,
        color = color,
        size = {width = width, height = height},
        animations = {}
    }
    for name, anim in pairs(panelSet) do
        if name ~= "filter" and name ~= "size" then
            newSprite.animations[name] = createAnim(image, width, height, anim)
        end
    end
    return newSprite
end

function AnimatedSprite.getFrameImage(self, name, frame)
    local qx, qy, qw, qh = self.animations[name].quads[frame]:getViewport()
    local img = love.image.newImageData(qw, qh)
    img.paste(img, self.spriteData, 0, 0, qx, qy, qw, qh)
    return love.graphics.newImage(img)
end

function AnimatedSprite.getFrameSize(self)
    return self.size.width, self.size.height
end
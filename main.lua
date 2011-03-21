socket = require("socket")
require("class")
require("queue")
require("globals")
require("engine")
require("graphics")
require("input")
require("network")
require("mainloop")

local NEXT_FRAME_TIME
local FRAME_STEP = 1/60

function love.load()
    mainloop = coroutine.create(fmainloop)
    NEXT_FRAME_TIME = love.timer.getTime()
end

function love.update()
    local now = love.timer.getTime()
    while NEXT_FRAME_TIME < now do
        local status, err = coroutine.resume(mainloop)
        if not status then
            error(err)
        end
        this_frame_keys = {}
        NEXT_FRAME_TIME = NEXT_FRAME_TIME + FRAME_STEP
    end
end

function love.draw()
    for i=gfx_q.first,gfx_q.last do
        gfx_q[i][1](unpack(gfx_q[i][2]))
    end
    -- love.graphics.print("FPS: "..love.timer.getFPS(),315,115)
end

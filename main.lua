socket = require("socket")

require("class")
require("queue")
require("globals")
require("engine")
require("graphics")
require("input")
require("network")
require("mainloop")

function love.load()
    math.randomseed(os.time(os.date("*t")))

    -- set resolution!
    love.graphics.setMode(820,615)

    graphics_init()     -- load images and set up stuff
    -- network_init()   -- we shouldn't set this up if we don't need it...
    -- input_init()     -- sets key repeat (well that was a bad idea)

    -- create mainloop coroutine
    mainloop = coroutine.create(fmainloop)
end

function love.draw()
    -- TODO: try to enforce 60fps even if we don't get vsync.
    local status, err = coroutine.resume(mainloop)
    if not status then
        error(err)
    end
    this_frame_keys = {}
end

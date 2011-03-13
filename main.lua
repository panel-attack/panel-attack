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
    network_init()      -- set up connection to server
    -- input_init()     -- sets key repeat (well that was a bad idea)

    -- create mainloop coroutine
    mainloop = coroutine.create(fmainloop)
end

function love.draw()
    local status, err = coroutine.resume(mainloop)
    if not status then
        error(err)
    end
end

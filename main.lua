function love.load()
    -- lol deterministic mode
    math.randomseed(10000)

    -- set resolution!
    love.graphics.setMode(820,615)

    -- load files!
    love.filesystem.load("class.lua")()
    love.filesystem.load("globals.lua")()
    love.filesystem.load("engine.lua")()
    love.filesystem.load("graphics.lua")()
    love.filesystem.load("input.lua")()

    -- load images and set up stuff
    graphics_init()
    -- sets key repeat (well that was a bad idea)
    -- input_init()

    P1 = Stack()

    -- create mainloop coroutine
    mainloop = coroutine.create(fmainloop)
end

--[[function draw_panel(id, row, col, stuff, junk)
    love.graphics.draw(IMG_panels[id], col*32*GFX_SCALE + 12,
            row*32*GFX_SCALE + 12, 0, GFX_SCALE, GFX_SCALE)
end--]]

function love.draw()
    coroutine.resume(mainloop)
    if(crash_now) then
        error(crash_error)
    end
    if(P1.game_over) then
        error("game over lol")
    end
end

function fmainloop()
    while true do
        local status, err = pcall(function ()
            --stage_background()
            P1:local_run()
        end)
        if not status then
            crash_error = err
            crash_now = true
        end
        coroutine.yield()
    end
end

GFX_SCALE = 3
FMODE = "nearest"
math.randomseed(10000)
function love.load()
    -- set resolution!
    love.graphics.setMode(820,615)

    -- load files!
    love.filesystem.load("class.lua")()
    love.filesystem.load("engine.lua")()
    love.filesystem.load("graphics.lua")()
    love.filesystem.load("input.lua")()

    -- load images and set up stuff
    graphics_init()
    -- sets key repeat (well that was a bad idea)
    -- input_init()

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
    if(P1_game_over) then
        error("game over lol")
    end
end

crash_now = false
crash_error = nil
CLOCK = 0

function fmainloop()
    local textpos = 0
    while true do
        local status, err = pcall(function ()
            controls()
            PdP()
            --stage_background()
            render_1P()
            love.graphics.draw(IMG_frame, 0, 0, 0, GFX_SCALE, GFX_SCALE)
--            love.graphics.print(_VERSION, textpos, 400)
            render_cursor()
            textpos = textpos+1
        end)
        if not status then
            crash_error = err
            crash_now = true
        end
        CLOCK = CLOCK + 1
        coroutine.yield()
    end
end


GFX_SCALE = 1.5
FMODE = "nearest"

function love.load()
    -- set resolution!
    love.graphics.setMode(820,615)

    -- load files!
    love.filesystem.load("class.lua")()
    love.filesystem.load("engine.lua")()
    love.filesystem.load("graphics.lua")()

    -- load images and set up stuff
    graphics_init()
end

function draw_panel(id, row, col, stuff, junk)
    love.graphics.draw(IMG_panels[id], col*32*GFX_SCALE + 12,
            row*32*GFX_SCALE + 12, 0, GFX_SCALE, GFX_SCALE)
end

function love.draw()
    love.graphics.draw(IMG_frame, 0, 0, 0, GFX_SCALE, GFX_SCALE)
    love.graphics.print(_VERSION, 400, 400)
end

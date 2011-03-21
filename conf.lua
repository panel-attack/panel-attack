function love.conf(t)
    t.title = "Panel Attack"
    t.author = "sharpobject@gmail.com"
    t.screen.width = 820
    t.screen.height = 615
    t.modules.joystick = false
    t.modules.audio = false
    t.modules.mouse = false
    t.modules.sound = false
    t.modules.physics = false
    t.screen.vsync = false       -- Enable vertical sync (boolean)

    -- DEFAULTS FROM HERE DOWN
    t.screen.fullscreen = false -- Enable fullscreen (boolean)
    t.screen.fsaa = 0           -- The number of FSAA-buffers (number)
    t.identity = nil            -- The name of the save directory (string)
    t.version = 0               -- The LÖVE version this game was made for (number)
    t.console = false           -- Attach a console (boolean, Windows only)
    t.modules.timer = true      -- Enable the timer module (boolean)
    t.modules.image = true      -- Enable the image module (boolean)
    t.modules.graphics = true   -- Enable the graphics module (boolean)
    t.modules.keyboard = true   -- Enable the keyboard module (boolean)
    t.modules.event = true
end

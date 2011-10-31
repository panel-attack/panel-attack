function love.conf(t)
  t.title = "Panel Attack"
  t.author = "sharpobject@gmail.com"
  t.screen.width = 819
  t.screen.height = 612
  t.modules.audio = false
  t.modules.mouse = true
  t.modules.sound = false
  t.modules.physics = false
  t.identity = "Panel Attack"

  -- DEFAULTS FROM HERE DOWN
  t.screen.vsync = true       -- Enable vertical sync (boolean)
  t.screen.fullscreen = false -- Enable fullscreen (boolean)
  t.screen.fsaa = 0           -- The number of FSAA-buffers (number)
  t.version = 0               -- The LÖVE version this game was made for (number)
  t.console = false           -- Attach a console (boolean, Windows only)
  t.modules.joystick = true
  t.modules.timer = true      -- Enable the timer module (boolean)
  t.modules.image = true      -- Enable the image module (boolean)
  t.modules.graphics = true   -- Enable the graphics module (boolean)
  t.modules.keyboard = true   -- Enable the keyboard module (boolean)
  t.modules.event = true
end

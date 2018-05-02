require("consts")

function love.conf(t)
  t.title = "Panel Attack"
  t.author = "sharpobject@gmail.com"
  t.url = "https://github.com/sharpobject/panel-attack"
  t.window.width = default_width
  t.window.height = default_height
  t.window.resizable = true
  t.modules.audio = true
  t.modules.mouse = true
  t.modules.sound = true
  t.modules.physics = false
  t.identity = "Panel Attack"
  t.version = "0.9.0"
  t.release = false
  t.externalstorage = true

  -- DEFAULTS FROM HERE DOWN
  local window = t.window or t.screen
  window.vsync = true       -- Enable vertical sync (boolean)
  window.fullscreen = false -- Enable fullscreen (boolean)
  window.fsaa = 0           -- The number of FSAA-buffers (number)
  t.console = false           -- Attach a console (boolean, Windows only)
  t.modules.joystick = true
  t.modules.timer = true      -- Enable the timer module (boolean)
  t.modules.image = true      -- Enable the image module (boolean)
  t.modules.graphics = true   -- Enable the graphics module (boolean)
  t.modules.keyboard = true   -- Enable the keyboard module (boolean)
  t.modules.event = true
end

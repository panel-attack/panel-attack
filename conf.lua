require("client.src.developer") -- Require developer here as this is basically the first thing to load in love 2D
require("client.src.config") -- We need to setup the config save data so we can setup the window properties right from the start when love asks for them

function love.conf(t)
  -- Set the identity before loading the config file
  -- as we need it set to get to the correct load directory.
  love.filesystem.setIdentity("Panel Attack")
  readConfigFile(config)

  --t.identity = "" -- (already set above) -- The name of the save directory (string)
  t.appendidentity = false            -- Search files in source directory before save directory (boolean)
  t.version = "12.0"                  -- The LÖVE version this game was made for (string)
  t.console = false                   -- Attach a console (boolean, Windows only)
  t.accelerometerjoystick = false     -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
  t.externalstorage = true
  t.gammacorrect = false              -- Enable gamma-correct rendering, when supported by the system (boolean)
  t.highdpi = true                  -- Enable high-dpi mode for the window on a Retina display (boolean)


  t.audio.mic = false                 -- Request and use microphone capabilities in Android (boolean)
  t.audio.mixwithsystem = false       -- Keep background music playing when opening LOVE (boolean, iOS and Android only)

  t.window.title = "Panel Attack"          -- The window title (string)
  t.window.icon = "client/assets/panels/__default/panel11.png"                      -- Filepath to an image to use as the window's icon (string)
  t.window.width = config.windowWidth            -- The window width (number)
  t.window.height = config.windowHeight          -- The window height (number)
  t.window.borderless = config.borderless  -- Remove all border visuals from the window (boolean)
  t.window.resizable = true                -- Let the window be user-resizable (boolean)
  t.window.minwidth = 1                    -- Minimum window width if the window is resizable (number)
  t.window.minheight = 1                   -- Minimum window height if the window is resizable (number)
  t.window.fullscreen = config.fullscreen  -- Enable fullscreen (boolean)
  t.window.fullscreentype = "desktop"      -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
  t.window.vsync = 0            -- Vertical sync mode (number)
  t.window.msaa = 0                        -- The number of samples to use with multi-sampled antialiasing (number)
  t.window.depth = nil                     -- The number of bits per sample in the depth buffer
  t.window.stencil = nil                   -- The number of bits per sample in the stencil buffer
  t.window.displayindex = config.display        -- Index of the monitor to show the window in (number)
  t.window.usedpiscale = false             -- Enable automatic DPI scaling when highdpi is set to true as well (boolean)
  t.window.x = config.windowX              -- The x-coordinate of the window's position in the specified display (number)
  t.window.y = config.windowY              -- The y-coordinate of the window's position in the specified display (number)

  t.modules.audio = true              -- Enable the audio module (boolean)
  t.modules.data = true               -- Enable the data module (boolean)
  t.modules.event = true              -- Enable the event module (boolean)
  t.modules.font = true               -- Enable the font module (boolean)
  t.modules.graphics = true           -- Enable the graphics module (boolean)
  t.modules.image = true              -- Enable the image module (boolean)
  t.modules.joystick = true           -- Enable the joystick module (boolean)
  t.modules.keyboard = true           -- Enable the keyboard module (boolean)
  t.modules.math = true               -- Enable the math module (boolean)
  t.modules.mouse = true              -- Enable the mouse module (boolean)
  t.modules.physics = false           -- Enable the physics module (boolean)
  t.modules.sound = true              -- Enable the sound module (boolean)
  t.modules.system = true             -- Enable the system module (boolean)
  t.modules.thread = true             -- Enable the thread module (boolean)
  t.modules.timer = true              -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
  t.modules.touch = true              -- Enable the touch module (boolean)
  t.modules.video = false             -- Enable the video module (boolean)
  t.modules.window = true             -- Enable the window module (boolean)
end

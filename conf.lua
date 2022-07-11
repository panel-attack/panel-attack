require("developer")
json = require("dkjson")
require("consts")
require("globals")

-- Default configuration values
config = {
  -- The last used engine version
  version                       = VERSION,

    -- Lang used for localization
  language_code                 = "EN",

  theme                         = default_theme_dir,
  panels                     	  = nil, -- setup later in panel init
  character                     = random_character_special_value,
  stage                         = random_stage_special_value,

  ranked                        = true,

  use_music_from                = "either",
  -- Level (2P modes / 1P vs yourself mode)
  level                         = 5,
  endless_speed                 = 1,
  endless_difficulty            = 1,
  endless_level                 = nil, -- nil indicates we want to use classic difficulty

  puzzle_level                  = 5,
  puzzle_randomColors           = false,

  -- Player name
  name                          = "defaultname",
  -- Volume settings
  master_volume                 = 100,
  SFX_volume                    = 100,
  music_volume                  = 100,
  -- Debug mode flag
  debug_mode                    = false,
  -- Show FPS in the top-left corner of the screen
  show_fps                      = false,
  -- Show ingame infos while playing the game
  show_ingame_infos             = true,
  -- Enable ready countdown flag
  ready_countdown_1P            = true,
  -- Change danger music back later flag
  danger_music_changeback_delay = false,
  input_repeat_delay            = default_input_repeat_delay,
  -- analytics
  enable_analytics              = true,
  -- Save replays setting
  save_replays_publicly         = "with my name",
  portrait_darkness             = default_portrait_darkness,
  popfx                         = true,
  cardfx_scale                  = 100,
  renderTelegraph               = true,
  renderAttacks                 = true,
  defaultPanelsCopied           = false,

  -- True if we immediately want to maximize the screen on startup
  maximizeOnStartup             = true,

  -- Love configuration variables
  width                         = canvas_width,
  height                        = canvas_height,
  borderless                    = false,
  fullscreen                    = false,
  vsync                         = 1,
  display                       = 1,
  window_x                      = nil,
  window_y                      = nil,
}

-- writes to the "conf.json" file
function write_conf_file()
  pcall(
    function()
      local file = love.filesystem.newFile("conf.json")
      file:open("w")
      file:write(json.encode(config))
      file:close()
    end
  )
end

local use_music_from_values = {stage = true, often_stage = true, either = true, often_characters = true, characters = true}
local save_replays_values = {["with my name"] = true, anonymously = true, ["not at all"] = true}

-- reads the "conf.json" file and overwrites the values into the passed in table
function readConfigFile(configTable)
  pcall(
    function()
      -- config current values are defined in globals.lua,
      -- we consider those values are currently in config

      local file = love.filesystem.newFile("conf.json")
      file:open("r")
      local read_data = {}
      local teh_json = file:read(file:getSize())
      for k, v in pairs(json.decode(teh_json)) do
        read_data[k] = v
      end

      -- do stuff using read_data.version for retrocompatibility here

      if type(read_data.theme) == "string" and love.filesystem.getInfo("themes/" .. read_data.theme) then
        configTable.theme = read_data.theme
      end

      -- language_code, panels, character and stage are patched later on by their own subsystems, we store their values in config for now!
      if type(read_data.language_code) == "string" then
        configTable.language_code = read_data.language_code
      end
      if type(read_data.panels) == "string" then
        configTable.panels = read_data.panels
      end
      if type(read_data.character) == "string" then
        configTable.character = read_data.character
      end
      if type(read_data.stage) == "string" then
        configTable.stage = read_data.stage
      end

      if type(read_data.ranked) == "boolean" then
        configTable.ranked = read_data.ranked
      end

      if type(read_data.use_music_from) == "string" and use_music_from_values[read_data.use_music_from] then
        configTable.use_music_from = read_data.use_music_from
      end

      if type(read_data.level) == "number" then
        configTable.level = bound(1, read_data.level, 10)
      end
      if type(read_data.endless_speed) == "number" then
        configTable.endless_speed = bound(1, read_data.endless_speed, 99)
      end
      if type(read_data.endless_difficulty) == "number" then
        configTable.endless_difficulty = bound(1, read_data.endless_difficulty, 3)
      end
      if type(read_data.endless_level) == "number" then
        configTable.endless_level = bound(1, read_data.endless_level, 11)
      end
      if type(read_data.puzzle_level) == "number" then
        configTable.puzzle_level = bound(1, read_data.puzzle_level, 11)
      end
      if type(read_data.puzzle_randomColors) == "boolean" then
        configTable.puzzle_randomColors = read_data.puzzle_randomColors
      end

      if type(read_data.name) == "string" then
        configTable.name = read_data.name
      end

      if type(read_data.master_volume) == "number" then
        configTable.master_volume = bound(0, read_data.master_volume, 100)
      end
      if type(read_data.SFX_volume) == "number" then
        configTable.SFX_volume = bound(0, read_data.SFX_volume, 100)
      end
      if type(read_data.music_volume) == "number" then
        configTable.music_volume = bound(0, read_data.music_volume, 100)
      end
      if type(read_data.input_repeat_delay) == "number" then
        configTable.input_repeat_delay = bound(1, read_data.input_repeat_delay, 50)
      end
      if type(read_data.debug_mode) == "boolean" then
        configTable.debug_mode = read_data.debug_mode
      end
      if type(read_data.show_fps) == "boolean" then
        configTable.show_fps = read_data.show_fps
      end
      if type(read_data.show_ingame_infos) == "boolean" then
        configTable.show_ingame_infos = read_data.show_ingame_infos
      end
      if type(read_data.ready_countdown_1P) == "boolean" then
        configTable.ready_countdown_1P = read_data.ready_countdown_1P
      end
      if type(read_data.danger_music_changeback_delay) == "boolean" then
        configTable.danger_music_changeback_delay = read_data.danger_music_changeback_delay
      end
      if type(read_data.enable_analytics) == "boolean" then
        configTable.enable_analytics = read_data.enable_analytics
      end
      if type(read_data.save_replays_publicly) == "string" and save_replays_values[read_data.save_replays_publicly] then
        configTable.save_replays_publicly = read_data.save_replays_publicly
      end
      if type(read_data.portrait_darkness) == "number" then
        configTable.portrait_darkness = bound(0, read_data.portrait_darkness, 100)
      end
      if type(read_data.popfx) == "boolean" then
        configTable.popfx = read_data.popfx
      end
      if type(read_data.cardfx_scale) == "number" then
        configTable.cardfx_scale = bound(1, read_data.cardfx_scale, 200)
      end
      if type(read_data.renderTelegraph) == "boolean" then
        configTable.renderTelegraph = read_data.renderTelegraph
      end
      if type(read_data.renderAttacks) == "boolean" then
        configTable.renderAttacks = read_data.renderAttacks
      end
      if type(read_data.defaultPanelsCopied) == "boolean" then
        configTable.defaultPanelsCopied = read_data.defaultPanelsCopied
      end

      if type(read_data.maximizeOnStartup) == "boolean" then
        configTable.maximizeOnStartup = read_data.maximizeOnStartup
      end

      if type(read_data.width) == "number" then
        configTable.width = read_data.width
      end
      if type(read_data.height) == "number" then
        configTable.height = read_data.height
      end
      if type(read_data.borderless) == "boolean" then
        configTable.borderless = read_data.borderless
      end
      if type(read_data.fullscreen) == "boolean" then
        configTable.fullscreen = read_data.fullscreen
      end
      if type(read_data.vsync) == "boolean" then
        configTable.vsync = read_data.vsync
      end
      if type(read_data.display) == "number" then
        configTable.display = read_data.display
      end
      if type(read_data.window_x) == "number" then
        configTable.window_x = read_data.window_x
      end
      if type(read_data.window_y) == "number" then
        configTable.window_y = read_data.window_y
      end

      file:close()
    end
  )
end

function love.conf(t)
  local identityString = "Panel Attack"

  -- Set the identity before loading the config file
  -- as we need it set to get to the correct save directory.
  love.filesystem.setIdentity(identityString)
  readConfigFile(config)

  --t.identity = ""                     -- The name of the save directory (string)
  t.appendidentity = false            -- Search files in source directory before save directory (boolean)
  t.version = "11.3"                  -- The LÖVE version this game was made for (string)
  t.console = false                   -- Attach a console (boolean, Windows only)
  t.accelerometerjoystick = false     -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
  t.externalstorage = false           -- True to save files (and read from the save directory) in external storage on Android (boolean) 
  t.gammacorrect = false              -- Enable gamma-correct rendering, when supported by the system (boolean)

  t.audio.mic = false                 -- Request and use microphone capabilities in Android (boolean)
  t.audio.mixwithsystem = false       -- Keep background music playing when opening LOVE (boolean, iOS and Android only)

  t.window.title = "Panel Attack"          -- The window title (string)
  t.window.icon = nil                      -- Filepath to an image to use as the window's icon (string)
  t.window.width = config.width            -- The window width (number)
  t.window.height = config.height          -- The window height (number)
  t.window.borderless = config.borderless  -- Remove all border visuals from the window (boolean)
  t.window.resizable = true                -- Let the window be user-resizable (boolean)
  t.window.minwidth = 1                    -- Minimum window width if the window is resizable (number)
  t.window.minheight = 1                   -- Minimum window height if the window is resizable (number)
  t.window.fullscreen = config.fullscreen  -- Enable fullscreen (boolean)
  t.window.fullscreentype = "desktop"      -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
  t.window.vsync = config.vsync            -- Vertical sync mode (number)
  t.window.msaa = 0                        -- The number of samples to use with multi-sampled antialiasing (number)
  t.window.depth = nil                     -- The number of bits per sample in the depth buffer
  t.window.stencil = nil                   -- The number of bits per sample in the stencil buffer
  t.window.display = config.display        -- Index of the monitor to show the window in (number)
  t.window.highdpi = false                 -- Enable high-dpi mode for the window on a Retina display (boolean)
  t.window.usedpiscale = true              -- Enable automatic DPI scaling when highdpi is set to true as well (boolean)
  t.window.x = config.window_x             -- The x-coordinate of the window's position in the specified display (number)
  t.window.y = config.window_y             -- The y-coordinate of the window's position in the specified display (number)

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

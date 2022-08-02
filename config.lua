local consts = require("consts")

---@module config
-- Default configuration values
local config = {
  -- The lastly used version
  version                       = consts.VERSION,

  -- Lang used for localization
  language_code                 = "EN",

  theme                         = consts.DEFAULT_THEME_DIR,
  panels                     	  = nil,
  character                     = consts.RANDOM_CHARACTER_SPECIAL_VALUE,
  stage                         = consts.RANDOM_STAGE_SPECIAL_VALUE,

  ranked                        = true,

  vsync                         = false,

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
  input_repeat_delay            = consts.DEFAULT_INPUT_REPEAT_DELAY,
  -- analytics
  enable_analytics              = true,
  -- Save replays setting
  save_replays_publicly         = "with my name",
  portrait_darkness             = 70,
  popfx                         = true,
  cardfx_scale                  = 100,
  
  renderTelegraph               = true,
  renderAttacks                 = true,
  defaultPanelsCopied           = false,
  
  -- True if we immediately want to maximize the screen on startup
  maximizeOnStartup             = true,
  gameScaleType                 = "auto",
  gameScaleFixedValue           = 2,
  
  -- Love configuration variables
  windowWidth                   = consts.CANVAS_WIDTH,
  windowHeight                  = consts.CANVAS_HEIGHT,
  borderless                    = false,
  fullscreen                    = false,
  vsync                         = 1,
  display                       = 1,
  windowX                       = nil,
  windowY                       = nil,
}

return config
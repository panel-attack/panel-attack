json = require("common.lib.dkjson")
local util = require("common.lib.util")
local fileUtils = require("client.src.FileUtils")
local consts = require("common.engine.consts")
require("client.src.globals")

-- Default configuration values
config = {
    -- The last used engine version
    version                       = consts.ENGINE_VERSION,

      -- Lang used for localization
    language_code                 = "EN",

    -- Last selected theme, panels, character and stage
    theme                         = consts.DEFAULT_THEME_DIRECTORY,
    panels                     	  = nil, -- setup later in panel init
    character                     = consts.RANDOM_CHARACTER_SPECIAL_VALUE,
    stage                         = consts.RANDOM_STAGE_SPECIAL_VALUE,

    -- Last choice for ranked and input method
    ranked                        = true,
    inputMethod                   = "controller",

    use_music_from                = "either",

    -- Level (2P modes / 1P vs yourself mode)
    level                         = 5,

    -- Endless / Time Attack settings
    endless_speed                 = 1,
    endless_difficulty            = 1,
    endless_level                 = nil, -- nil indicates we want to use classic difficulty

    -- Puzzle settings
    puzzle_level                  = 5,
    puzzle_randomColors           = false,
    puzzle_randomFlipped          = false,

    -- Player name
    name                          = "",
    -- Volume settings
    master_volume                 = 50,
    SFX_volume                    = 100,
    music_volume                  = 100,
    -- Debug mode flag
    debug_mode                    = false,
    debugShowServers              = false,
    debugShowDesignHelper         = false,
    -- Show FPS in the top-left corner of the screen
    show_fps                      = false,
    -- controls how much of the remaining time after a frame is run is used for active garbage collection
    activeGarbageCollectionPercent = 0.2,
    -- Show ingame infos while playing the game
    show_ingame_infos             = true,
    -- Change danger music back later flag
    danger_music_changeback_delay = false,
    -- analytics
    enable_analytics              = true,
    -- Save replays setting
    save_replays_publicly         = "with my name",
    -- Darkness of the background portrait
    portrait_darkness             = 70,
    -- Whether to show the popfx from panels
    popfx                         = true,
    -- Multiplier for the intensity of the shake animation when garbage falls
    shakeIntensity = 1,
    -- Not currently settable in game, spacing of popfx
    cardfx_scale                  = 100,
    -- Whether to render the telegraph
    renderTelegraph               = true,
    -- Whether to render the attacks that come from the panels
    renderAttacks                 = true,
    -- Tracks if the default panels have been copied over yet
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
    display                       = 1,
    windowX                       = nil,
    windowY                       = nil,
  }

  -- writes to the "conf.json" file
  function write_conf_file()
    pcall(
      function()
        love.filesystem.write("conf.json", json.encode(config))
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

        local read_data = fileUtils.readJsonFile("conf.json")

        if read_data then
          -- do stuff using read_data.version for retrocompatibility here

          if type(read_data.theme) == "string" and love.filesystem.getInfo(THEME_DIRECTORY_PATH .. read_data.theme .. "/config.json") then
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

          if type(read_data.inputMethod) == "string" then
            configTable.inputMethod = read_data.inputMethod
          end

          if type(read_data.use_music_from) == "string" and use_music_from_values[read_data.use_music_from] then
            configTable.use_music_from = read_data.use_music_from
          end

          if type(read_data.level) == "number" then
            configTable.level = util.bound(1, read_data.level, 10)
          end
          if type(read_data.endless_speed) == "number" then
            configTable.endless_speed = util.bound(1, read_data.endless_speed, 99)
          end
          if type(read_data.endless_difficulty) == "number" then
            configTable.endless_difficulty = util.bound(1, read_data.endless_difficulty, 3)
          end
          if type(read_data.endless_level) == "number" then
            configTable.endless_level = util.bound(1, read_data.endless_level, 11)
          end
          if type(read_data.puzzle_level) == "number" then
            configTable.puzzle_level = util.bound(1, read_data.puzzle_level, 11)
          end
          if type(read_data.puzzle_randomColors) == "boolean" then
            configTable.puzzle_randomColors = read_data.puzzle_randomColors
          end
          if type(read_data.puzzle_randomFlipped) == "boolean" then
            configTable.puzzle_randomFlipped = read_data.puzzle_randomFlipped
          end

          if type(read_data.name) == "string" then
            configTable.name = read_data.name
          end

          if type(read_data.master_volume) == "number" then
            configTable.master_volume = util.bound(0, read_data.master_volume, 100)
          end
          if type(read_data.SFX_volume) == "number" then
            configTable.SFX_volume = util.bound(0, read_data.SFX_volume, 100)
          end
          if type(read_data.music_volume) == "number" then
            configTable.music_volume = util.bound(0, read_data.music_volume, 100)
          end
          if type(read_data.debug_mode) == "boolean" then
            configTable.debug_mode = read_data.debug_mode
          end
          if type(read_data.debugShowServers) == "boolean" then
            configTable.debugShowServers = read_data.debugShowServers
          end
          if type(read_data.debugShowDesignHelper) == "boolean" then
            configTable.debugShowDesignHelper = read_data.debugShowDesignHelper
          end
          if type(read_data.show_fps) == "boolean" then
            configTable.show_fps = read_data.show_fps
          end
          if type(read_data.show_ingame_infos) == "boolean" then
            configTable.show_ingame_infos = read_data.show_ingame_infos
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
            configTable.portrait_darkness = util.bound(0, read_data.portrait_darkness, 100)
          end
          if type(read_data.popfx) == "boolean" then
            configTable.popfx = read_data.popfx
          end
          if type(read_data.shakeIntensity) == "number" then
            configTable.shakeIntensity = util.bound(0.5, read_data.shakeIntensity, 1)
          end
          if type(read_data.cardfx_scale) == "number" then
            configTable.cardfx_scale = util.bound(1, read_data.cardfx_scale, 200)
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
          if type(read_data.gameScaleType) == "string" then
            configTable.gameScaleType = read_data.gameScaleType
          end
          if type(read_data.gameScaleFixedValue) == "number" then
            configTable.gameScaleFixedValue = read_data.gameScaleFixedValue
          end

          if type(read_data.windowWidth) == "number" then
            configTable.windowWidth = read_data.windowWidth
          end
          if type(read_data.windowHeight) == "number" then
            configTable.windowHeight = read_data.windowHeight
          end
          if type(read_data.borderless) == "boolean" then
            configTable.borderless = read_data.borderless
          end
          if type(read_data.fullscreen) == "boolean" then
            configTable.fullscreen = read_data.fullscreen
          end
          if type(read_data.display) == "number" then
            configTable.display = read_data.display
          end
        

          if type(read_data.activeGarbageCollectionPercent) == "number" then
            config.activeGarbageCollectionPercent = util.bound(0.1, read_data.activeGarbageCollectionPercent, 0.8)
          end
        end

      end
    )
  end

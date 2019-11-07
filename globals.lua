require("consts")
require("queue")

-- keyboard assignment vars
K = {{up="up", down="down", left="left", right="right",
      swap1="z", swap2="x", raise1="c", raise2="v"},
      {},{},{}}
keys = {}
this_frame_keys = {}
this_frame_unicodes = {}
this_frame_messages = {}

score_mode = SCOREMODE_TA

gfx_q = Queue()

characters = {} -- initialized in character.lua
characters_ids = {} -- initialized in character.lua
characters_ids_for_current_theme = {} -- initialized in character.lua
characters_ids_by_display_names = {} -- initialized in character.lua

stages = {} -- initialized in stage.lua
stages_ids = {} -- initialized in stage.lua
stages_ids_for_current_theme = {} -- initialized in stage.lua
stages_ids_by_display_names = {} -- initialized in stage.lua

current_stage = nil

-- win counters
my_win_count = 0
op_win_count = 0

global_my_state = nil
global_op_state = nil

main_font = love.graphics.getFont()
main_font:setFilter("nearest", "nearest")
small_font = love.graphics.newFont(9)
small_font:setFilter("nearest", "nearest")

  -- Default configuration values
config = {
	-- The lastly used version
	version                       = VERSION,

	theme                         = default_theme_dir,
	panels                        = default_panels_dir,
	character                     = "lip",
	stage                         = random_stage_special_value,

	use_music_from                = "stage",
	-- Level (2P modes / 1P vs yourself mode)
	level                         = 5,
	endless_speed                 = 1,
	endless_difficulty            = 1,
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
	-- Enable ready countdown flag
	ready_countdown_1P            = true,
	-- Change danger music back later flag
	danger_music_changeback_delay = false,
	-- analytics
	enable_analytics              = false,
	-- Save replays setting
	save_replays_publicly         = "with my name",
}
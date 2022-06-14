require("consts")
require("queue")
require("server_queue")
require("sound_util")

-- keyboard assignment vars
keys = {}
this_frame_keys = {}
this_frame_released_keys = {}
this_frame_unicodes = {}
this_frame_messages = {}

server_queue = ServerQueue()

score_mode = SCOREMODE_TA
 
GARBAGE_TELEGRAPH_TIME = 45 -- the amount of time the garbage stays in the telegraph after getting there from the attack animation
GARBAGE_DELAY_LAND_TIME = 60 -- this is the amount of time after garbage leaves the telegraph before it can land on the opponent
						  -- a higher value allows less rollback to happen and makes lag have less of an impact on the game
						  -- technically this was 0 in classic games, but we are using this value to make rollback less noticable and match PA history
GARBAGE_TRANSIT_TIME = 45 -- the amount of time the garbage attack animation plays before getting to the telegraph
MAX_LAG = 200 + GARBAGE_TELEGRAPH_TIME -- maximum amount of lag before net games abort

gfx_q = Queue()

themes = {} -- initialized in theme.lua

characters = {} -- initialized in character.lua
characters_ids = {} -- initialized in character.lua
characters_ids_for_current_theme = {} -- initialized in character.lua
characters_ids_by_display_names = {} -- initialized in character.lua

stages = {} -- initialized in stage.lua
stages_ids = {} -- initialized in stage.lua
stages_ids_for_current_theme = {} -- initialized in stage.lua

panels = {} -- initialized in panels.lua
panels_ids = {} -- initialized in panels.lua

trainings = {} -- used in save.lua for training mode files

current_stage = nil

replay = {}

-- sfx play
SFX_Fanfare_Play = 0
SFX_GarbageThud_Play = 0
SFX_GameOver_Play = 0

global_op_state = nil

large_font = 10 -- large font base+10
small_font = -3 -- small font base-3

default_input_repeat_delay = 20
default_portrait_darkness = 70

zero_sound = load_sound_from_supported_extensions("zero_music")

  -- Default configuration values
config = {
	-- The lastly used version
	version                       = VERSION,

	 -- Lang used for localization
	language_code                 = "EN",

	theme                         = default_theme_dir,
	panels                     	  = default_panels_dir,
	character                     = random_character_special_value,
	stage                         = random_stage_special_value,

	ranked                        = true,

	vsync                         = false,

	use_music_from                = "either",
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
	renderAttacks                 = true
}

current_use_music_from = "stage" -- either "stage" or "characters", no other values!

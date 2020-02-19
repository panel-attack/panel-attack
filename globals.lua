require("consts")
require("queue")
require("server_queue")
require("sound_util")

-- keyboard assignment vars
K = {{up="up", down="down", left="left", right="right",
      swap1="z", swap2="x", taunt_up="y", taunt_down="u", raise1="c", raise2="v", pause="p"},
      {},{},{}}
keys = {}
this_frame_keys = {}
this_frame_released_keys = {}
this_frame_unicodes = {}
this_frame_messages = {}
server_queue = ServerQueue(20)

score_mode = SCOREMODE_TA

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

current_stage = nil

background_overlay = nil
foreground_overlay = nil

-- win counters
my_win_count = 0
op_win_count = 0

-- sfx play
SFX_Fanfare_Play = 0
SFX_GarbageThud_Play = 0
SFX_GameOver_Play = 0

global_my_state = nil
global_op_state = nil

-- Warning messages
display_warning_message = false

-- game can be paused while playing on local
game_is_paused = false

large_font = 10 -- large font base+10
small_font = -3 -- small font base-3

default_input_repeat_delay = 20

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

	vsync                         = true,

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
	show_ingame_infos             = false,
	-- Enable ready countdown flag
	ready_countdown_1P            = true,
	-- Change danger music back later flag
	danger_music_changeback_delay = false,
  	input_repeat_delay            = default_input_repeat_delay,
	-- analytics
	enable_analytics              = false,
	-- Save replays setting
	save_replays_publicly         = "with my name",
}

current_use_music_from = "stage" -- either "stage" or "characters", no other values!

function warning(msg)
	err = "=================================================================\n["..os.date("%x %X").."]\nError: "..msg..debug.traceback("").."\n"
	love.filesystem.append("warnings.txt", err)
	if display_warning_message then
		display_warning_message = false
		local loc_warning = "You've had a bug. Please report this on Discord with file:"
		if loc ~= nil then
			local str = loc("warning_msg")
			if str:sub(1, 1) ~= "#" then
				loc_warning = str
			end
		end
		love.window.showMessageBox("Warning", loc_warning.."\n%appdata%\\Panel Attack\\warnings.txt")
	end
end
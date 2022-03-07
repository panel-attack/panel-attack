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

replay = {}

-- sfx play
SFX_Fanfare_Play = 0
SFX_GarbageThud_Play = 0
SFX_GameOver_Play = 0

global_my_state = nil
global_op_state = nil

-- Warning messages
display_warning_message = false

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
	panels                     	  			= default_panels_dir,
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
}

current_use_music_from = "stage" -- either "stage" or "characters", no other values!

function warning(msg)
	err = "=================================================================\n["..os.date("%x %X").."]\nError: "..msg..debug.traceback("").."\n"
	love.filesystem.append("warnings.txt", err)
	print(err)
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

require("consts")
require("sound_util")

-- keyboard assignment vars
keys = {}
this_frame_keys = {}
this_frame_released_keys = {}
this_frame_unicodes = {}
this_frame_messages = {}

score_mode = SCOREMODE_TA

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

zero_sound = load_sound_from_supported_extensions("zero_music")

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

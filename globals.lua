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

server_queue = ServerQueue()

score_mode = SCOREMODE_TA
   
TELEGRAPH_HEIGHT = 16
TELEGRAPH_PADDING = 2 --vertical space between telegraph and stack
TELEGRAPH_BLOCK_WIDTH = 24
TELEGRAPH_ATTACK_MAX_SPEED = 8 --fastest an attack can travel toward the telegraph per frame
--The telegraph_attack_animation below refers the little loop shape attacks make before they start traveling toward the target.
telegraph_attack_animation_speed = {
    4,4,4,4,4,2,2,2,2,1,
    1,1,1,.5,.5,.5,.5,1,1,1,
    1,2,2,2,2,4,4,4,4,8}

--the following are angles out of 64, 0 being right, 32 being left, 16 being down, and 48 being up.
telegraph_attack_animation_angles = {}
--[1] for attacks where the destination is right of the origin

telegraph_attack_animation_angles[1] = {}
for i=24,24+#telegraph_attack_animation_speed-1 do
  telegraph_attack_animation_angles[1][#telegraph_attack_animation_angles[1]+1] = i%64
end
--[-1] for attacks where the destination is left of the origin
telegraph_attack_animation_angles[-1] = {}
local leftward_animation_angle = 8
while #telegraph_attack_animation_angles[-1] <= #telegraph_attack_animation_speed do
  telegraph_attack_animation_angles[-1][#telegraph_attack_animation_angles[-1]+1] = leftward_animation_angle
  leftward_animation_angle = leftward_animation_angle - 1
  if leftward_animation_angle < 0 then
    leftward_animation_angle = 64
  end
end

telegraph_attack_animation = {}
telegraph_attack_animation[1] = {}
local leftward_or_rightward = {-1, 1}
for k, animation in ipairs(leftward_or_rightward) do
  telegraph_attack_animation[animation] = {}
  for frame=1,#telegraph_attack_animation_speed do
    local distance = telegraph_attack_animation_speed[frame]
    local angle = telegraph_attack_animation_angles[animation][frame]/64
    
                --[[ use trigonometry to find the change in x and the change in y, given the hypotenuse (telegraph_attack_animation_speed) and the angle we should be traveling (2*math.pi*telegraph_attack_animation_angles[left_or_right][frame]/64)
                
                I think:              
                change in y will be hypotenuse*sin angle
                change in x will be hypotenuse*cos angle
                --]]
    
    telegraph_attack_animation[animation][frame] = {}
    telegraph_attack_animation[animation][frame].dx = distance * math.cos(angle*2*math.pi)
    telegraph_attack_animation[animation][frame].dy = distance * math.sin(angle*2*math.pi)
  end
end
--print("table_to_string(telegraph_attack_animation):")
--print(table_to_string(telegraph_attack_animation))
 
GARBAGE_DELAY = 60
GARBAGE_TRANSIT_TIME = 90

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

GAME_ENDED_CLOCK = 0

replay = {}

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
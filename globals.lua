require("consts")
require("queue")
require("server_queue")

server_queue = ServerQueue()

score_mode = SCOREMODE_TA

GARBAGE_TELEGRAPH_TIME = 45 -- the amount of time the garbage stays in the telegraph after getting there from the attack animation
GARBAGE_DELAY_LAND_TIME = 60 -- this is the amount of time after garbage leaves the telegraph before it can land on the opponent
						  -- a higher value allows less rollback to happen and makes lag have less of an impact on the game
						  -- technically this was 0 in classic games, but we are using this value to make rollback less noticable and match PA history
GARBAGE_TRANSIT_TIME = 45 -- the amount of time the garbage attack animation plays before getting to the telegraph
MAX_LAG = 200 + GARBAGE_TELEGRAPH_TIME -- maximum amount of lag before net games abort
NAME_LENGTH_LIMIT = 16

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
match_type = "Casual"

-- sfx play
SFX_Fanfare_Play = 0
SFX_GarbageThud_Play = 0
SFX_GameOver_Play = 0

global_op_state = nil

current_use_music_from = "stage" -- either "stage" or "characters", no other values!

-- this should probably live on match in the future
spectators_string = ""
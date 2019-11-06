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

-- win counters
my_win_count = 0
op_win_count = 0

global_my_state = nil
global_op_state = nil
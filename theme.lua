require("graphics_util")
require("sound_util")

local function load_theme_img(name)
  local img = load_img_from_supported_extensions("themes/"..config.theme.."/"..name)
  if not img then
    img = load_img_from_supported_extensions("themes/"..default_theme_dir.."/"..name)
  end
  return img
end

bg = load_theme_img("background/main")

local function graphics_init()
  title = load_theme_img("background/main")
  charselect = load_theme_img("background/select_screen")
  IMG_menu_readme = load_theme_img("background/readme")

  IMG_level_cursor = load_theme_img("level/level_cursor")
  IMG_levels = {}
  IMG_levels_unfocus = {}
  IMG_levels[1] = load_theme_img("level/level1")
  IMG_levels_unfocus[1] = nil -- meaningless by design
  for i=2,10 do
    IMG_levels[i] = load_theme_img("level/level"..i.."")
    IMG_levels_unfocus[i] = load_theme_img("level/level"..i.."unfocus")
  end

  IMG_ready = load_theme_img("ready")
  IMG_loading = load_theme_img("loading")
  IMG_numbers = {}
  for i=1,3 do
    IMG_numbers[i] = load_theme_img(i.."")
  end

  IMG_random_stage = load_theme_img("random_stage")

  IMG_frame = load_theme_img("frame")
  IMG_wall = load_theme_img("wall")

  IMG_cards = {}
  IMG_cards[true] = {}
  IMG_cards[false] = {}
  for i=4,66 do
    IMG_cards[false][i] = load_theme_img("combo/combo"
      ..tostring(math.floor(i/10))..tostring(i%10).."")
  end
  for i=2,13 do
    IMG_cards[true][i] = load_theme_img("chain/chain"
      ..tostring(math.floor(i/10))..tostring(i%10).."")
  end

  IMG_cards[true][14] = load_theme_img("chain/chain00")
  for i=15,99 do
    IMG_cards[true][i] = IMG_cards[true][14]
  end

  local MAX_SUPPORTED_PLAYERS = 2
  IMG_char_sel_cursors = {}
  IMG_players = {}
  IMG_cursor = {}
  for player_num=1,MAX_SUPPORTED_PLAYERS do
    IMG_players[player_num] = load_theme_img("p"..player_num)
    IMG_cursor[player_num] = load_theme_img("p"..player_num.."_cursor")
    IMG_char_sel_cursors[player_num] = {}
    for position_num=1,2 do
      IMG_char_sel_cursors[player_num][position_num] = load_theme_img("p"..player_num.."_select_screen_cursor"..position_num)
    end
  end

  IMG_char_sel_cursor_halves = {left={}, right={}}
  for player_num=1,MAX_SUPPORTED_PLAYERS do
    IMG_char_sel_cursor_halves.left[player_num] = {}
    for position_num=1,2 do
      local cur_width, cur_height = IMG_char_sel_cursors[player_num][position_num]:getDimensions()
      local half_width, half_height = cur_width/2, cur_height/2 -- TODO: is these unused vars an error ??? -Endu
      IMG_char_sel_cursor_halves["left"][player_num][position_num] = love.graphics.newQuad(0,0,half_width,cur_height,cur_width, cur_height)
    end
    IMG_char_sel_cursor_halves.right[player_num] = {}
    for position_num=1,2 do
      local cur_width, cur_height = IMG_char_sel_cursors[player_num][position_num]:getDimensions()
      local half_width, half_height = cur_width/2, cur_height/2
      IMG_char_sel_cursor_halves.right[player_num][position_num] = love.graphics.newQuad(half_width,0,half_width,cur_height,cur_width, cur_height)
    end
  end
end

local function sound_init()
  local function find_generic_SFX(SFX_name)
    local dirs_to_check = {"themes/"..config.theme.."/SFX/",
                           "themes/"..default_theme_dir.."/SFX/"}
    return find_sound(SFX_name, dirs_to_check)
  end

  --sounds: SFX, music
  SFX_Fanfare_Play = 0
  SFX_GameOver_Play = 0
  SFX_GarbageThud_Play = 0

  sounds = {
      cur_move = find_generic_SFX("move"),
      swap = find_generic_SFX("swap"),
      land = find_generic_SFX("land"),
      fanfare1 = find_generic_SFX("fanfare1"),
      fanfare2 = find_generic_SFX("fanfare2"),
      fanfare3 = find_generic_SFX("fanfare3"),
      game_over = find_generic_SFX("gameover"),
      countdown = find_generic_SFX("countdown"),
      go = find_generic_SFX("go"),
      menu_move = find_generic_SFX("menu_move"),
      menu_validate = find_generic_SFX("menu_validate"),
      menu_cancel = find_generic_SFX("menu_cancel"),
      garbage_thud = {
        find_generic_SFX("thud_1"),
        find_generic_SFX("thud_2"),
        find_generic_SFX("thud_3")
      },
      pops = {}
  }
  zero_sound = load_sound_from_supported_extensions("zero_music")
  
  for popLevel=1,4 do
    sounds.pops[popLevel] = {}
    for popIndex=1,10 do
      sounds.pops[popLevel][popIndex] = find_generic_SFX("pop"..popLevel.."-"..popIndex)
    end
  end
end

function theme_init()
  graphics_init()
  sound_init()
end

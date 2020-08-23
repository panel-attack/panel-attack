require("graphics_util")
require("sound_util")

local musics = {"main", "select_screen", "main_start", "select_screen_start"}

-- from https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
local flags =
{
"cn", -- China
"de", -- Germany
"es", -- Spain
"fr", -- France
"gb", -- United Kingdom of Great Britain and Northern Ireland
"in", -- India
"it", -- Italy
"jp", -- Japan
"pt", -- Portugal
"us", -- United States of America
}

local function load_theme_img(name)
  local img = load_img_from_supported_extensions("themes/"..config.theme.."/"..name)
  if not img then
    img = load_img_from_supported_extensions("themes/"..default_theme_dir.."/"..name)
  end
  return img
end

Theme = class(function(self)
    self.images = {}
    self.sounds = {}
    self.musics = {}
  end)

background = load_theme_img("background/main")

function Theme.graphics_init(self)
  self.images = {}

  self.images.flags = {}
  for _, flag in ipairs(flags) do
    self.images.flags[flag] = load_theme_img("flags/"..flag)
  end

  self.images.bg_main = load_theme_img("background/main")
  self.images.bg_select_screen = load_theme_img("background/select_screen")
  self.images.bg_readme = load_theme_img("background/readme")

  self.images.bg_overlay = load_theme_img("background/bg_overlay")
  self.images.fg_overlay = load_theme_img("background/fg_overlay")

  self.images.pause = load_theme_img("pause")

  self.images.IMG_level_cursor = load_theme_img("level/level_cursor")
  self.images.IMG_levels = {}
  self.images.IMG_levels_unfocus = {}
  self.images.IMG_levels[1] = load_theme_img("level/level1")
  self.images.IMG_levels_unfocus[1] = nil -- meaningless by design
  for i=2,#level_to_starting_speed do --which should equal the number of levels in the game
    self.images.IMG_levels[i] = load_theme_img("level/level"..i.."")
    self.images.IMG_levels_unfocus[i] = load_theme_img("level/level"..i.."unfocus")
  end

  self.images.IMG_ready = load_theme_img("ready")
  self.images.IMG_loading = load_theme_img("loading")
  self.images.IMG_super = load_theme_img("super")
  self.images.IMG_numbers = {}
  for i=1,3 do
    self.images.IMG_numbers[i] = load_theme_img(i.."")
  end

  self.images.IMG_random_stage = load_theme_img("random_stage")
  self.images.IMG_random_character = load_theme_img("random_character")

  --play field frames, plus the wall at the bottom.
  self.images.IMG_frame1P = load_theme_img("frame/frame1P")
  self.images.IMG_wall1P = load_theme_img("frame/wall1P")
  self.images.IMG_frame2P = load_theme_img("frame/frame2P")
  self.images.IMG_wall2P = load_theme_img("frame/wall2P")
  --the game currently only supports 2 players, but since 3P+ support is on the "to-do-eventually" list, include assets for more players
  --special thanks to TheWolfBunny on DeviantArt for 3P+ frame and wall sprites
  self.images.IMG_frame3P = load_theme_img("frame/frame3P")
  self.images.IMG_wall3P = load_theme_img("frame/wall3P")
  self.images.IMG_frame4P = load_theme_img("frame/frame4P")
  self.images.IMG_wall4P = load_theme_img("frame/wall4P")
  --5P-8P might be overkill, but just imagine...
  --self.images.IMG_frame5P = load_theme_img("frame/frame5P")
  --self.images.IMG_wall5P = load_theme_img("frame/wall5P")
  --self.images.IMG_frame6P = load_theme_img("frame/frame6P")
  --self.images.IMG_wall6P = load_theme_img("frame/wall6P")
  --self.images.IMG_frame7P = load_theme_img("frame/frame7P")
  --self.images.IMG_wall7P = load_theme_img("frame/wall7P")
  --self.images.IMG_frame8P = load_theme_img("frame/frame8P")
  --self.images.IMG_wall8P = load_theme_img("frame/wall8P")
  
  
  self.images.IMG_cards = {}
  self.images.IMG_cards[true] = {}
  self.images.IMG_cards[false] = {}
  for i=4,66 do
    self.images.IMG_cards[false][i] = load_theme_img("combo/combo"
      ..tostring(math.floor(i/10))..tostring(i%10).."")
  end
  for i=2,13 do
    self.images.IMG_cards[true][i] = load_theme_img("chain/chain"
      ..tostring(math.floor(i/10))..tostring(i%10).."")
  end

  self.images.IMG_cards[true][14] = load_theme_img("chain/chain00")
  for i=15,99 do
    self.images.IMG_cards[true][i] = self.images.IMG_cards[true][14]
  end

  local MAX_SUPPORTED_PLAYERS = 2
  self.images.IMG_char_sel_cursors = {}
  self.images.IMG_players = {}
  self.images.IMG_cursor = {}
  for player_num=1,MAX_SUPPORTED_PLAYERS do
    self.images.IMG_players[player_num] = load_theme_img("p"..player_num)
    self.images.IMG_cursor[player_num] = load_theme_img("p"..player_num.."_cursor")
    self.images.IMG_char_sel_cursors[player_num] = {}
    for position_num=1,2 do
      self.images.IMG_char_sel_cursors[player_num][position_num] = load_theme_img("p"..player_num.."_select_screen_cursor"..position_num)
    end
  end

  self.images.IMG_char_sel_cursor_halves = {left={}, right={}}
  for player_num=1,MAX_SUPPORTED_PLAYERS do
    self.images.IMG_char_sel_cursor_halves.left[player_num] = {}
    for position_num=1,2 do
      local cur_width, cur_height = self.images.IMG_char_sel_cursors[player_num][position_num]:getDimensions()
      local half_width, half_height = cur_width/2, cur_height/2 -- TODO: is these unused vars an error ??? -Endu
      self.images.IMG_char_sel_cursor_halves["left"][player_num][position_num] = love.graphics.newQuad(0,0,half_width,cur_height,cur_width, cur_height)
    end
    self.images.IMG_char_sel_cursor_halves.right[player_num] = {}
    for position_num=1,2 do
      local cur_width, cur_height = self.images.IMG_char_sel_cursors[player_num][position_num]:getDimensions()
      local half_width, half_height = cur_width/2, cur_height/2
      self.images.IMG_char_sel_cursor_halves.right[player_num][position_num] = love.graphics.newQuad(half_width,0,half_width,cur_height,cur_width, cur_height)
    end
  end
end

function Theme.apply_config_volume(self)
  set_volume(self.sounds, config.SFX_volume/100)
  set_volume(self.musics, config.music_volume/100)
end

function Theme.sound_init(self)
  local function load_theme_sfx(SFX_name)
    local dirs_to_check = {"themes/"..config.theme.."/sfx/",
                           "themes/"..default_theme_dir.."/sfx/"}
    return find_sound(SFX_name, dirs_to_check)
  end

  -- SFX
  self.sounds = {
      cur_move = load_theme_sfx("move"),
      swap = load_theme_sfx("swap"),
      land = load_theme_sfx("land"),
      fanfare1 = load_theme_sfx("fanfare1"),
      fanfare2 = load_theme_sfx("fanfare2"),
      fanfare3 = load_theme_sfx("fanfare3"),
      game_over = load_theme_sfx("gameover"),
      countdown = load_theme_sfx("countdown"),
      go = load_theme_sfx("go"),
      menu_move = load_theme_sfx("menu_move"),
      menu_validate = load_theme_sfx("menu_validate"),
      menu_cancel = load_theme_sfx("menu_cancel"),
      notification = load_theme_sfx("notification"),
      garbage_thud = {
        load_theme_sfx("thud_1"),
        load_theme_sfx("thud_2"),
        load_theme_sfx("thud_3")
      },
      pops = {}
  }
  
  for popLevel=1,4 do
    self.sounds.pops[popLevel] = {}
    for popIndex=1,10 do
      self.sounds.pops[popLevel][popIndex] = load_theme_sfx("pop"..popLevel.."-"..popIndex)
    end
  end

  -- music
  self.musics = {}
  for _, music in ipairs(musics) do
    self.musics[music] = load_sound_from_supported_extensions("themes/"..config.theme.."/music/"..music, true)
    if self.musics[music] then
      if not string.find(music, "start") then
        self.musics[music]:setLooping(true)
      else
        self.musics[music]:setLooping(false)
      end
    end
  end

  self:apply_config_volume()
end

function Theme.load(self, id)
  print("loading theme "..id)
  self:graphics_init()
  self:sound_init()
  print("loaded theme "..id)
end

function theme_init()
  -- only one theme at a time for now, but we may decide to allow different themes in the future
  themes = {}
  themes[config.theme] = Theme()
  themes[config.theme]:load(config.theme)
end

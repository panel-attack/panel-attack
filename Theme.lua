require("developer")
require("graphics_util")
require("sound_util")
local consts = require("consts")
require("class")
local logger = require("logger")
local fileUtils = require("FileUtils")
local levelPresets = require("LevelPresets")

local musics = {"main", "select_screen", "main_start", "select_screen_start", "title_screen"} -- the music used in a theme

-- from https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
local flags = {
  "cn", -- China
  "de", -- Germany
  "es", -- Spain
  "fr", -- France
  "gb", -- United Kingdom of Great Britain and Northern Ireland
  "in", -- India
  "it", -- Italy
  "jp", -- Japan
  "pt", -- Portugal
  "us" -- United States of America
}

-- Represents the current styles and images to apply to the game UI
Theme =
  class(
  function(self, name)
    self.VERSIONS = { original = 1, two = 2, fixedOffsets = 3, current = 3}
    self.name = name
    self.version = self.VERSIONS.original
    self.images = {} -- theme images
    self.sounds = {} -- theme sfx
    self.musics = {} -- theme music
    self.font = {} -- font
    self.font.size = 12

    self.main_menu_screen_pos = {0, 0} -- the top center position of most menus
    self.main_menu_y_max = 0
    self.main_menu_max_height = 0

    self:load()
  end
)

-- Returns a list of keys and their type allowed in theme config files
function Theme:configurableKeys() 
  local result = {}

  result["version"] = "number"
  result["matchtypeLabel_Pos"] = "table"
  result["matchtypeLabel_Scale"] = "number"
  result["timeLabel_Pos"] = "table"
  result["timeLabel_Scale"] = "number"
  result["time_Pos"] = "table"
  result["time_Scale"] = "number"
  result["moveLabel_Pos"] = "table"
  result["moveLabel_Scale"] = "number"
  result["move_Pos"] = "table"
  result["move_Scale"] = "number"
  result["scoreLabel_Pos"] = "table"
  result["scoreLabel_Scale"] = "number"
  result["score_Pos"] = "table"
  result["score_Scale"] = "number"
  result["speedLabel_Pos"] = "table"
  result["speedLabel_Scale"] = "number"
  result["speed_Pos"] = "table"
  result["speed_Scale"] = "number"
  result["levelLabel_Pos"] = "table"
  result["levelLabel_Scale"] = "number"
  result["level_Pos"] = "table"
  result["level_Scale"] = "number"
  result["winLabel_Pos"] = "table"
  result["winLabel_Scale"] = "number"
  result["win_Pos"] = "table"
  result["win_Scale"] = "number"
  result["name_Pos"] = "table"
  result["name_Font_Size"] = "number"
  result["ratingLabel_Pos"] = "table"
  result["ratingLabel_Scale"] = "number"
  result["rating_Pos"] = "table"
  result["rating_Scale"] = "number"
  result["spectators_Pos"] = "table"
  result["healthbar_frame_Pos"] = "table"
  result["healthbar_frame_Scale"] = "number"
  result["healthbar_Pos"] = "table"
  result["healthbar_Scale"] = "number"
  result["healthbar_Rotate"] = "number"
  result["multibar_Pos"] = "table"
  result["multibar_Scale"] = "number"
  result["multibar_is_absolute"] = "boolean"
  result["multibar_LeftoverTime_Pos"] = "table"
  result["font_size"] = "number"
  result["bg_title_speed_x"] = "number"
  result["bg_title_speed_y"] = "number"
  result["bg_main_speed_x"] = "number"
  result["bg_main_speed_y"] = "number"
  result["bg_select_screen_speed_x"] = "number"
  result["bg_select_screen_speed_y"] = "number"
  result["bg_readme_speed_x"] = "number"
  result["bg_readme_speed_y"] = "number"
  result["bg_title_is_tiled"] = "boolean"
  result["bg_main_is_tiled"] = "boolean"
  result["bg_select_screen_is_tiled"] = "boolean"
  result["bg_readme_is_tiled"] = "boolean"
  result["gameover_text_Pos"] = "table"

  return result
end

function Theme:loadVersion1DefaultValues()
  -- Version 1 values
  -- All of the default values below are legacy "version 1" values, the modern values are are loaded from the default theme config file
  -- Old themes inherit these values if they do not specify a version.
  self.matchtypeLabel_Pos = {-40, -30} -- the position of the "match type" label
  self.matchtypeLabel_Scale = 3 -- the scale size of the "match type" lavel
  self.timeLabel_Pos = {-4, 2} -- the position of the timer label
  self.timeLabel_Scale = 2 -- the scale size of the timer label
  self.time_Pos = {26, 26} -- the position of the timer
  self.time_Scale = 2 -- the scale size of the timer
  self.name_Pos = {20, -30} -- the position of the name
  self.name_Font_Size = 12 -- the font size of the name
  self.moveLabel_Pos = {468, 170} -- the position of the move label
  self.moveLabel_Scale = 2 -- the scale size of the move label
  self.move_Pos = {40, 34} -- the position of the move
  self.move_Scale = 1 -- the scale size of the move
  self.scoreLabel_Pos = {104, 25} -- the position of the score label
  self.scoreLabel_Scale = 2 -- the scale size of the score label
  self.score_Pos = {116, 32} -- the position of the score
  self.score_Scale = 1.5 -- the scale size of the score
  self.speedLabel_Pos = {106, 42} -- the position of the speed label
  self.speedLabel_Scale = 2 -- the scale size of the speed label
  self.speed_Pos = {116, 48} -- the position of the speed
  self.speed_Scale = 1.35 -- the scale size of the speed
  self.levelLabel_Pos = {104, 58} -- the position of the level label
  self.levelLabel_Scale = 2 -- the scale size of the level label
  self.level_Pos = {112, 66} -- the position of the level
  self.level_Scale = 1 -- the scale size of the level
  self.winLabel_Pos = {10, 190} -- the position of the win label
  self.winLabel_Scale = 2 -- the scale size of the win label
  self.win_Pos = {40, 220} -- the position of the win counter
  self.win_Scale = 2 -- the scale size of the win counter
  self.ratingLabel_Pos = {5, 140} -- the position of the rating label
  self.ratingLabel_Scale = 2 -- the scale size of the rating label
  self.rating_Pos = {38, 160} -- the position of the rating value
  self.rating_Scale = 1 -- the scale size of the rating value
  self.spectators_Pos = {547, 460} -- the position of the spectator list
  self.healthbar_frame_Pos = {-17, -4} -- the position of the healthbar frame
  self.healthbar_frame_Scale = 3 -- the scale size of the healthbar frame
  self.healthbar_Pos = {-13, 148} -- the position of the healthbar
  self.healthbar_Scale = 1 -- the scale size of the healthbar
  self.healthbar_Rotate = 0 -- the rotation of the healthbar
  self.multibar_Pos = {-13, 96} -- the position of the multibar
  self.multibar_Scale = 1 -- the scale size of the multibar
  self.multibar_is_absolute = false -- if the multibar should render in absolute scale
  self.bg_title_is_tiled = false -- if the image should tile (default is stretch)
  self.bg_title_speed_x = 0 -- speed the various backgrounds move at
  self.bg_title_speed_y = 0
  self.bg_main_is_tiled = false -- if the image should tile (default is stretch)
  self.bg_main_speed_x = 0
  self.bg_main_speed_y = 0
  self.bg_select_screen_is_tiled = false -- if the image should tile (default is stretch)
  self.bg_select_screen_speed_x = 0
  self.bg_select_screen_speed_y = 0
  self.bg_readme_is_tiled = false -- if the image should tile (default is stretch)
  self.bg_readme_speed_x = 0
  self.bg_readme_speed_y = 0
end

function Theme:loadVersion2DefaultValues()
  -- Version 2 values
  -- All of the default values below are legacy "version 2" values, the modern values are are loaded from the default theme config file
  self.timeLabel_Pos = {-4, 2} -- the position of the timer label
  self.time_Pos = {26, 26} -- the position of the timer
  self.name_Pos = {20, -30} -- the position of the name
  self.name_Font_Size = 12 -- the font size of the name
  self.scoreLabel_Pos = {104, 25} -- the position of the score label
  self.score_Pos = {116, 34} -- the position of the score
  self.speedLabel_Pos = {104, 42} -- the position of the speed label
  self.speed_Pos = {116, 50} -- the position of the speed
  self.levelLabel_Scale = 1 -- the scale size of the level label
  self.levelLabel_Pos = {105, 58} -- the position of the level label
  self.level_Pos = {112, 66} -- the position of the level
  self.level_Scale = 1 -- the scale size of the level
  self.ratingLabel_Pos = {0, 140} -- the position of the rating label
  self.rating_Pos = {38, 162} -- the position of the rating value
  self.spectators_Pos = {547, 460} -- the position of the spectator list
  self.winLabel_Pos = {10, 190} -- the position of the win label
  self.win_Pos = {40, 212} -- the position of the win counter
  self.moveLabel_Scale = 1 -- the scale size of the move label
  self.moveLabel_Pos = {468, 170} -- the position of the move label
  self.move_Scale = 1 -- the scale size of the move
  self.move_Pos = {40, 34} -- the position of the move
  self.healthbar_frame_Pos = {-17, -4} -- the position of the healthbar frame
end

Theme.themeDirectoryPath = "themes/"
Theme.defaultThemeDirectoryPath = Theme.themeDirectoryPath .. consts.DEFAULT_THEME_DIRECTORY .. "/"

-- loads the image of the given name
function Theme:load_theme_img(name, useBackup)
  if useBackup == nil then
    useBackup = true
  end
  local img = GraphicsUtil.loadImageFromSupportedExtensions(Theme.themeDirectoryPath .. self.name .. "/" .. name)
  if not img and useBackup then
    img = GraphicsUtil.loadImageFromSupportedExtensions(Theme.defaultThemeDirectoryPath .. name)
  end
  return img
end

function Theme.graphics_init(self)
  self.images = {}

  self.images.flags = {}
  for _, flag in ipairs(flags) do
    self.images.flags[flag] = self:load_theme_img("flags/" .. flag)
  end

  self.images.bg_overlay = self:load_theme_img("background/bg_overlay")
  self.images.fg_overlay = self:load_theme_img("background/fg_overlay")

  self.images.pause = self:load_theme_img("pause")

  self.images.IMG_level_cursor = self:load_theme_img("level/level_cursor")
  self.images.IMG_levels = {}
  self.images.IMG_levels_unfocus = {}
  self.images.IMG_levels[1] = self:load_theme_img("level/level1")
  self.images.IMG_levels_unfocus[1] = nil -- meaningless by design
  for i = 2, levelPresets.modernPresetCount do --which should equal the number of levels in the game
    self.images.IMG_levels[i] = self:load_theme_img("level/level" .. i .. "")
    self.images.IMG_levels_unfocus[i] = self:load_theme_img("level/level" .. i .. "unfocus")
  end

  self.images.IMG_ready = self:load_theme_img("ready")
  self.images.IMG_loading = self:load_theme_img("loading")
  self.images.IMG_super = self:load_theme_img("super")
  self.images.IMG_numbers = {}
  for i = 1, 3 do
    self.images.IMG_numbers[i] = self:load_theme_img(i .. "")
  end

  self.images.burst = self:load_theme_img("burst")

  self.images.fade = self:load_theme_img("fade")

  self.fontMaps = {}

  local numberAtlasCharacters = "0123456789"
  local numberAtlas1 = self:load_theme_img("numbers_1P")
  local numberAtlas2 = self:load_theme_img("numbers_2P")
  self.fontMaps.numbers = {}
  self.fontMaps.numbers[1] = GraphicsUtil.createPixelFontMap(numberAtlasCharacters, numberAtlas1)
  self.fontMaps.numbers[2] = GraphicsUtil.createPixelFontMap(numberAtlasCharacters, numberAtlas2)

  self.images.IMG_time = self:load_theme_img("time")

  local timeAtlasCharacters = "0123456789:'"
  local timeAtlas = self:load_theme_img("time_numbers")
  self.fontMaps.time = GraphicsUtil.createPixelFontMap(timeAtlasCharacters, timeAtlas)

  local pixelFontCharacters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ&?!%*."
  local pixelFontBlueAtlas = self:load_theme_img("pixel_font_blue")
  local pixelFontGreyAtlas = self:load_theme_img("pixel_font_grey")
  local pixelFontYellowAtlas = self:load_theme_img("pixel_font_yellow")

  self.fontMaps.pixelFontBlue = GraphicsUtil.createPixelFontMap(pixelFontCharacters, pixelFontBlueAtlas)
  self.fontMaps.pixelFontGrey = GraphicsUtil.createPixelFontMap(pixelFontCharacters, pixelFontGreyAtlas)
  self.fontMaps.pixelFontYellow = GraphicsUtil.createPixelFontMap(pixelFontCharacters, pixelFontYellowAtlas)

  self.images.IMG_moves = self:load_theme_img("moves")

  self.images.IMG_score_1P = self:load_theme_img("score_1P")
  self.images.IMG_score_2P = self:load_theme_img("score_2P")

  self.images.IMG_speed_1P = self:load_theme_img("speed_1P")
  self.images.IMG_speed_2P = self:load_theme_img("speed_2P")

  self.images.IMG_level_1P = self:load_theme_img("level_1P")
  self.images.IMG_level_2P = self:load_theme_img("level_2P")

  self.images.IMG_wins = self:load_theme_img("wins")

  self.images.levelNumberAtlas = {}
  self.images.levelNumberAtlas[1] = {}
  self.images.levelNumberAtlas[1].image = self:load_theme_img("level_numbers_1P")
  self.images.levelNumberAtlas[1].charWidth = self.images.levelNumberAtlas[1].image:getWidth() / 11
  self.images.levelNumberAtlas[1].charHeight = self.images.levelNumberAtlas[1].image:getHeight()

  self.images.levelNumberAtlas[2] = {}
  self.images.levelNumberAtlas[2].image = self:load_theme_img("level_numbers_2P")
  self.images.levelNumberAtlas[2].charWidth = self.images.levelNumberAtlas[2].image:getWidth() / 11
  self.images.levelNumberAtlas[2].charHeight = self.images.levelNumberAtlas[2].image:getHeight()

  self.images.IMG_casual = self:load_theme_img("casual")
  self.images.IMG_ranked = self:load_theme_img("ranked")

  self.images.IMG_rating_1P = self:load_theme_img("rating_1P")
  self.images.IMG_rating_2P = self:load_theme_img("rating_2P")

  self.images.IMG_random_stage = self:load_theme_img("random_stage")
  self.images.IMG_random_character = self:load_theme_img("random_character")

  self.images.healthbarFrames = {}
  self.images.healthbarFrames.relative = {}
  self.images.healthbarFrames.relative[1]  = self:load_theme_img("healthbar_frame_1P")
  self.images.healthbarFrames.relative[2]  = self:load_theme_img("healthbar_frame_2P")
  self.images.healthbarFrames.absolute = {}
  self.images.healthbarFrames.absolute[1] = self:load_theme_img("healthbar_frame_1P_absolute")
  self.images.healthbarFrames.absolute[2] = self:load_theme_img("healthbar_frame_2P_absolute")
  
  self.images.IMG_healthbar = self:load_theme_img("healthbar")

  self.images.IMG_multibar_frame = self:load_theme_img("multibar_frame")
  self.images.IMG_multibar_prestop_bar = self:load_theme_img("multibar_prestop_bar")
  self.images.IMG_multibar_stop_bar = self:load_theme_img("multibar_stop_bar")
  self.images.IMG_multibar_shake_bar = self:load_theme_img("multibar_shake_bar")

  self.images.IMG_bug = self:load_theme_img("bug")

  --play field frames, plus the wall at the bottom.
  self.images.frames = {}
  self.images.walls = {}
  self.images.frames[1] = self:load_theme_img("frame/frame1P")
  self.images.frames[2] = self:load_theme_img("frame/frame2P")
  self.images.walls[1] = self:load_theme_img("frame/wall1P")
  self.images.walls[2] = self:load_theme_img("frame/wall2P")

  self.images.IMG_swap = self:load_theme_img("swap")
  self.images.IMG_apm = self:load_theme_img("apm")
  self.images.IMG_gpm = self:load_theme_img("GPM")
  self.images.IMG_cursorCount = self:load_theme_img("CursorCount")

  self.images.IMG_cards = {}
  self.images.IMG_cards[true] = {}
  self.images.IMG_cards[false] = {}
  for i = 4, 72 do
    self.images.IMG_cards[false][i] = self:load_theme_img("combo/combo" .. tostring(math.floor(i / 10)) .. tostring(i % 10) .. "")
  end
  -- mystery chain
  self.images.IMG_cards[true][0] = self:load_theme_img("chain/chain00")
  -- mystery combo
  self.images.IMG_cards[false][0] = self:load_theme_img("combo/combo00")

  -- Chain card loading
  -- load as many chain cards as there are available until 99
  -- we assume if the theme provided any chains, they want to control all of them so don't load backups
  local hasChainCards = love.filesystem.getInfo(Theme.themeDirectoryPath .. self.name .. "/chain")
  local wantsBackupChainCards = hasChainCards == nil
  for i = 2, 13 do
    -- with backup from default theme
    self.images.IMG_cards[true][i] = self:load_theme_img("chain/chain" .. tostring(math.floor(i / 10)) .. tostring(i % 10) .. "")
  end
  -- load as many more chain cards as there are available until 99, we will substitute in the mystery card if a card is missing
  self.chainCardLimit = 99
  for i = 14, 99 do
    -- without backup from default theme
    self.images.IMG_cards[true][i] = self:load_theme_img("chain/chain" .. tostring(math.floor(i / 10)) .. tostring(i % 10) .. "", wantsBackupChainCards)
    if self.images.IMG_cards[true][i] == nil then
      self.chainCardLimit = i - 1
      break
    end
  end

  local MAX_SUPPORTED_PLAYERS = 2
  self.images.IMG_char_sel_cursors = {}
  self.images.IMG_players = {}
  self.images.IMG_cursor = {}
  for player_num = 1, MAX_SUPPORTED_PLAYERS do
    self.images.IMG_players[player_num] = self:load_theme_img("p" .. player_num)
    self.images.IMG_char_sel_cursors[player_num] = {}
    for position_num = 1, 2 do
      self.images.IMG_char_sel_cursors[player_num][position_num] = self:load_theme_img("p" .. player_num .. "_select_screen_cursor" .. position_num)
    end
  end

  -- Cursor animation is 2 frames
  for i = 1, 2 do
    -- Cursor images used to be named weird and make modders think they were for different players
    -- Load either format from the custom theme, and fallback to the built in cursor otherwise.
    local cursorImage = self:load_theme_img("cursor" .. i, false)
    local legacyCursorImage = self:load_theme_img("p" .. i .. "_cursor", false)
    if not cursorImage then
      if legacyCursorImage then
        cursorImage = legacyCursorImage
      else
        cursorImage = self:load_theme_img("cursor" .. i, true)
      end
    end
    assert(cursorImage ~= nil)
    self.images.IMG_cursor[i] = cursorImage
  end

  self.images.IMG_char_sel_cursor_halves = {left = {}, right = {}}
  for player_num = 1, MAX_SUPPORTED_PLAYERS do
    self.images.IMG_char_sel_cursor_halves.left[player_num] = {}
    for position_num = 1, 2 do
      local cur_width, cur_height = self.images.IMG_char_sel_cursors[player_num][position_num]:getDimensions()
      local half_width, half_height = cur_width / 2, cur_height / 2 -- TODO: is these unused vars an error ??? -Endu
      self.images.IMG_char_sel_cursor_halves["left"][player_num][position_num] = GraphicsUtil:newRecycledQuad(0, 0, half_width, cur_height, cur_width, cur_height)
    end
    self.images.IMG_char_sel_cursor_halves.right[player_num] = {}
    for position_num = 1, 2 do
      local cur_width, cur_height = self.images.IMG_char_sel_cursors[player_num][position_num]:getDimensions()
      local half_width, half_height = cur_width / 2, cur_height / 2
      self.images.IMG_char_sel_cursor_halves.right[player_num][position_num] = GraphicsUtil:newRecycledQuad(half_width, 0, half_width, cur_height, cur_width, cur_height)
    end
  end

  for key, value in pairs(fileUtils.getFilteredDirectoryItems(Theme.themeDirectoryPath .. self.name)) do
    if value:lower():match(".*%.ttf") then -- Any .ttf file
      self.font.path = Theme.themeDirectoryPath .. self.name .. "/" .. value
      GraphicsUtil.setGlobalFont(self.font.path, self.font.size)
      break
    end
  end
end

-- applies the config volume to the theme
function Theme.apply_config_volume(self)
  set_volume(self.sounds, config.SFX_volume / 100)
  set_volume(self.musics, config.music_volume / 100)
end

-- initializes the theme sounds
function Theme.sound_init(self)
  local function load_theme_sfx(SFX_name)
    local dirs_to_check = {
      Theme.themeDirectoryPath .. self.name .. "/sfx/",
      Theme.defaultThemeDirectoryPath .. "sfx/"
    }
    return find_sound(SFX_name, dirs_to_check)
  end

  self.zero_sound = load_sound_from_supported_extensions("zero_music")

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

  for popLevel = 1, 4 do
    self.sounds.pops[popLevel] = {}
    for popIndex = 1, 10 do
      self.sounds.pops[popLevel][popIndex] = load_theme_sfx("pop" .. popLevel .. "-" .. popIndex)
    end
  end

  -- music
  self.musics = {}
  for _, music in ipairs(musics) do
    self.musics[music] = load_sound_from_supported_extensions(Theme.themeDirectoryPath .. self.name .. "/music/" .. music, true)
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

function Theme.upgradeAndSaveVerboseConfig(self)
  if self.version == self.VERSIONS.original then
    self.version = self.VERSIONS.two
    self:saveVerboseConfig()
  end
end

function Theme.saveVerboseConfig(self)
  local jsonPath = Theme.themeDirectoryPath .. self.name .. "/config.json"

  -- Get the data from the file in case there is something we don't know about
  local jsonData = self:getJSONDataForFile(jsonPath)

  -- Save off any configurable data that may have changed / upgraded
  local configurableKeys = self:configurableKeys()
  for key, _ in pairs(configurableKeys) do
    jsonData[key] = self[key]
  end
  
  pcall(
    function()
      local file = love.filesystem.newFile(jsonPath)
      file:open("w")
      file:write(json.encode(jsonData))
      file:close()
    end
  )
end

-- initializes theme using the json settings
function Theme.json_init(self)
  -- Start with the default theme
  local defaultData = self:getJSONDataForFile(Theme.defaultThemeDirectoryPath .. "config.json")
  self:applyJSONData(defaultData)

  -- Then override with custom theme
  if self.name ~= consts.DEFAULT_THEME_DIRECTORY then
    local customData = self:getJSONDataForFile(Theme.themeDirectoryPath .. self.name .. "/config.json")
    local version = self:versionForJSONVersion(customData.version)
    if version == self.VERSIONS.original then
      self:loadVersion1DefaultValues()
    elseif version == self.VERSIONS.two then
      self:loadVersion2DefaultValues()
    end
    self:applyJSONData(customData)

    self:upgradeAndSaveVerboseConfig()
  end
end

function Theme:versionForJSONVersion(jsonVersion)
  if jsonVersion and type(jsonVersion) == "number" then
    return  jsonVersion
  else
    return self.VERSIONS.original
  end
end

function Theme:getJSONDataForFile(filePath)
  local read_data = {}

  -- First read the default theme json
  local config_file, err = love.filesystem.newFile(filePath, "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    config_file:close()
    for k, v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end

  return read_data
end

-- applies all the JSON values from a table
function Theme:applyJSONData(read_data)
  local configurableKeys = self:configurableKeys()
  for key, value in pairs(read_data) do
    if configurableKeys[key] ~= nil and type(value) == configurableKeys[key] then
      self[key] = read_data[key]
    end
  end

  -- Handle non standard mappings
  if self.font_size then
    self.font.size = self.font_size
    self.font_size = nil
  end
  self.version = self:versionForJSONVersion(read_data.version)
end

function Theme:final_init()

  local titleImage = self:load_theme_img("background/title", false)
  if titleImage then
    self.images.bg_title = UpdatingImage(titleImage, self.bg_title_is_tiled, self.bg_title_speed_x, self.bg_title_speed_y, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  end

  self.images.bg_main = UpdatingImage(self:load_theme_img("background/main"), self.bg_main_is_tiled, self.bg_main_speed_x, self.bg_main_speed_y, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  self.images.bg_select_screen = UpdatingImage(self:load_theme_img("background/select_screen"), self.bg_select_screen_is_tiled, self.bg_select_screen_speed_x, self.bg_select_screen_speed_y, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  self.images.bg_readme = UpdatingImage(self:load_theme_img("background/readme"), self.bg_readme_is_tiled, self.bg_readme_speed_x, self.bg_readme_speed_y, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)

  local menuYPadding = 10
  self.centerMenusVertically = true
  if self.images.bg_title then
    menuYPadding = 100
    self.main_menu_screen_pos = {532, menuYPadding}
    self.main_menu_y_max = consts.CANVAS_HEIGHT - menuYPadding
  else
    self.main_menu_screen_pos = {532, 249}
    self.main_menu_y_max = consts.CANVAS_HEIGHT - menuYPadding
    self.centerMenusVertically = false
  end
  self.main_menu_max_height = (self.main_menu_y_max - self.main_menu_screen_pos[2])
  self.main_menu_y_center = self.main_menu_screen_pos[2] + (self.main_menu_max_height / 2)

end

function Theme:offsetsAreFixed()
  return self.version >= self.VERSIONS.fixedOffsets
end

function Theme:chainImage(chainAmount)
  local cardImage = self.images.IMG_cards[true][chainAmount]
  if cardImage == nil then
   cardImage = self.images.IMG_cards[true][0]
  end
  return cardImage
end

function Theme:comboImage(comboAmount)
  local cardImage = self.images.IMG_cards[false][comboAmount]
  if cardImage == nil then
   cardImage = self.images.IMG_cards[false][0]
  end
  return cardImage
end

-- loads a theme into the game
function Theme.load(self)
  logger.debug("loading theme " .. self.name)
  self:json_init()
  self:graphics_init()
  self:sound_init()
  self:final_init()
  logger.debug("loaded theme " .. self.name)
end

-- initializes a theme
function theme_init()
  -- only one theme at a time for now, but we may decide to allow different themes in the future
  themes = {}
  local themeName = config.theme
  themes[themeName] = Theme(themeName)
end
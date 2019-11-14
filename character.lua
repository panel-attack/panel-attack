require("character_loader")

  -- Stuff defined in this file:
  --  . the data structure that store a character's data
local min, pairs, deepcpy = math.min, pairs, deepcpy
local max = math.max

local basic_character_images = { "icon" }
local other_character_images = {"topleft", "botleft", "topright", "botright",
                  "top", "bot", "left", "right", "face", "pop",
                  "doubleface", "filler1", "filler2", "flash",
                  "portrait"}

local required_char_SFX = {"chain", "combo"}
local required_char_music = {"normal_music"}

  -- @CardsOfTheHeart says there are 4 chain sfx: --x2/x3, --x4, --x5 is x2/x3 with an echo effect, --x6+ is x4 with an echo effect
  -- combo sounds, on the other hand, can have multiple variations, hence combo, combo2, combo3 (...) and combo_echo, combo_echo2...
local basic_characters_sfx = {"selection"}
local other_characters_sfx = {"chain", "combo", "combo_echo", "chain_echo", "chain2" ,"chain2_echo", "garbage_match", "win"}
local basic_characters_musics = {}
local other_characters_musics = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}

local default_stages = {lip="flower", windy="wind", sherbet="ice", thiana="forest", ruby="jewel",
                        elias="water", flare="fire", neris="sea", seren="moon", phoenix="cave", 
                        dragon="cave", thanatos="king", cordelia="cordelia", lakitu="wind",
                        bumpty="ice", poochy="forest", wiggler="jewel", froggy="water", blargg="fire",
                        lungefish="sea", raphael="moon", yoshi="yoshi", hookbill="cave",
                        navalpiranha="cave", kamek="cave", bowser="king"}

Character = class(function(s, id)
    s.id = id -- string | id of the character, is also the name of its folder
    s.display_name = id -- string | display name of the character
    s.favorite_stage = default_stages[id] -- string | id of the character, is also the name of its folder
    s.images = {}
    s.sounds = { combos = {}, combo_echos = {}, selections = {}, wins = {}, garbage_matches = {}, others = {} }
    s.musics = {}
    s.fully_loaded = false
  end)

function Character.other_data_init(self)
  local dirs_to_check = { "characters/" }
  if config.use_default_characters and self.id ~= default_character_id then
    dirs_to_check = { "assets/"..config.assets_dir.."/",
                      "assets/"..default_assets_dir.."/",
                      "characters/"}
  end
  self.display_name = self.id
  self.favorite_stage = default_stages[self.id]

  -- display name
  for _,current_dir in ipairs(dirs_to_check) do
    local txt_file, err = love.filesystem.newFile(current_dir..self.id.."/name.txt", "r")
    if txt_file then
      local display_name = txt_file:read(txt_file:getSize())
      if display_name then
        self.display_name = display_name
        break
      end
    end
  end
  -- favorite stage
  for _,current_dir in ipairs(dirs_to_check) do
    local txt_file, err = love.filesystem.newFile(current_dir..self.id.."/stage.txt", "r")
    if txt_file then
      local stage = txt_file:read(txt_file:getSize())
      if stage then
        self.favorite_stage = stage
        break
      end
    end
  end
  print( self.id..(self.id ~= self.display_name and (", aka "..self.display_name..", ") or " ")..(self.favorite_stage and ("likes to play in stage "..self.favorite_stage) or "would play anywhere"))
end

local function find_character_SFX(character_id, SFX_name,fallback)
  fallback = fallback or nil
  local dirs_to_check = { "characters/" }
  if config.use_default_characters and character_id ~= default_character_id then
    dirs_to_check = { "sounds/"..config.sounds_dir.."/characters/",
                      "sounds/"..default_sounds_dir.."/characters/",
                      "characters/"}
  end
  for _,current_dir in ipairs(dirs_to_check) do
    --Note: if there is a chain or a combo, but not the other, return the same SFX for either inquiry.
    --This way, we can always depend on a character having a combo and a chain SFX.
    --If they are missing others, that's fine.
    --(ie. some characters won't have "match_garbage" or a fancier "chain-x6")
    local cur_dir_chain = get_from_supported_extensions(current_dir..character_id.."/chain")
    if SFX_name == "chain" and cur_dir_chain then 
      if config.debug_mode then print("loaded "..SFX_name.." for "..character_id) end
      return cur_dir_chain
    end
    local cur_dir_combo = get_from_supported_extensions(current_dir..character_id.."/combo")
    if SFX_name == "combo" and cur_dir_combo then 
      if config.debug_mode then print("loaded "..SFX_name.." for "..character_id) end
      return cur_dir_combo
    elseif SFX_name == "combo" and cur_dir_chain then
      if config.debug_mode then print("substituted found chain SFX for "..SFX_name.." for "..character_id) end
      return cur_dir_chain --in place of the combo SFX
    end
    if SFX_name == "chain" and cur_dir_combo then
      if config.debug_mode then print("substituted found combo SFX for "..SFX_name.." for "..character_id) end
      return cur_dir_combo
    end
    
    local other_requested_SFX = get_from_supported_extensions(current_dir..character_id.."/"..SFX_name)
    if other_requested_SFX then
      if config.debug_mode then print("loaded "..SFX_name.." for "..character_id) end
      return other_requested_SFX
    else
      if config.debug_mode then print("did not find "..SFX_name.." for "..character_id.." in current directory: "..current_dir) end
    end
    if cur_dir_chain or cur_dir_combo --[[and we didn't find the requested SFX in this dir]] then
      if config.debug_mode then print("chain or combo was provided, but "..SFX_name.." was not.") end
      return nil --don't continue looking in other fallback directories,
  --else
    --keep looking
    end
  end
  --if not found in above directories: fallback
  return fallback
end

local function find_music(character_id, music_type)
  local dirs_to_check = { "",
                          "sounds/"..default_sounds_dir.."/" }
  if config.use_default_characters and character_id ~= default_character_id then
    dirs_to_check = { "sounds/"..config.sounds_dir.."/",
                      "sounds/"..default_sounds_dir.."/",
                      ""}
  end
  for _,current_dir in ipairs(dirs_to_check) do
    local path = current_dir.."characters/"..character_id
    if any_supported_extension(path.."/normal_music") then -- character has control over their musics, no fallback allowed!
      local found_source = get_from_supported_extensions(path.."/"..music_type, true)
      if config.debug_mode then print("In "..path.." directory, "..(found_source and "" or "did not").." found "..music_type.." for "..character_id) end
      return found_source
    elseif characters[character_id].favorite_stage then
      local path = (current_dir~="" and current_dir or "sounds/"..config.sounds_dir.."/").."music/"..characters[character_id].favorite_stage
      if any_supported_extension(path.."/normal_music") then
        local found_source = get_from_supported_extensions(path.."/"..music_type, true)
        if config.debug_mode then print("In "..path.." directory, "..(found_source and "" or "did not").." found "..music_type.." for "..character_id) end
        return found_source
      end
    end
  end
  
  return characters[default_character_id].musics[music_type]
end

local function init_variations_sfx(character_id, sfx_array, sfx_name, first_sound)
  local sound_name = sfx_name..1
  if first_sound then
    -- "combo" in others will be stored in "combo1" in combos
    sfx_array[1] = first_sound
    first_sound = nil
  else
    local sound = find_character_SFX(character_id, sound_name)
    if sound then
      sfx_array[1] = sound
    end
  end

  -- search for all variations
  local sfx_count = 1
  while sfx_array[sfx_count] do
    sfx_count = sfx_count+1
    sound_name = sfx_name..sfx_count
    local sound = find_character_SFX(character_id, sound_name)
    if sound then
      sfx_array[sfx_count] = sound
    end
  end
end

function Character.assert_requirements_met(self)
  assert(self.sounds.others["chain"], "Character SFX chain for "..self.id.." was not loaded.")
  assert(#self.sounds.combos ~= 0, "Character SFX combo for "..self.id.." was not loaded.")
  for k, music_type in ipairs(required_char_music) do
    assert(self.musics[music_type], music_type.." for "..self.id.." was not loaded.")
  end
end

function Character.stop_sounds(self)
  music_t = {}

  -- SFX
  for _, sound_table in ipairs(self.sounds) do
    if type(sound_table) == "table" then
      for _,sound in pairs(sound_table) do
        sound:stop()
      end
    end
  end

  -- music
  for _, music in ipairs(self.musics) do
    if self.musics[music] then
      self.musics[music]:stop()
    end
  end
end

function Character.play_selection_sfx(self)
  if not SFX_mute and #self.sounds.selections ~= 0 then
    self.sounds.selections[math.random(#self.sounds.selections)]:play()
  end
end

function Character.preload(self)
  print("preloading "..self.id)
  self:other_data_init()
  self:graphics_init(false,false)
  self:sound_init(false,false)
end

function Character.load(self,instant)
  print("loading "..self.id)
  self:graphics_init(true,(not instant))
  self:sound_init(true,(not instant))
  self:assert_requirements_met()
  self.fully_loaded = true
  print("loaded "..self.id)
end

function Character.unload(self)
  print("unloading "..self.id)
  self:graphics_uninit()
  self:sound_uninit()
  self.fully_loaded = false
  print("unloaded "..self.id)
end

function characters_init()
  characters = {} -- holds all characters, most of them will not be fully loaded
  characters_ids = {} -- holds all characters ids
  characters_ids_for_current_theme = {} -- holds characters ids for the current theme, those characters will appear in the lobby
  characters_ids_by_display_names = {} -- holds keys to array of character ids holding that name

  if config.use_default_characters then
    -- retrocompatibility with older versions and mods
    characters_ids = deepcpy(default_characters_ids)
    characters_ids[#characters_ids+1] = default_character_id;
    characters_ids_for_current_theme = deepcpy(default_characters_ids)
    for _,character_id in ipairs(characters_ids) do
      characters[character_id] = Character(character_id)
    end
  else
    -- new system with characters belonging to their own folder and characters.txt detailing current characters
    local raw_dir_list = love.filesystem.getDirectoryItems("characters")
    for _,v in ipairs(raw_dir_list) do
      local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
      if love.filesystem.getInfo("characters/"..v) and start_of_v ~= prefix_of_ignored_dirs then
        characters[v] = Character(v)
        characters_ids[#characters_ids+1] = v
      end
    end

    if love.filesystem.getInfo("assets/"..config.assets_dir.."/characters.txt") then
      for line in love.filesystem.lines("assets/"..config.assets_dir.."/characters.txt") do
        line = trim(line) -- remove whitespace
        if love.filesystem.getInfo("characters/"..line) then
          -- found at least a valid character in a characters.txt file
          if characters[line] then
            characters_ids_for_current_theme[#characters_ids_for_current_theme+1] = line
            print("found a valid character:"..characters_ids_for_current_theme[#characters_ids_for_current_theme])
          end
        end
      end
    end

    local function has_exactly_all_default_ids()
      if #characters_ids ~= #default_characters_ids then
        return false
      end
      for _,id in ipairs(default_characters_ids) do
        if not characters[id] then
          return false
        end
      end
      return true
    end
  
    -- all characters case
    if #characters_ids_for_current_theme == 0 then
      -- kinda retrocompatibility stuff: order the characters as the legacy order if they are exactly the default ones
      if has_exactly_all_default_ids() then
        characters_ids_for_current_theme = shallowcpy(default_characters_ids)
      else
        characters_ids_for_current_theme = shallowcpy(characters_ids)
      end
    end

    characters_ids[#characters_ids+1] = default_character_id;
    characters[default_character_id] = Character(default_character_id)
  end

  -- init default first, as it is used as a fallback we initialize it fully
  characters[default_character_id]:preload()
  characters[default_character_id]:load(true)
  
  -- actual init for all characters (default is initialized twice but that's 'okay', it's cheap enough)
  for _,character in pairs(characters) do
    character:preload()

    if characters_ids_by_display_names[character.display_name] then
      characters_ids_by_display_names[character.display_name][#characters_ids_by_display_names[character.display_name]+1] = character.id
    else
      characters_ids_by_display_names[character.display_name] = { character.id }
    end
  end

  -- fix config character if it's missing
  if not config.character or not characters[config.character] then
    config.character = uniformly(characters_ids_for_current_theme)
  end

  character_loader_load(config.character)
  character_loader_wait()
end

function Character.graphics_init(self,full,yields)
  local character_images = full and other_character_images or basic_character_images
  if config.use_default_characters and self.id ~= default_character_id then
    for _,image_name in ipairs(character_images) do
      self.images[image_name] = load_img(self.id.."/"..image_name..".png")
      if not self.images[image_name] then
        self.images[image_name] = load_img(image_name..".png","characters/"..self.id, "characters/__default")
      end
      if yields then coroutine.yield() end
    end
  else
    for _,image_name in ipairs(character_images) do
      self.images[image_name] = load_img(image_name..".png","characters/"..self.id, "characters/__default")
      if yields then coroutine.yield() end
    end
  end
end

function Character.graphics_uninit(self)
  for _,image_name in ipairs(other_character_images) do
    self.images[image_name] = nil
  end
end

function Character.apply_config_volume(self)
  set_volume(self.sounds, config.SFX_volume/100)
  set_volume(self.musics, config.music_volume/100)
end

function Character.sound_init(self,full,yields)
  -- SFX
  local character_sfx = full and other_characters_sfx or basic_characters_sfx
  for _, sound in ipairs(character_sfx) do
    self.sounds.others[sound] = find_character_SFX(self.id, sound, characters[default_character_id].sounds.others[sound])
    if not self.sounds.others[sound] then
      print("could not find "..sound.." for "..self.id)
      if string.find(sound, "chain") then
        self.sounds.others[sound] = find_character_SFX(self.id, "chain")
      elseif string.find(sound, "combo") then 
        self.sounds.others[sound] = find_character_SFX(self.id, "combo")
      end
    end
    if yields then coroutine.yield() end
  end

  if not full then
    init_variations_sfx(self.id, self.sounds.selections, "selection", self.sounds.others["selection"])
    if yields then coroutine.yield() end
  else
    init_variations_sfx(self.id, self.sounds.combos, "combo", self.sounds.others["combo"])
    if yields then coroutine.yield() end
    init_variations_sfx(self.id, self.sounds.combo_echos, "combo_echo", self.sounds.others["combo_echo"])
    if yields then coroutine.yield() end
    init_variations_sfx(self.id, self.sounds.wins, "win", self.sounds.others["win"])
    if yields then coroutine.yield() end
    init_variations_sfx(self.id, self.sounds.garbage_matches, "garbage_match", self.sounds.others["garbage_match"])
    if yields then coroutine.yield() end
  end

  -- music
  local character_musics = full and other_characters_musics or basic_characters_musics
  for _, music in ipairs(character_musics) do
    self.musics[music] = find_music(self.id, music)
    -- Set looping status for music.
    -- Intros won't loop, but other parts should.
    if self.musics[music] then
      if not string.find(music, "start") then
        self.musics[music]:setLooping(true)
      else
        self.musics[music]:setLooping(false)
      end
    end
    if yields then coroutine.yield() end
  end

  self:apply_config_volume()
end

function Character.sound_uninit(self)
  -- SFX
  for _,sound in ipairs(other_characters_sfx) do
    self.sounds.others[sound] = nil
  end
  self.sounds.combos = {}
  self.sounds.combo_echos = {}
  self.sounds.wins = {}
  self.sounds.garbage_matches = {}

  -- music
  for _,music in ipairs(other_characters_musics) do
    self.musics[music] = nil
  end
end
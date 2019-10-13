  -- Stuff defined in this file:
  --  . the data structure that store a character's data
local min, pairs, deepcpy = math.min, pairs, deepcpy
local max = math.max

local character_images = {"topleft", "botleft", "topright", "botright",
                  "top", "bot", "left", "right", "face", "pop",
                  "doubleface", "filler1", "filler2", "flash",
                  "portrait", "icon"}

local required_char_SFX = {"chain", "combo"}
  -- @CardsOfTheHeart says there are 4 chain sfx: --x2/x3, --x4, --x5 is x2/x3 with an echo effect, --x6+ is x4 with an echo effect
  -- combo sounds, on the other hand, can have multiple variations, hence combo, combo2, combo3 (...) and combo_echo, combo_echo2...
local allowed_char_SFX = {"chain", "combo", "combo_echo", "chain_echo", "chain2" ,"chain2_echo", "garbage_match", "selection", "win"}
local required_char_music = {"normal_music", "danger_music"}
local allowed_char_music = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}

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
    s.sounds = {}
    s.musics = {}
  end)

function Character.other_data_init(self)
  local dirs_to_check = { "characters/",
                        "assets/"..config.assets_dir.."/",
                        "assets/"..default_assets_dir.."/"}

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

function Character.graphics_init(self)
  local dir_to_check = "assets/"..config.assets_dir
  if love.filesystem.getInfo("characters/"..self.id) then
    dir_to_check = "characters"
  end
  self.images = {}
  for k,image_name in ipairs(character_images) do
    self.images[image_name] = load_img(self.id.."/"..image_name..".png",dir_to_check)
  end

end

local function find_character_SFX(character_id, SFX_name)
  local dirs_to_check = { "characters/",
                          "sounds/"..config.sounds_dir.."/characters/",
                          "sounds/"..default_sounds_dir.."/characters/"}
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
  --if not found in above directories:
  return nil
end

--returns audio source based on character and music_type (normal_music, danger_music, normal_music_start, or danger_music_start)
local function find_music(character, music_type)
  local dirs_to_check = { "",
                        "sounds/"..config.sounds_dir.."/",
                        "sounds/"..default_sounds_dir.."/"}
  for k,current_dir in ipairs(dirs_to_check) do
    local path = current_dir.."characters/"..character
    local character_dir_overrides = any_supported_extension(path.."/normal_music")
    if character_dir_overrides then -- character has control over their musics, no fallback allowed!
      local found_source = get_from_supported_extensions(path.."/"..music_type, true)
      if found_source then
        if config.debug_mode then print("In "..path.." directory, found "..music_type.." for "..character) end
      else
        if config.debug_mode then print("In "..path.." directory, did not find "..music_type.." for "..character) end
      end
      return found_source
    elseif k > 1 then -- ignore this case for root directory
      if characters[character].favorite_stage then
        local path = current_dir.."music/"..characters[character].favorite_stage
        stage_dir_overrides = any_supported_extension(path.."/normal_music")
        if stage_dir_overrides then
          local found_source = get_from_supported_extensions(path.."/"..music_type, true)
          if found_source then
            if config.debug_mode then print("In "..path.."directory, found "..music_type.." for "..character) end
          else
            if config.debug_mode then print("In "..path.." directory, did not find "..music_type.." for "..character) end
          end
          return found_source
        end
      end
    end
  end
  return nil
end

local function init_variations_sfx(character_id, sfx_table, sfx_name, first_sound)
  local sound = sfx_name..1
  if first_sound then
    -- "combo" in others will be stored in "combo1" in combos
    sfx_table[sound] = first_sound
    first_sound = nil
  else
    sfx_table[sound] = find_character_SFX(character_id, sound)
  end

  -- search for all variations
  local sfx_count = 0
  while sfx_table[sound] do
    sfx_count = sfx_count+1
    sound = sfx_name..(sfx_count+1)
    sfx_table[sound] = find_character_SFX(character_id, sound)
  end
  -- print(character.." has "..sfx_count.." variation(s) of "..sfx_name)
  return sfx_count
end


function Character.sound_init(self)
  -- SFX
  self.sounds = { combos = {}, combo_count = 0, combo_echos = {}, combo_echo_count = 0, selections = {}, selection_count = 0, wins = {}, win_count = 0, others = {} }
  for _, sound in ipairs(allowed_char_SFX) do
    self.sounds.others[sound] = find_character_SFX(self.id, sound)
    if not self.sounds.others[sound] then
      if string.find(sound, "chain") then
        self.sounds.others[sound] = find_character_SFX(self.id, "chain")
      elseif string.find(sound, "combo") then 
        self.sounds.others[sound] = find_character_SFX(self.id, "combo")
      end
    end
  end

  self.sounds.combo_count = init_variations_sfx(self.id, self.sounds.combos, "combo", self.sounds.others["combo"])
  self.sounds.combo_echo_count = init_variations_sfx(self.id, self.sounds.combo_echos, "combo_echo", self.sounds.others["combo_echo"])
  self.sounds.selection_count = init_variations_sfx(self.id, self.sounds.selections, "selection", self.sounds.others["selection"])
  self.sounds.win_count = init_variations_sfx(self.id, self.sounds.wins, "win", self.sounds.others["win"])
  
  -- music
  self.musics = {}
  for _, music_type in ipairs(allowed_char_music) do
    self.musics[music_type] = find_music(self.id, music_type)
    -- Set looping status for music.
    -- Intros won't loop, but other parts should.
    if self.musics[music_type] then
      if not string.find(music_type, "start") then
        self.musics[music_type]:setLooping(true)
      else
        self.musics[music_type]:setLooping(false)
      end
    end
  end
end

function Character.assert_requirements_met(self)
  assert(self.sounds.others["chain"], "Character SFX chain for "..self.id.." was not loaded.")
  assert(self.sounds.combo_count ~= 0, "Character SFX combo for "..self.id.." was not loaded.")
  for k, music_type in ipairs(required_char_music) do
    assert(self.musics[music_type], music_type.." for "..self.id.." was not loaded.")
  end
end

function Character.stop_sounds(self)
  music_t = {}

  -- SFX
  for k, sound_table in ipairs(self.sounds) do
    if type(sound_table) == "table" then
      for _,sound in pairs(sound_table) do
        sound:stop()
      end
    end
  end

  -- music
  for k, music_type in ipairs(allowed_char_music) do
    if self.musics[music_type] then
      self.musics[music_type]:stop()
    end
  end
end

function Character.play_selection_sfx(self)
  if not SFX_mute and self.sounds.selection_count ~= 0 then
    self.sounds.selections["selection" .. math.random(self.sounds.selection_count)]:play()
  end
end

local default_characters_ids = {"lip", "windy", "sherbet", "thiana", "ruby",
              "elias", "flare", "neris", "seren", "phoenix", 
              "dragon", "thanatos", "cordelia",  "lakitu", 
              "bumpty", "poochy", "wiggler", "froggy", "blargg",
              "lungefish", "raphael", "yoshi", "hookbill",
              "navalpiranha", "kamek", "bowser"}

function characters_init()
  characters = {} -- holds all characters, most of them will not be fully loaded
  characters_ids = {} -- holds all characters ids
  characters_ids_for_current_theme = {} -- holds characters ids for the current theme, those characters will appear in the lobby

  if config.use_default_characters then
    -- retrocompatibility with older versions and mods
    characters_ids = deepcpy(default_characters_ids)
    characters_ids_for_current_theme = deepcpy(default_characters_ids)
    for i=1,#characters_ids do
      characters[characters_ids[i]] = Character(characters_ids[i])
    end
    return
  end

  local raw_dir_list = love.filesystem.getDirectoryItems("characters")
  for _,v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
    if love.filesystem.getInfo("characters/"..v) and start_of_v ~= prefix_of_ignored_dirs then
      characters[v] = Character(v)
      characters_ids[#characters_ids+1] = v
    end
  end

  if love.filesystem.getInfo("assets/"..config.assets_dir.."/characters.txt") then
    for line in love.filesystem.lines(current_dir.."/characters.txt") do
      if love.filesystem.getInfo("characters/"..line) then
        -- found at least a valid character in a characters.txt file
        if characters[line] then
          characters_ids_for_current_theme[#characters_ids_for_current_theme+1] = line
          print("found a valid character:"..characters_ids_for_current_theme[#characters_ids_for_current_theme])
        end
      end
    end
  end

  if #characters_ids_for_current_theme == 0 then
    -- all characters case
    characters_ids_for_current_theme = deepcpy(characters_ids)
  end
end
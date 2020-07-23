require("character_loader")

  -- Stuff defined in this file: the data structure that store a character's data

local basic_images = { "icon" }
local other_images = {"topleft", "botleft", "topright", "botright",
                  "top", "bot", "left", "right", "face", "pop",
                  "doubleface", "filler1", "filler2", "flash",
                  "portrait"}
local defaulted_images = { icon=true, topleft=true, botleft=true, topright=true, botright=true,
                  top=true, bot=true, left=true, right=true, face=true, pop=true,
                  doubleface=true, filler1=true, filler2=true, flash=true,
                  portrait=true } -- those images will be defaulted if missing
local basic_sfx = {"selection"}
local other_sfx = {"chain", "combo", "combo_echo", "chain_echo", "chain2" ,"chain2_echo", "garbage_match", "garbage_land", "win", "taunt_up", "taunt_down"}
local defaulted_sfxs = {} -- those sfxs will be defaulted if missing
local basic_musics = {}
local other_musics = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}
local defaulted_musics = {} -- those musics will be defaulted if missing

local default_character = nil -- holds default assets fallbacks

local e_chain_style = { classic=0, per_chain=1 }

Character = class(function(self, full_path, folder_name)
    self.path = full_path -- string | path to the character folder content
    self.id = folder_name -- string | id of the character, specified in config.json
    self.display_name = self.id -- string | display name of the stage
    self.stage = nil -- string | stage that get selected upon doing the super selection of that character
    self.panels = nil -- string | panels that get selected upon doing the super selection of that character
    self.sub_characters = {} -- stringS | either empty or with two elements at least; holds the sub characters IDs for bundle characters
    self.images = {}
    self.sounds = { combos = {}, combo_echos = {}, chains = {}, selections = {}, wins = {}, garbage_matches = {}, garbage_lands = {}, taunt_ups = {}, taunt_downs = {}, others = {} }
    self.musics = {}
    self.flag = nil -- string | flag to be displayed in the select screen
    self.fully_loaded = false
    self.is_visible = true
    self.chain_style = e_chain_style.classic
  end)

function Character.json_init(self)
  local read_data = {}
  local config_file, err = love.filesystem.newFile(self.path.."/config.json", "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    for k,v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end

  if read_data.id and type(read_data.id) == "string" then
    self.id = read_data.id

    -- sub ids for bundles
    if read_data.sub_ids and type(read_data.sub_ids) == "table" then
      self.sub_characters = read_data.sub_ids
    end  
    -- display name
    if read_data.name and type(read_data.name) == "string" then
      self.display_name = read_data.name
    end
    -- is visible
    if read_data.visible ~= nil and type(read_data.visible) == "boolean" then
      self.is_visible = read_data.visible
    elseif read_data.visible and type(read_data.visible) == "string" then
      self.is_visible = read_data.visible=="true"
    end

    -- chain_style
    if read_data.chain_style and type(read_data.chain_style) == "string" then
      self.chain_style = read_data.chain_style=="per_chain" and e_chain_style.per_chain or e_chain_style.classic
    end

    -- associated stage
    if read_data.stage and type(read_data.stage) == "string" and stages[read_data.stage] and not stages[read_data.stage]:is_bundle() then
      self.stage = read_data.stage
    end
    -- associated panel
    if read_data.panels and type(read_data.panels) == "string" and panels[read_data.panels] then
      self.panels = read_data.panels
    end

    -- flag
    if read_data.flag and type(read_data.flag) == "string" then
      self.flag = read_data.flag
    end
    
    return true
  end

  return false
end

function Character.stop_sounds(self)
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
    return true
  end
  return false
end

function Character.play_combo_chain_sfx(self,chain_combo)
  if not SFX_mute then
    -- stop previous sounds if any
    for _,v in pairs(self.sounds.combos) do
      v:stop()
    end
    for _,v in pairs(self.sounds.combo_echos) do
      v:stop()
    end
    if self.chain_style == e_chain_style.classic then
      self.sounds.others["chain"]:stop()
      self.sounds.others["chain2"]:stop()
      self.sounds.others["chain_echo"]:stop()
      self.sounds.others["chain2_echo"]:stop()
    else --elseif self.chain_style == e_chain_style.per_chain then
      for _,v in pairs(self.sounds.chains) do
        for _,w in pairs(v) do
          w:stop()
        end
      end
    end

    -- play combos or chains
    if chain_combo[1] == e_chain_or_combo.combo then
      -- either combos or combo_echos
      self.sounds[chain_combo[2]][math.random(#self.sounds[chain_combo[2]])]:play()
    else --elseif chain_combo[1] == e_chain_or_combo.chain then 
      local length = chain_combo[2]
      if self.chain_style == e_chain_style.classic then
        if length < 4 then 
          self.sounds.others["chain"]:play()
        elseif length == 4 then
          self.sounds.others["chain2"]:play()
        elseif length == 5 then
          self.sounds.others["chain_echo"]:play()
        elseif length >= 6 then
          self.sounds.others["chain2_echo"]:play()
        end
      else --elseif self.chain_style == e_chain_style.per_chain then
        length = math.max(length, 2)
        if length > 13 then
          length = 0
        end
        self.sounds.chains[length][math.random(#self.sounds.chains[length])]:play()
      end
    end
  end
end

function Character.preload(self)
  print("preloading character "..self.id)
  self:graphics_init(false,false)
  self:sound_init(false,false)
end

function Character.load(self,instant)
  print("loading character "..self.id)
  self:graphics_init(true,(not instant))
  self:sound_init(true,(not instant))
  self.fully_loaded = true
  print("loaded character "..self.id)
end

function Character.unload(self)
  print("unloading character "..self.id)
  self:graphics_uninit()
  self:sound_uninit()
  self.fully_loaded = false
  print("unloaded character "..self.id)
end

local function add_characters_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = lfs.getDirectoryItems(path)
  for i,v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
    if start_of_v ~= prefix_of_ignored_dirs then
      local current_path = path.."/"..v
      if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
        -- call recursively: facade folder
        add_characters_from_dir_rec(current_path)

        -- init stage: 'real' folder
        local character = Character(current_path,v)
        local success = character:json_init()

        if success then
          if characters[character.id] ~= nil then
            print(current_path.." has been ignored since a character with this id has already been found")
          else
            characters[character.id] = character
            characters_ids[#characters_ids+1] = character.id
            -- print(current_path.." has been added to the character list!")
          end
        end
      end
    end
  end
end

local function fill_characters_ids()
  -- check validity of bundle characters
  local invalid = {}
  local copy_of_characters_ids = shallowcpy(characters_ids)
  characters_ids = {} -- clean up
  for _,character_id in ipairs(copy_of_characters_ids) do
    local character = characters[character_id]
    if #character.sub_characters > 0 then -- bundle character (needs to be filtered if invalid)
      local copy_of_sub_characters = shallowcpy(character.sub_characters)
      character.sub_characters = {}
      for _,sub_character in ipairs(copy_of_sub_characters) do
        if characters[sub_character] and #characters[sub_character].sub_characters == 0 then -- inner bundles are prohibited
          character.sub_characters[#character.sub_characters+1] = sub_character
          print(character.id.." has "..sub_character.." as part of its subcharacters.")
        end
      end

      if #character.sub_characters < 2 then
        invalid[#invalid+1] = character_id -- character is invalid
        print(character.id.." (bundle) is being ignored since it's invalid!")
      else
        characters_ids[#characters_ids+1] = character_id
        print(character.id.." (bundle) has been added to the character list!")
      end
    else -- normal character
      characters_ids[#characters_ids+1] = character_id
      print(character.id.." has been added to the character list!")
    end
  end

  -- characters are removed outside of the loop since erasing while iterating isn't working
  for _,invalid_character in pairs(invalid) do
    characters[invalid_character] = nil
  end
end

function characters_init()
  characters = {} -- holds all characters, most of them will not be fully loaded
  characters_ids = {} -- holds all characters ids
  characters_ids_for_current_theme = {} -- holds characters ids for the current theme, those characters will appear in the lobby
  characters_ids_by_display_names = {} -- holds keys to array of character ids holding that name

  add_characters_from_dir_rec("characters")
  fill_characters_ids()

  if #characters_ids == 0 then
    recursive_copy("default_data/characters", "characters")
    add_characters_from_dir_rec("characters")
    fill_characters_ids()
  end

  if love.filesystem.getInfo("themes/"..config.theme.."/characters.txt") then
    for line in love.filesystem.lines("themes/"..config.theme.."/characters.txt") do
      line = trim(line) -- remove whitespace
      if characters[line] then
        -- found at least a valid character in a characters.txt file
        characters_ids_for_current_theme[#characters_ids_for_current_theme+1] = line
      end
    end
  else
    for _,character_id in ipairs(characters_ids) do
      if characters[character_id].is_visible then
        characters_ids_for_current_theme[#characters_ids_for_current_theme+1] = character_id
      end
    end
  end

  -- all characters case
  if #characters_ids_for_current_theme == 0 then
    characters_ids_for_current_theme = shallowcpy(characters_ids)
  end

  -- fix config character if it's missing
  if not config.character or ( config.character ~= random_character_special_value and not characters[config.character] ) then
    config.character = uniformly(characters_ids_for_current_theme)
  end

  -- actual init for all characters, starting with the default one
  default_character = Character("characters/__default", "__default")
  default_character:preload()
  default_character:load(true)

  for _,character in pairs(characters) do
    character:preload()

    if characters_ids_by_display_names[character.display_name] then
      characters_ids_by_display_names[character.display_name][#characters_ids_by_display_names[character.display_name]+1] = character.id
    else
      characters_ids_by_display_names[character.display_name] = { character.id }
    end
  end

  if config.character ~= random_character_special_value and not characters[config.character]:is_bundle() then
    character_loader_load(config.character)
    character_loader_wait()
  end
end

function Character.is_bundle(self)
  return #self.sub_characters > 1
end

function Character.graphics_init(self,full,yields)
  local character_images = full and other_images or basic_images
  for _,image_name in ipairs(character_images) do
    self.images[image_name] = load_img_from_supported_extensions(self.path.."/"..image_name)
    if not self.images[image_name] and defaulted_images[image_name] and not self:is_bundle() then
      self.images[image_name] = default_character.images[image_name]
    end
    if yields then coroutine.yield() end
  end
end

function Character.graphics_uninit(self)
  for _,image_name in ipairs(other_images) do
    self.images[image_name] = nil
  end
end

function Character.init_sfx_variants(self, sfx_array, sfx_name, sfx_suffix_at_higher_count)
  sfx_suffix_at_higher_count = sfx_suffix_at_higher_count or ""

  -- be careful is we are to support chain2X sfx since chain21 will be found and used for chain2 (unwanted behavior), might be a future bug!
  local sound_name = sfx_name..sfx_suffix_at_higher_count..1
  if self.sounds.others[sfx_name] then
    -- "combo" in others will be stored in 'combos' and 'others' will be freed from it
    sfx_array[1] = self.sounds.others[sfx_name]
    self.sounds.others[sfx_name] = nil
  elseif sfx_suffix_at_higher_count == "" then
    local sound = load_sound_from_supported_extensions(self.path.."/"..sound_name, false)
    if sound then
      sfx_array[1] = sound
    end
  else
    local sound = load_sound_from_supported_extensions(self.path.."/"..sfx_name, false)
    if sound then
      sfx_array[1] = sound
    end
  end

  -- search for all variants
  local sfx_count = 1
  while sfx_array[sfx_count] do
    sfx_count = sfx_count+1
    sound_name = sfx_name..sfx_suffix_at_higher_count..sfx_count
    local sound = load_sound_from_supported_extensions(self.path.."/"..sound_name, false)
    if sound then
      sfx_array[sfx_count] = sound
    end
  end
end

function Character.apply_config_volume(self)
  set_volume(self.sounds, config.SFX_volume/100)
  set_volume(self.musics, config.music_volume/100)
end

function Character.sound_init(self,full,yields)
  -- SFX
  local character_sfx = full and other_sfx or basic_sfx
  for _, sfx in ipairs(character_sfx) do
    self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/"..sfx, false)

    -- fallback case: chain/combo can be used for the other one if missing and for the longer names versions ("combo" used for "combo_echo" for instance)
    if not self.sounds.others[sfx] then
      if sfx == "combo" then
        self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/chain", false)
      elseif sfx == "chain" then 
        self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/combo", false)
      elseif sfx == "combo_echo" then 
        self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/combo", false)
        if not self.sounds.others[sfx] then
          self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/chain", false)
        end
      elseif string.find(sfx, "chain") then
        self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/chain", false)
      elseif string.find(sfx, "combo") then 
        self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/combo", false)
      end
    end
    if not self.sounds.others[sfx] and defaulted_sfxs[sfx] and not self:is_bundle() then
      self.sounds.others[sfx] = default_character.sounds.others[sfx] or zero_sound
    end
    if yields then coroutine.yield() end
  end

  if not full then
    self:init_sfx_variants(self.sounds.selections, "selection")
    if yields then coroutine.yield() end
  elseif not self:is_bundle() then
    if self.chain_style == e_chain_style.per_chain then
      -- actual init of sounds
      for i=2,13 do
        self.sounds.chains[i] = {}
        self:init_sfx_variants(self.sounds.chains[i], "chain"..i, "_")
        if #self.sounds.chains[i] ~= 0 then
          print("chain"..i.." has "..#self.sounds.chains[i].." variant(s)")
        end
      end
        self.sounds.chains[0] = {}
      self:init_sfx_variants(self.sounds.chains[0], "chain0", "_")
      -- make it so every values in the chain array point to a properly filled arrays of sfx (last index used as fallback)
      if #self.sounds.chains[2] == 0 then
        self.sounds.chains[2][1] = self.sounds.others["chain"]
      end
      local last_filled_chains = 2
      for i=3,13 do
        if #self.sounds.chains[i] == 0 then
          self.sounds.chains[i] = self.sounds.chains[last_filled_chains] -- points to the same array, not an actual copy
        else
          last_filled_chains = i
        end
      end
      if #self.sounds.chains[0] == 0 then
        self.sounds.chains[0] = self.sounds.chains[last_filled_chains]
      end
      if yields then coroutine.yield() end
    end
    self:init_sfx_variants(self.sounds.combos, "combo")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.combo_echos, "combo_echo")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.wins, "win")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.garbage_matches, "garbage_match")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.garbage_lands, "garbage_land")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.taunt_downs, "taunt_down")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.taunt_ups, "taunt_up")
    if yields then coroutine.yield() end
  end

  -- music
  local character_musics = full and other_musics or basic_musics
  for _, music in ipairs(character_musics) do
    self.musics[music] = load_sound_from_supported_extensions(self.path.."/"..music, true)
    -- Set looping status for music.
    -- Intros won't loop, but other parts should.
    if self.musics[music] then
      if not string.find(music, "start") then
        self.musics[music]:setLooping(true)
      else
        self.musics[music]:setLooping(false)
      end
    elseif not self.musics[music] and defaulted_musics[music] and not self:is_bundle() then
      self.musics[music] = default_character.musics[music] or zero_sound
    end

    if yields then coroutine.yield() end
  end
  
  self:apply_config_volume()
end

function Character.sound_uninit(self)
  -- SFX
  for _,sound in ipairs(other_sfx) do
    self.sounds.others[sound] = nil
  end
  self.sounds.combos = {}
  self.sounds.combo_echos = {}
  self.sounds.wins = {}
  self.sounds.garbage_matches = {}
  self.sounds.garbage_lands = {}

  -- music
  for _,music in ipairs(other_musics) do
    self.musics[music] = nil
  end
end
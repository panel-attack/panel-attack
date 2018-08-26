--sets the volume of a single source or table of sources
supported_sound_formats = {".mp3",".ogg", ".it"}
function set_volume(source, new_volume)
  if config.debug_mode then print("set_volume called") end
  if type(source) == "table" then
    for _,v in pairs(source) do
      set_volume(v, new_volume)
    end
  else
    source:setVolume(new_volume)
  end
end

-- returns a new sound effect if it can be found, else returns nil
function find_sound(sound_name, dirs_to_check)
  local found_source
  for k,dir in ipairs(dirs_to_check) do
    found_source = check_supported_extensions(dir..sound_name)
    if found_source then
      return found_source
    end
  end
  return nil
end

function find_generic_SFX(SFX_name)
  local dirs_to_check = {"sounds/"..sounds_dir.."/SFX/",
                         "sounds/"..default_sounds_dir.."/SFX/"}
  return find_sound(SFX_name, dirs_to_check)
end

function find_character_SFX(character, SFX_name)
  local dirs_to_check = {"sounds/"..sounds_dir.."/characters/",
                         "sounds/"..default_sounds_dir.."/characters/"}
  local cur_dir_contains_chain
  for k,current_dir in ipairs(dirs_to_check) do
    --Note: if there is a chain or a combo, but not the other, return the same SFX for either inquiry.
    --This way, we can always depend on a character having a combo and a chain SFX.
    --If they are missing others, that's fine.
    --(ie. some characters won't have "match_garbage" or a fancier "chain-x6")
    local cur_dir_chain = check_supported_extensions(current_dir.."/"..character.."/chain")
    if SFX_name == "chain" and cur_dir_chain then 
      if config.debug_mode then print("loaded "..SFX_name.." for "..character) end
      return cur_dir_chain
    end
    local cur_dir_combo = check_supported_extensions(current_dir.."/"..character.."/combo")
    if SFX_name == "combo" and cur_dir_combo then 
      if config.debug_mode then print("loaded "..SFX_name.." for "..character) end
      return cur_dir_combo
    elseif SFX_name == "combo" and cur_dir_chain then
      if config.debug_mode then print("substituted found chain SFX for "..SFX_name.." for "..character) end
      return cur_dir_chain --in place of the combo SFX
    end
    if SFX_name == "chain" and cur_dir_combo then
      if config.debug_mode then print("substituted found combo SFX for "..SFX_name.." for "..character) end
      return cur_dir_combo
    end
    
    local other_requested_SFX = check_supported_extensions(current_dir.."/"..character.."/"..SFX_name)
    if other_requested_SFX then
      if config.debug_mode then print("loaded "..SFX_name.." for "..character) end
      return other_requested_SFX
    else
      if config.debug_mode then print("did not find "..SFX_name.." for "..character.." in current directory: "..current_dir) end
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
function find_music(character, music_type)
  local found_source
  local character_music_overrides_stage_music = check_supported_extensions("sounds/"..sounds_dir.."/characters/"..character.."/normal_music")
  if character_music_overrides_stage_music then
    found_source = check_supported_extensions("sounds/"..sounds_dir.."/characters/"..character.."/"..music_type)
    if found_source then
      if config.debug_mode then print("In selected sound directory, found "..music_type.." for "..character) end
    else
      if config.debug_mode then print("In selected sound directory, did not find "..music_type.." for "..character) end
    end
    return found_source
  else
    if stages[character] then
      sound_set_overrides_default_sound_set = check_supported_extensions("sounds/"..sounds_dir.."/music/"..stages[character].."/normal_music")
      if sound_set_overrides_default_sound_set then
        found_source = check_supported_extensions("sounds/"..sounds_dir.."/music/"..stages[character].."/"..music_type)
        if found_source then
          if config.debug_mode then print("In selected sound directory stages, found "..music_type.." for "..character) end
          
        else
          if config.debug_mode then print("In selected sound directory stages, did not find "..music_type.." for "..character) end
        end
        return found_source
      else
        found_source = check_supported_extensions("sounds/"..default_sounds_dir.."/music/"..stages[character].."/"..music_type)
        if found_source then
          if config.debug_mode then print("In default sound directory stages, found "..music_type.." for "..character) end
        else
          if config.debug_mode then print("In default sound directory stages, did not find "..music_type.." for "..character) end
        end
        return found_source
      end
    end
    return found_source
  end
  return nil
end

--returns a source, or nil if it could not find a file
function check_supported_extensions(path_and_filename)
  for k, extension in ipairs(supported_sound_formats) do
    if love.filesystem.isFile(path_and_filename..extension) then
      if string.find(path_and_filename, "music") then
        return love.audio.newSource(path_and_filename..extension)
      else
        return love.audio.newSource(path_and_filename..extension, "static")
      end
    end
  end
  return nil
end

function assert_requirements_met()
  --assert we have all required generic sound effects
  local SFX_requirements =  {"cur_move", "swap", "fanfare1", "fanfare2", "fanfare3", "game_over", "countdown", "go"}
  for k,v in ipairs(SFX_requirements) do
    assert(sounds.SFX[v], "SFX \""..v.."\"was not loaded")
  end
  local NUM_REQUIRED_GARBAGE_THUDS = 3
  for i=1, NUM_REQUIRED_GARBAGE_THUDS do
    assert(sounds.SFX.garbage_thud[i], "SFX garbage_thud "..i.."was not loaded")
  end
    --assert we have the required SFX and music for each character
  for i,name in ipairs(characters) do
    for k, sound in ipairs(required_char_SFX) do
      assert(sounds.SFX.characters[name][sound], "Character SFX"..sound.." for "..name.." was not loaded.")
    end
    for k, music_type in ipairs(required_char_music) do
      assert(sounds.music.characters[name][music_type], music_type.." for "..name.." was not loaded.")
    end
  end
  --assert pops have been loaded
  for popLevel=1,4 do
      for popIndex=1,10 do
          assert(sounds.SFX.pops[popLevel][popIndex], "SFX pop"..popLevel.."-"..popIndex.." was not loaded")
      end
  end
end

function stop_character_sounds(character)
  danger_music_intro_started = nil
  danger_music_intro_finished = nil
  danger_music_intro_playing = nil
  normal_music_intro_exists = nil
  normal_music_intro_started = nil
  normal_music_intro_finished = nil
  for k, sound in ipairs(allowed_char_SFX) do
    if sounds.SFX.characters[character][sound] then
      sounds.SFX.characters[character][sound]:stop()
    end
  end
  for k, music_type in ipairs(allowed_char_music) do
    if sounds.music.characters[character][music_type] then
      sounds.music.characters[character][music_type]:stop()
    end
  end
end

function sound_init()
  sounds_dir = config.sounds_dir or default_sounds_dir
  --sounds: SFX, music
  SFX_Fanfare_Play = 0
  SFX_GameOver_Play = 0
  SFX_GarbageThud_Play = 0
  sounds = {
    SFX = {
      cur_move = find_generic_SFX("move"),
      swap = find_generic_SFX("swap"),
      land = find_generic_SFX("land"),
      fanfare1 = find_generic_SFX("fanfare1"),
      fanfare2 = find_generic_SFX("fanfare2"),
      fanfare3 = find_generic_SFX("fanfare3"),
      game_over = find_generic_SFX("gameover"),
      countdown = find_generic_SFX("countdown"),
      go = find_generic_SFX("go"),
      garbage_thud = {
        find_generic_SFX("thud_1"),
        find_generic_SFX("thud_2"),
        find_generic_SFX("thud_3")
      },
      characters = {},
      pops = {}
    },
    music = {
      characters = {},
    }
  }
  required_char_SFX = {"chain", "combo"}
  -- @CardsOfTheHeart says there are 4 chain sfx: --x2/x3, --x4, --x5 is x2/x3 with an echo effect, --x6+ is x4 with an echo effect
  allowed_char_SFX = {"chain", "combo", "combo_echo", "chain_echo", "chain2" ,"chain2_echo", "garbage_match"}
  required_char_music = {"normal_music", "danger_music"}
  allowed_char_music = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}
  for i,name in ipairs(characters) do
    sounds.SFX.characters[name] = {}
    for k, sound in ipairs(allowed_char_SFX) do
      sounds.SFX.characters[name][sound] = find_character_SFX(name, sound)
      if not sounds.SFX.characters[name][sound] then
        if string.find(sound, "chain") then
          sounds.SFX.characters[name][sound] = find_character_SFX(name, "chain")
        elseif string.find(sound, "combo") then 
          sounds.SFX.characters[name][sound] = find_character_SFX(name, "combo")
        end
      end
    end
    sounds.music.characters[name] = {}
    for k, music_type in ipairs(allowed_char_music) do
      sounds.music.characters[name][music_type] = find_music(name, music_type)
    end
  end
  for popLevel=1,4 do
    sounds.SFX.pops[popLevel] = {}
    for popIndex=1,10 do
      sounds.SFX.pops[popLevel][popIndex] = find_generic_SFX("pop"..popLevel.."-"..popIndex)
    end
  end
  assert_requirements_met()
  
  love.audio.setVolume(config.master_volume/100)
  set_volume(sounds.SFX, config.SFX_volume/100)
  set_volume(sounds.music, config.music_volume/100) 
end
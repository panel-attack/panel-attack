--- Sound module
--- Handle sound effects, stage and charactes themes and volume of the game

--  This function sets the volume of a single source or table of sources
function set_volume(source, new_volume)
    -- Conditional with debug purposes
    if config.debug_mode then print("set_volume called") end
    if type(source) == "table" then
      for _,volume in pairs(source) do
        set_volume(volume, new_volume)
      end
    else
      source:setVolume(new_volume)
    end
end

-- This function returns a new sound effect if it can be found, else returns nil
function find_sound(sound_name, directories_to_check)
    local found_source
    for search_SFX,directory in ipairs(directories_to_check) do
      found_source = check_supported_extensions(directory..sound_name)
      if found_source then
        return found_source
      end
    end
    return nil
end

-- This function check directories that may have the desired sound effect
function find_generic_SFX(SFX_sound_name)
    local DIRECTORIES_TO_CHECK = {
        "sounds/"..sounds_dir.."/SFX/",
        "sounds/"..default_sounds_dir.."/SFX/"
    }
    return find_sound(SFX_sound_name, DIRECTORIES_TO_CHECK)
end

-- This function search for sound effects and then match it with specific character
function find_character_SFX(character, SFX_sound_name)
    local DIRECTORIES_TO_CHECK = {
        "sounds/"..sounds_dir.."/characters/",
        "sounds/"..default_sounds_dir.."/characters/"
    }
  
    -- variable initialized but never used in this file
    local cur_dir_contains_chain
  
    for k,currentDirectory in ipairs(DIRECTORIES_TO_CHECK) do
      -- note: if there is a chain or a combo, but not the other, return the same SFX for either inquiry.
      -- this way, we can always depend on a character having a combo and a chain SFX.
      -- if they are missing others, that's fine.
      -- (ie. some characters won't have "match_garbage" or a fancier "chain-x6")
    
      local current_directory_has_chain_sound = check_supported_extensions(currentDirectory.."/"..character.."/chain")
      local current_directory_has_combo_sound = check_supported_extensions(currentDirectory.."/"..character.."/combo")
      local other_requested_SFX = check_supported_extensions(currentDirectory.."/"..character.."/"..SFX_sound_name)


      -- Conditionals to check tha directories has specific sound effects
      -- SFXSounName probably a misspelled global variable
      if SFXSounName == "chain" and current_directory_has_chain_sound then 
        if config.debug_mode then print("loaded "..SFX_sound_name.." for "..character) end
        return current_directory_has_chain_sound
      end
      if SFX_sound_name == "combo" and current_directory_has_combo_sound then 
        if config.debug_mode then print("loaded "..SFX_sound_name.." for "..character) end
        return current_directory_has_combo_sound
      elseif SFX_sound_name == "combo" and current_directory_has_chain_sound then
        if config.debug_mode then print("substituted found chain SFX for "..SFX_sound_name.." for "..character) end
        return current_directory_has_chain_sound -- in place of the combo SFX
      end
      if SFX_sound_name == "chain" and current_directory_has_combo_sound then
        if config.debug_mode then print("substituted found combo SFX for "..SFX_sound_name.." for "..character) end
        return current_directory_has_combo_sound
      end
    
      if other_requested_SFX then
        if config.debug_mode then print("loaded "..SFX_sound_name.." for "..character) end
        return other_requested_SFX
      else
        if config.debug_mode then print("did not find "..SFX_sound_name.." for "..character.." in current directory: "..current_dir) end
      end
      if current_directory_has_chain_sound or current_directory_has_combo_sound --[[and we didn't find the requested SFX in this dir]] then
        if config.debug_mode then print("chain or combo was provided, but "..SFX_sound_name.." was not.") end
        return nil -- don't continue looking in other fallback directories,
    -- else
      -- keep looking
      end
    end
    -- if not found in above directories:
    return nil
end

-- This function returns audio source based on character and music_type (normal_music, danger_music, normal_music_start, or danger_music_start)
function find_music(character, music_type)
  
    local found_source
    local character_theme_overrides_stage_theme = check_supported_extensions("sounds/"..sounds_dir.."/characters/"..character.."/normal_music")
  
    -- Conditionals to select if the character sound theme needs to overrides the current stage sound theme  
    if character_theme_overrides_stage_theme then
      found_source = check_supported_extensions("sounds/"..sounds_dir.."/characters/"..character.."/"..music_type)
      if found_source then
        if config.debug_mode then print("In selected sound directory, found "..music_type.." for "..character) end
      else
        if config.debug_mode then print("In selected sound directory, did not find "..music_type.." for "..character) end
      end
      return found_source
    else
      if stages[character] then
        soundSetOverridesDefaultSoundSet = check_supported_extensions("sounds/"..sounds_dir.."/music/"..stages[character].."/normal_music")
        if soundSetOverridesDefaultSoundSet then
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

-- This function returns a source, or nil if it could not find a file
function check_supported_extensions(path_and_filename)
  
    SUPPORTED_SOUND_FORMAT = {".mp3",".ogg", ".it"}

    for k, extension in ipairs(SUPPORTED_SOUND_FORMAT) do
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

-- This function asserts that all required generic sound effects exists
function assert_requirements_met()

    local SFX_REQUIREMENTS =  {"cur_move", "swap", "fanfare1", "fanfare2", "fanfare3", "game_over"}
    local NUMBER_REQUIRED_GARBAGE_THUDS = 3

    for k,SFX_sounds in ipairs(SFX_REQUIREMENTS) do
      assert(sounds.SFX[SFX_sounds], "SFX \""..SFX_sounds.."\"was not loaded")
    end
    for i=1, NUMBER_REQUIRED_GARBAGE_THUDS do
      assert(sounds.SFX.garbage_thud[i], "SFX garbage_thud "..i.."was not loaded")
    end
    -- assert we have the required SFX and music for each character
    for character,name in ipairs(characters) do
      for characterSFX, sound in ipairs(required_characters_SFX) do
        assert(sounds.SFX.characters[name][sound], "Character SFX"..sound.." for "..name.." was not loaded.")
      end
      for character_theme, musicType in ipairs(required_character_music) do
        assert(sounds.music.characters[name][musicType], musicType.." for "..name.." was not loaded.")
      end
    end
    -- assert pops have been loaded
    for popLevel=1,4 do
        for popIndex=1,10 do
            assert(sounds.SFX.pops[popLevel][popIndex], "SFX pop"..popLevel.."-"..popIndex.." was not loaded")
        end
    end
  end

-- This function stops all sounds related to characters
function stop_character_sounds(character)
    -- global variables
    danger_music_intro_started = nil
    danger_music_intro_finished = nil
    danger_music_intro_playing = nil
    normal_music_intro_exists = nil
    normal_music_intro_started = nil
    normal_music_intro_finished = nil
  
    for characterSFX, sound in ipairs(allowed_SFX_character) do
        -- Conditional that get a sound effect and then stop it
        if sounds.SFX.characters[character][sound] then
            sounds.SFX.characters[character][sound]:stop()
        end
    end
    for characterMusic, musicType in ipairs(allowed_character_music) do
        -- Conditional that get a character theme and then stop it
        if sounds.music.characters[character][musicType] then
            sounds.music.characters[character][musicType]:stop()
        end
    end
end

-- This function initializes the sounds and sets variables with sound effects used all over other functions in this file
function sound_init()
    default_sounds_dir = "Stock PdP_TA"
    sounds_dir = config.sounds_dir or default_sounds_dir
    -- sounds: SFX, music
    -- globlal variables
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
    required_characters_SFX = {"chain", "combo"}
    -- @CardsOfTheHeart says there are 4 chain sfx: --x2/x3, --x4, --x5 is x2/x3 with an echo effect, --x6+ is x4 with an echo effect
    allowed_SFX_character = {"chain", "combo", "combo_echo", "chain_echo", "chain2" ,"chain2_echo", "garbage_match"}
    required_character_music = {"normal_music", "danger_music"}
    allowed_character_music = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}
  
    for character,name in ipairs(characters) do
      sounds.SFX.characters[name] = {}
      for characterSFX, sound in ipairs(allowed_SFX_character) do
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
      for characterMusic, music_type in ipairs(allowed_character_music) do
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
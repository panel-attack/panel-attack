-- sets the volume of a single source or table of sources
supportedSoundsFormats = {".mp3",".ogg", ".it"}

function set_volume(source, newVolume)
  if config.debug_mode then print("set_volume called") end
  if type(source) == "table" then
    for _,volume in pairs(source) do
      set_volume(volume, newVolume)
    end
  else
    source:setVolume(newVolume)
  end
end

-- returns a new sound effect if it can be found, else returns nil
function find_sound(soundName, directoriesToCheck)
  local foundSource
  for searchSFX,directory in ipairs(directoriesToCheck) do
    foundSource = check_supported_extensions(directory..soundName)
    if foundSource then
      return foundSource
    end
  end
  return nil
end

function find_generic_SFX(SFXSoundName)
  local DIRECTORIES_TO_CHECK = {"sounds/"..sounds_dir.."/SFX/",
                                "sounds/"..default_sounds_dir.."/SFX/"}
  return find_sound(SFXSoundName, DIRECTORIES_TO_CHECK)
end

function find_character_SFX(character, SFXSoundName)
  local DIRECTORIES_TO_CHECK = {"sounds/"..sounds_dir.."/characters/",
                              "sounds/"..default_sounds_dir.."/characters/"}
  
  
  local cur_dir_contains_chain
  
  for k,currentDirectory in ipairs(DIRECTORIES_TO_CHECK) do
    -- note: if there is a chain or a combo, but not the other, return the same SFX for either inquiry.
    -- this way, we can always depend on a character having a combo and a chain SFX.
    -- if they are missing others, that's fine.
    -- (ie. some characters won't have "match_garbage" or a fancier "chain-x6")
    local currentDirectoryHasChainSound = check_supported_extensions(currentDirectory.."/"..character.."/chain")
    if SFXSounName == "chain" and currentDirectoryHasChainSound then 
      if config.debug_mode then print("loaded "..SFXSoundName.." for "..character) end
      return currentDirectoryHasChainSound
    end
    local currentDirectoryComboSound = check_supported_extensions(currentDirectory.."/"..character.."/combo")
    if SFXSoundName == "combo" and currentDirectoryComboSound then 
      if config.debug_mode then print("loaded "..SFXSoundName.." for "..character) end
      return currentDirectoryComboSound
    elseif SFXSoundName == "combo" and currentDirectoryHasChainSound then
      if config.debug_mode then print("substituted found chain SFX for "..SFXSoundName.." for "..character) end
      return currentDirectoryHasChainSound -- in place of the combo SFX
    end
    if SFXSoundName == "chain" and currentDirectoryComboSound then
      if config.debug_mode then print("substituted found combo SFX for "..SFXSoundName.." for "..character) end
      return currentDirectoryComboSound
    end
    
    local otherRequestedSFX = check_supported_extensions(currentDirectory.."/"..character.."/"..SFXSoundName)
    if otherRequestedSFX then
      if config.debug_mode then print("loaded "..SFXSoundName.." for "..character) end
      return otherRequestedSFX
    else
      if config.debug_mode then print("did not find "..SFXSoundName.." for "..character.." in current directory: "..current_dir) end
    end
    if currentDirectoryHasChainSound or currentDirectoryComboSound --[[and we didn't find the requested SFX in this dir]] then
      if config.debug_mode then print("chain or combo was provided, but "..SFXSoundName.." was not.") end
      return nil -- don't continue looking in other fallback directories,
  -- else
    -- keep looking
    end
  end
  -- if not found in above directories:
  return nil
end

-- returns audio source based on character and music_type (normal_music, danger_music, normal_music_start, or danger_music_start)
function find_music(character, musicType)
  local foundSource
  local characterThemeOverridesStageTheme = check_supported_extensions("sounds/"..sounds_dir.."/characters/"..character.."/normal_music")
  if characterThemeOverridesStageTheme then
    foundSource = check_supported_extensions("sounds/"..sounds_dir.."/characters/"..character.."/"..musicType)
    if foundSource then
      if config.debug_mode then print("In selected sound directory, found "..musicType.." for "..character) end
    else
      if config.debug_mode then print("In selected sound directory, did not find "..musicType.." for "..character) end
    end
    return foundSource
  else
    if stages[character] then
      soundSetOverridesDefaultSoundSet = check_supported_extensions("sounds/"..sounds_dir.."/music/"..stages[character].."/normal_music")
      if soundSetOverridesDefaultSoundSet then
        foundSource = check_supported_extensions("sounds/"..sounds_dir.."/music/"..stages[character].."/"..musicType)
        if foundSource then
          if config.debug_mode then print("In selected sound directory stages, found "..musicType.." for "..character) end
          
        else
          if config.debug_mode then print("In selected sound directory stages, did not find "..musicType.." for "..character) end
        end
        return foundSource
      else
        foundSource = check_supported_extensions("sounds/"..default_sounds_dir.."/music/"..stages[character].."/"..musicType)
        if foundSource then
          if config.debug_mode then print("In default sound directory stages, found "..musicType.." for "..character) end
        else
          if config.debug_mode then print("In default sound directory stages, did not find "..musicType.." for "..character) end
        end
        return foundSource
      end
    end
    return foundSource
  end
  return nil
end

-- returns a source, or nil if it could not find a file
function check_supported_extensions(pathAndFilename)
  for k, extension in ipairs(supportedSoundsFormats) do
    if love.filesystem.isFile(pathAndFilename..extension) then
      if string.find(pathAndFilename, "music") then
        return love.audio.newSource(pathAndFilename..extension)
      else
        return love.audio.newSource(pathAndFilename..extension, "static")
      end
    end
  end
  return nil
end

function assert_requirements_met()
  -- assert we have all required generic sound effects
  local SFX_REQUIREMENTS =  {"cur_move", "swap", "fanfare1", "fanfare2", "fanfare3", "game_over"}
  for k,SFXSounds in ipairs(SFX_REQUIREMENTS) do
    assert(sounds.SFX[SFXSounds], "SFX \""..SFXSounds.."\"was not loaded")
  end
  local NUM_REQUIRED_GARBAGE_THUDS = 3
  for i=1, NUM_REQUIRED_GARBAGE_THUDS do
    assert(sounds.SFX.garbage_thud[i], "SFX garbage_thud "..i.."was not loaded")
  end
    -- assert we have the required SFX and music for each character
  for character,name in ipairs(characters) do
    for characterSFX, sound in ipairs(requiredCharacterSFX) do
      assert(sounds.SFX.characters[name][sound], "Character SFX"..sound.." for "..name.." was not loaded.")
    end
    for characterTheme, musicType in ipairs(requiredCharacterMusic) do
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

function stop_character_sounds(character)
  local danger_music_intro_started = nil
  local danger_music_intro_finished = nil
  local danger_music_intro_playing = nil
  local normal_music_intro_exists = nil
  local normal_music_intro_started = nil
  local normal_music_intro_finished = nil
  for k, sound in ipairs(allowedCharacterSFX) do
    if sounds.SFX.characters[character][sound] then
      sounds.SFX.characters[character][sound]:stop()
    end
  end
  for k, musicType in ipairs(allowedCharacterMusic) do
    if sounds.music.characters[character][musicType] then
      sounds.music.characters[character][musicType]:stop()
    end
  end
end

function sound_init()
  default_sounds_dir = "Stock PdP_TA"
  sounds_dir = config.sounds_dir or default_sounds_dir

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
  requiredCharacterSFX = {"chain", "combo"}
  -- @CardsOfTheHeart says there are 4 chain sfx: --x2/x3, --x4, --x5 is x2/x3 with an echo effect, --x6+ is x4 with an echo effect
  allowedCharacterSFX = {"chain", "combo", "combo_echo", "chain_echo", "chain2" ,"chain2_echo", "garbage_match"}
  requiredCharacterMusic = {"normal_music", "danger_music"}
  allowedCharacterMusic = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}
  for i,name in ipairs(characters) do
    sounds.SFX.characters[name] = {}
    for k, sound in ipairs(allowedCharacterSFX) do
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
    for k, music_type in ipairs(allowedCharacterMusic) do
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
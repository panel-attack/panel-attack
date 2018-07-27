--sets the volume of a single source or table of sources
supported_sound_formats = {".ogg",".mp3", ".it"}
function set_volume(source, new_volume)
  print("set_volume called")
  if type(source) == "table" then
    for _,v in pairs(source) do
      set_volume(v, new_volume)
    end
  else
    source:setVolume(new_volume)
  end
end

function load_char_SFX(path_and_filename)
  local lfs = love.filesystem
  for k, char_name in (characters) do
    if lfs.isFile("sounds/"..sounds_dir.."/"..sounds_dir.."/characters/"..char_name.."/"..path_and_filename) then
    --TODO this whole function
    end
  end
  if lfs.isFile("sounds/"..sounds_dir.."/") then
  elseif lfs.isFile("sounds/"..sounds_dir.."/"..sounds_dir) then
  elseif lfs.isFile("sounds/"..sounds_dir.."/"..default_sounds_dir) then
  end
end

-- returns a new sound effect if it can be found, else returns nil
function find_sound(sound_name, dirs_to_check)
  local found_file
  for k,dir in ipairs(dirs_to_check) do
    found_file = check_supported_extensions(dir..sound_name)
    if found_file then
      return love.audio.newSource(found_file, static)
    end
  end
  return nil
end

function find_generic_SFX(SFX_name)
  local dirs_to_check = {"sounds/"..sounds_dir.."/SFX/",
                         "sounds/"..default_sounds_dir.."/SFX/"}
  return find_sound(SFX_name, dirs_to_check)
end

--returns audio source based on character and music_type (normal, danger, normal_start, or danger_start)
function find_music(character, music_type)
  local found_file
  local character_music_overrides_stage_music = check_supported_extensions("sounds/"..sounds_dir.."characters/"..character.."/"..normal)
  if character_music_overrides_stage_music then
    found_file = check_supported_extensions("sounds"..sounds_dir.."/characters/"..character.."/"..music_type)
    return found_file
  elseif stages[character] then
    found_file = check_supported_extensions("sounds"..sounds_dir.."/music/"..stages[character]..music_type)
    return found_file
  else
    --nothing, I think...  --TODO: check this
  end
end

function find_character_SFX(SFX_name)
  local dirs_to_check
  -- TODO: this whole function
end

function SFX_init()

end

--returns the full path, name, and extension of the first found file, or nil if it could not find a file
function check_supported_extensions(path_and_filename)
  local ret
  for k, extension in ipairs(supported_sound_formats) do
    if love.filesystem.isFile(path_and_filename..extension) then
      return path_and_filename..extension
    end
  end
  return nil
end

function sound_init()
  default_sounds_dir = "Stock PdP_TA"
  sounds_dir = "Stock PdP_TA" -- TODO: pull this from config
  --sounds: SFX, music
  SFX_Fanfare_Play = 0
  SFX_GameOver_Play = 0
  SFX_GarbageThud_Play = 0
  sounds = {
    SFX = {
      cur_move = find_generic_SFX("06move.ogg", "static"),
      swap = love.audio.newSource("sounds/"..sounds_dir.."/SFX/08swap.ogg", "static"),
      land = love.audio.newSource("sounds/"..sounds_dir.."/SFX/12cLand.ogg", "static"),
      fanfare1 = love.audio.newSource("sounds/"..sounds_dir.."/SFX/F6Fanfare1.ogg", "static"),
      fanfare2 = love.audio.newSource("sounds/"..sounds_dir.."/SFX/F7Fanfare2.ogg", "static"),
      fanfare3 = love.audio.newSource("sounds/"..sounds_dir.."/SFX/F8Fanfare3.ogg", "static"),
      game_over = love.audio.newSource("sounds/"..sounds_dir.."/SFX/0DGameOver.ogg", "static"),
      garbage_thud = {
        love.audio.newSource("sounds/"..sounds_dir.."/SFX/Thud_1.ogg"),
        love.audio.newSource("sounds/"..sounds_dir.."/SFX/Thud_2.ogg"),
        love.audio.newSource("sounds/"..sounds_dir.."/SFX/Thud_3.ogg")
      },
      character = {},
      pops = {}
    },
    music = {
      character_normal = {},
      character_danger = {}
    }
  }
  for i,name in ipairs(characters) do
      sounds.SFX.character[name] = love.audio.newSource("sounds/"..sounds_dir.."/characters/"..name.."/chain.ogg", "static")
  end
  for i,name in ipairs(characters) do
      sounds.music.character_normal[name] = love.audio.newSource("sounds/"..sounds_dir.."/Music/"..stages[name].."_normal.it")
  end
  for i,name in ipairs(characters) do
      sounds.music.character_danger[name] = love.audio.newSource("sounds/"..sounds_dir.."/Music/"..stages[name].."_danger.it")
  end
  for popLevel=1,4 do
      sounds.SFX.pops[popLevel] = {}
      for popIndex=1,10 do
          sounds.SFX.pops[popLevel][popIndex] = love.audio.newSource("sounds/"..sounds_dir.."/SFX/pop"..popLevel.."-"..popIndex..".ogg", "static")
      end
  end
  love.audio.setVolume(config.master_volume/100)
  set_volume(sounds.SFX, config.SFX_volume/100)
  set_volume(sounds.music, config.music_volume/100) 
end
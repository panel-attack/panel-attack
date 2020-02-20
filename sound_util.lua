local supported_sound_formats = { ".mp3", ".ogg", ".wav", ".it", ".flac" }

--sets the volume of a single source or table of sources
function set_volume(source, new_volume)
  if type(source) == "table" then
    for _,v in pairs(source) do
      set_volume(v, new_volume)
    end
  elseif type(source) ~= "number" then
    source:setVolume(new_volume)
  end
end

-- returns a new sound effect if it can be found, else returns nil
function find_sound(sound_name, dirs_to_check, streamed)
  streamed = streamed or false
  local found_source
  for k,dir in ipairs(dirs_to_check) do
    found_source = load_sound_from_supported_extensions(dir..sound_name,streamed)
    if found_source then
      return found_source
    end
  end
  return nil
end

--returns a source, or nil if it could not find a file
function load_sound_from_supported_extensions(path_and_filename,streamed)
  for k, extension in ipairs(supported_sound_formats) do
    if love.filesystem.getInfo(path_and_filename..extension) then
      return love.audio.newSource(path_and_filename..extension, streamed and "stream" or "static")
    end
  end
  return nil
end
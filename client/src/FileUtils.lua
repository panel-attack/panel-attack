local logger = require("common.lib.logger")

local PREFIX_OF_IGNORED_DIRECTORIES = "__"

--@module FileUtils
-- Collection of functions for file operations
local fileUtils = {}

-- returns the directory items with a default filter and an optional filetype filter
-- by default, filters out everything starting with __ and Mac's .DS_Store file
-- optionally the result can be filtered to return only "file" or "directory" items
function fileUtils.getFilteredDirectoryItems(path, fileType)
  local results = {}

  local directoryList = love.filesystem.getDirectoryItems(path)
  for _, file in ipairs(directoryList) do

    local startOfFile = string.sub(file, 0, string.len(PREFIX_OF_IGNORED_DIRECTORIES))
   -- macOS sometimes puts these files in folders without warning, they are never useful for PA, so filter them.
    if startOfFile ~= PREFIX_OF_IGNORED_DIRECTORIES and file ~= ".DS_Store" then
      if not fileType or love.filesystem.getInfo(path .. "/" .. file, fileType) then
        results[#results+1] = file
      end
    end
  end

  return results
end

function fileUtils.getFileNameWithoutExtension(filename)
  return filename:gsub("%..*", "")
end

-- copies a file from the given source to the given destination
function fileUtils.copyFile(source, destination)
  local success
  local source_file, err = love.filesystem.read(source)
  success, err = love.filesystem.write(destination, source_file)
  return success, err
end

-- copies a file from the given source to the given destination
function fileUtils.recursiveCopy(source, destination, yields)
  local lfs = love.filesystem
  local names = lfs.getDirectoryItems(source)
  local temp
  for i, name in ipairs(names) do
    local info = lfs.getInfo(source .. "/" .. name)
    if info and info.type == "directory" then
      logger.trace("calling recursive_copy(source" .. "/" .. name .. ", " .. destination .. "/" .. name .. ")")
      fileUtils.recursiveCopy(source .. "/" .. name, destination .. "/" .. name, yields)
    elseif info and info.type == "file" then
      local destination_info = lfs.getInfo(destination)
      if not destination_info or destination_info.type ~= "directory" then
        love.filesystem.createDirectory(destination)
      end
      logger.trace("copying file:  " .. source .. "/" .. name .. " to " .. destination .. "/" .. name)

      local success, message = fileUtils.copyFile(source .. "/" .. name, destination .. "/" .. name)

      if not success then
        logger.warn(message)
      end
    else
      logger.warn("name:  " .. name .. " isn't a directory or file?")
    end
  end

  if yields then
    coroutine.yield("Copied\n" .. source .. "\nto\n" .. destination)
  end
end

-- Deletes any file matching the target name from the file tree recursively
function fileUtils.recursiveRemoveFiles(folder, targetName)
  local lfs = love.filesystem
  local filesTable = lfs.getDirectoryItems(folder)
  for _, fileName in ipairs(filesTable) do
    local file = folder .. "/" .. fileName
    local info = lfs.getInfo(file)
    if info then
      if info.type == "directory" then
        fileUtils.recursiveRemoveFiles(file, targetName)
      elseif info.type == "file" and fileName == targetName then
        love.filesystem.remove(file)
      end
    end
  end
end

function fileUtils.readJsonFile(file)
  if not love.filesystem.getInfo(file, "file") then
    logger.debug("No file at specified path " .. file)
    return nil
  else
    local fileContent, info = love.filesystem.read(file)
    if type(info) == "string" then
      -- info is the number of read bytes if successful, otherwise an error string
      -- thus, if it is of type string, that indicates an error
      logger.warn("Could not read file at path " .. file)
      return nil
    else
      local value, _, errorMsg = json.decode(fileContent)
      if errorMsg then
        logger.error("Error reading " .. file .. ":\n" .. errorMsg .. ":\n" .. fileContent)
        return nil
      else
        return value
      end
    end
  end
end

local SUPPORTED_SOUND_FORMATS = {".mp3", ".ogg", ".wav", ".it", ".flac"}
--returns a source, or nil if it could not find a file
function fileUtils.loadSoundFromSupportExtensions(path_and_filename, streamed)
  for k, extension in ipairs(SUPPORTED_SOUND_FORMATS) do
    if love.filesystem.getInfo(path_and_filename .. extension) then
      return love.audio.newSource(path_and_filename .. extension, streamed and "stream" or "static")
    end
  end
  return nil
end

-- returns a new sound effect if it can be found, else returns nil
function fileUtils.findSound(sound_name, dirs_to_check, streamed)
  streamed = streamed or false
  local found_source
  for k, dir in ipairs(dirs_to_check) do
    found_source = fileUtils.loadSoundFromSupportExtensions(dir .. sound_name, streamed)
    if found_source then
      return found_source
    end
  end
  return nil
end

function fileUtils.soundFileExists(soundName, path)
  for _, extension in pairs(SUPPORTED_SOUND_FORMATS) do
    if love.filesystem.exists(path .. "/" .. soundName .. extension) then
      return true
    end
  end

  return false
end

function fileUtils.saveTextureToFile(texture, filePath, format)
  local imageData = love.graphics.readbackTexture(texture)
  local data = imageData:encode(format)
  love.filesystem.write(filePath .. "." .. format, data)
end

return fileUtils
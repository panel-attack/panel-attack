require("class")
require("table_util")
require("FileUtil")
local logger = require("logger")

local lfs = love.filesystem

local ModImport = {}

function ModImport.importCharacter(path)
  local configPath = path .. "/config.json"
  if not lfs.getInfo(configPath, "file") then
    return false
  else
    local configData, err = lfs.read(configPath)
    if not configData then
      error("Error trying to import character " .. path .. "\nCouldn't read config.json\n" .. err)
    else
      local config = json.decode(configData)
      if table.contains(characters_ids, config["id"]) then
        local now = os.date("*t", to_UTC(os.time()))
        local existingPath = characters[config["id"]].path
        local backUpPath = existingPath .. "/__backup_" ..
                               string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
        lfs.createDirectory(backUpPath)
        local importFiles = ModImport.recursiveRead(path)
        local currentFiles = ModImport.recursiveRead(existingPath)
        ModImport.recursiveCompareBackupAndCopy(importFiles, backUpPath, currentFiles)
      else
        recursive_copy(path, "characters/" .. config["name"])
      end

      return true
    end
  end
end

-- This function will recursively populate the passed in empty table fileTree with the directory and fileData
function ModImport.recursiveRead(folder, fileTree)
  local function getFileContent(filePath)
    local fileContent, size = lfs.read(filePath)
    return {size = size, content = fileContent}
  end

  local function getName(folderString)
    local len = string.len(folderString)
    local reversed = string.reverse(folderString)
    local index, stop, _ = string.find(reversed, "/")
    if index then
      return string.sub(folderString, len - index + 1, len)
    else
      return folderString
    end
  end

	if not fileTree then
		fileTree = {}
	end

  local filesTable = lfs.getDirectoryItems(folder)
  local folderName = getName(folder)
  fileTree[folderName] = {type = "directory", files = {}, path = folder}
  logger.debug("Reading folder " .. folder .. " into memory")
  for _, v in ipairs(filesTable) do
    local file = folder .. "/" .. v
    local info = lfs.getInfo(file)
    if info then
      if info.type == "file" then
        logger.debug("Reading file " .. file .. " into memory")
        fileTree[folderName].files[v] = {type = "file", content = getFileContent(file), path = file}
      elseif info.type == "directory" then
        ModImport.recursiveRead(file, fileTree[folderName].files)
      end
    end
  end
  return fileTree
end

function ModImport.recursiveCompareBackupAndCopy(importFiles, backUpPath, currentFiles)
  -- droppedFiles and currentFiles are always directories in the filetree structure
  -- assert(droppedFiles.type == "directory")

  for key, value in pairs(importFiles) do
    if value.type == currentFiles[key].type and value.path == currentFiles[key].path then
      if value.type == "file" then
        if not currentFiles[key] then
          -- the file doesn't exist, we can just copy over
          copy_file(importFiles[key].path, currentFiles.path .. "/" .. key)
        elseif value.content.size == currentFiles[key].content.size and value.content.content == currentFiles[key].content.content then
          -- files are identical, no need to do anything
        else
          -- files are not identical, copy the old one to backup before copying the new one over
          copy_file(currentFiles[key].path, backUpPath .. "/" .. key)
          copy_file(importFiles[key].path, currentFiles[key].path)
        end
      else
        if currentFiles[key] then
          local nextBackUpPath = backUpPath .. "/" .. key
          -- create the path in the backup folder so writes to backup don't fail in the recursive call
          lfs.createDirectory(nextBackUpPath)
          return ModImport.recursiveCompareBackupAndCopy(value.files, nextBackUpPath, currentFiles[key].files)
        else
          -- the subfolder doesn't exist, we can just copy over
          recursive_copy(importFiles[key].path, currentFiles.path .. "/" .. key)
        end
      end
    end
  end
end

return ModImport

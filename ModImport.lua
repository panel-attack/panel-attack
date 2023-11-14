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
      local modConfig = json.decode(configData)
      if table.contains(characters_ids, modConfig["id"]) then
        local existingPath = characters[modConfig["id"]].path
        local backUpPath = ModImport.createBackupDirectory(existingPath)
        -- next is just a slightly scuffed way to access the only top level element in the table
        -- we need to pass without the head as otherwise different folder names can screw the import up
        local _, importFiles = next(ModImport.recursiveRead(path))
        local _, currentFiles = next(ModImport.recursiveRead(existingPath))
        ModImport.recursiveCompareBackupAndCopy(importFiles.files, backUpPath, currentFiles.files)
      else
        if not lfs.getInfo("characters/" .. modConfig["name"]) then
          recursive_copy(path, "characters/" .. modConfig["name"])
        else
          recursive_copy(path, "characters/" .. modConfig["id"])
        end
      end

      return true
    end
  end
end

function ModImport.importStage(path)
  local configPath = path .. "/config.json"
  if not lfs.getInfo(configPath, "file") then
    return false
  else
    local configData, err = lfs.read(configPath)
    if not configData then
      error("Error trying to import stage " .. path .. "\nCouldn't read config.json\n" .. err)
    else
      local modConfig = json.decode(configData)
      if table.contains(stages_ids, modConfig["id"]) then
        local existingPath = stages[modConfig["id"]].path
        local backUpPath = ModImport.createBackupDirectory(existingPath)
        -- next is just a slightly scuffed way to access the only top level element in the table
        -- we need to pass without the head as otherwise different folder names can screw the import up
        local _, importFiles = next(ModImport.recursiveRead(path))
        local _, currentFiles = next(ModImport.recursiveRead(existingPath))
        ModImport.recursiveCompareBackupAndCopy(importFiles.files, backUpPath, currentFiles.files)
      else
        if not lfs.getInfo("stages/" .. modConfig["name"]) then
          recursive_copy(path, "stages/" .. modConfig["name"])
        else
          recursive_copy(path, "stages/" .. modConfig["id"])
        end
      end

      return true
    end
  end
end

function ModImport.importPanelSet(path)
  local configPath = path .. "/config.json"
  if not lfs.getInfo(configPath, "file") then
    return false
  else
    local configData, err = lfs.read(configPath)
    if not configData then
      error("Error trying to import panels " .. path .. "\nCouldn't read config.json\n" .. err)
    else
      local modConfig = json.decode(configData)
      if table.contains(panels_ids, modConfig["id"]) then
        local existingPath = panels[modConfig["id"]].path
        local backUpPath = ModImport.createBackupDirectory(existingPath)
        -- next is just a slightly scuffed way to access the only top level element in the table
        -- we need to pass without the head as otherwise different folder names can screw the import up
        local _, importFiles = next(ModImport.recursiveRead(path))
        local _, currentFiles = next(ModImport.recursiveRead(existingPath))
        ModImport.recursiveCompareBackupAndCopy(importFiles.files, backUpPath, currentFiles.files)
      else
        if not lfs.getInfo("panels/" .. FileUtil.getDirectoryName(path)) then
          recursive_copy(path, "panels/" .. FileUtil.getDirectoryName(path))
        else
          recursive_copy(path, "panels/" .. modConfig["id"])
        end
      end

      return true
    end
  end
end

function ModImport.importTheme(path)
  local configPath = path .. "/config.json"
  if not lfs.getInfo(configPath, "file") then
    return false
  else
    local configData, err = lfs.read(configPath)
    if not configData then
      error("Error trying to import theme " .. path .. "\nCouldn't read config.json\n" .. err)
    else
      local themeName = FileUtil.getDirectoryName(path)
      if lfs.getInfo("themes/" .. themeName, "directory") then
        local existingPath = "themes/" .. themeName
        local backUpPath = ModImport.createBackupDirectory(existingPath)
        local importFiles = ModImport.recursiveRead(path)
        local currentFiles = ModImport.recursiveRead(existingPath)
        -- unlike the other mod types, themes are (unfortunately) still identified by foldername
        -- so we can keep the top level element in (if it wasn't the same, we'd have landed in the else branch)
        ModImport.recursiveCompareBackupAndCopy(importFiles, backUpPath, currentFiles)
      else
        recursive_copy(path, "themes/" .. themeName)
      end

      return true
    end
  end
end

function ModImport.importPuzzleFile(path)
  -- we really need a proper puzzle format that guarantees identification to some degree
  -- way too easy to overwrite otherwise compared to themes
end

function ModImport.createBackupDirectory(path)
  local now = os.date("*t", to_UTC(os.time()))
  local backUpPath = path .. "/__backup_" ..
                         string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
  lfs.createDirectory(backUpPath)
  return backUpPath
end

-- This function will recursively populate the passed in empty table fileTree with the directory and fileData
function ModImport.recursiveRead(folder, fileTree)
  if not fileTree then
    fileTree = {}
  end

  local filesTable = FileUtil.getFilteredDirectoryItems(folder)
  local folderName = FileUtil.getDirectoryName(folder)
  fileTree[folderName] = {type = "directory", files = {}, path = folder}
  logger.debug("Reading folder " .. folder .. " into memory")
  for _, v in ipairs(filesTable) do
    local filePath = folder .. "/" .. v
    local info = lfs.getInfo(filePath)
    if info then
      if info.type == "file" then
        logger.debug("Reading file " .. filePath .. " into memory")
        local fileContent, size = lfs.read(filePath)
        fileTree[folderName].files[v] = {type = "file", content = {size = size, content = fileContent}, path = filePath}
      elseif info.type == "directory" then
        ModImport.recursiveRead(filePath, fileTree[folderName].files)
      end
    end
  end
  return fileTree
end

function ModImport.recursiveCompareBackupAndCopy(importFiles, backUpPath, currentFiles)
  -- droppedFiles and currentFiles are always directories in the filetree structure
  -- assert(droppedFiles.type == "directory")

  for key, value in pairs(importFiles) do
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

return ModImport

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
        local existingPath = characters[config["id"]].path
        local backUpPath = ModImport.createBackupDirectory(existingPath)
        local importFiles = ModImport.recursiveRead(path)
        local currentFiles = ModImport.recursiveRead(existingPath)
        ModImport.recursiveCompareBackupAndCopy(importFiles, backUpPath, currentFiles)
      else
        if not lfs.getInfo("characters/" .. config["name"]) then
					recursive_copy(path, "characters/" .. config["name"])
				else
					recursive_copy(path, "characters/" .. config["id"])
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
      local config = json.decode(configData)
      if table.contains(stages_ids, config["id"]) then
        local existingPath = stages[config["id"]].path
        local backUpPath = ModImport.createBackupDirectory(existingPath)
        local importFiles = ModImport.recursiveRead(path)
        local currentFiles = ModImport.recursiveRead(existingPath)
        ModImport.recursiveCompareBackupAndCopy(importFiles, backUpPath, currentFiles)
      else
				if not lfs.getInfo("stages/" .. config["name"]) then
					recursive_copy(path, "stages/" .. config["name"])
				else
					recursive_copy(path, "stages/" .. config["id"])
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
      local config = json.decode(configData)
      if table.contains(panels_ids, config["id"]) then
        local existingPath = panels[config["id"]].path
        local backUpPath = ModImport.createBackupDirectory(existingPath)
        local importFiles = ModImport.recursiveRead(path)
        local currentFiles = ModImport.recursiveRead(existingPath)
        ModImport.recursiveCompareBackupAndCopy(importFiles, backUpPath, currentFiles)
      else
				if not lfs.getInfo("panels/" .. FileUtil.getDirectoryName(path)) then
					recursive_copy(path, "panels/" .. FileUtil.getDirectoryName(path))
				else
					recursive_copy(path, "panels/" .. config["id"])
				end
      end

      return true
    end
  end
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
  local function getFileContent(filePath)
    local fileContent, size = lfs.read(filePath)
    return {size = size, content = fileContent}
  end

	if not fileTree then
		fileTree = {}
	end

  local filesTable = lfs.getDirectoryItems(folder)
  local folderName = FileUtil.getDirectoryName(folder)
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

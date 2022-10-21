
-- Deletes any file from the file tree recursively
function AndroidMigration.recursiveRemoveFiles(self, folder)
  local lfs = love.filesystem
  local filesTable = lfs.getDirectoryItems(folder)
  for _, fileName in ipairs(filesTable) do
    local file = folder .. "/" .. fileName
    local info = lfs.getInfo(file)
    if info then
      if info.type == "directory" then
        self:recursiveRemoveFiles(file)
      elseif info.type == "file" then
        self:logEvent("Removing file " .. file .. " from " .. DATA_LOCATION .. " storage")
        love.filesystem.remove(file)
        coroutine.yield()
      end
    end
  end
  -- directories can only get removed after they were emptied
  self:logEvent("Removing folder " .. folder .. " from " .. DATA_LOCATION .. " storage")
  love.filesystem.remove(folder)
  coroutine.yield()
end

--[[ 
filetree structure:

filetree["characters"] = { type = "directory", files = {}}
filetree["characters"].files["beatrice"] = { type = "directory", files = {}}
filetree["characters"].files["beatrice"].files["cackle.ogg"] = readFile()
etc.
]]

-- This function will recursively populate the passed in empty table fileTree with the directory and fileData
function AndroidMigration.recursiveRead(self, folder, fileTree)
  local function getFileContent(source)
    local source_file = love.filesystem.newFile(source)
    source_file:open("r")
    local source_size = source_file:getSize()
    local content = source_file:read(source_size)
    source_file:close()
  
    return {size = source_size, content = content}
  end

  local function getName(folderString)
    local len = string.len(folderString)
    local reversed = string.reverse(folderString)
    local index, stop, _  = string.find(reversed, "/")
    if index then
      return string.sub(folderString, len - index + 1, len)
    else
      return folderString
    end
  end

	local filesTable = love.filesystem.getDirectoryItems(folder)
  local folderName = getName(folder)
  fileTree[folderName] = { type = "directory", files = {}, path = folder}
  self:logEvent("Reading folder " .. folder .. " into memory")
  for _,v in ipairs(filesTable) do
    local file = folder.."/"..v
    local info = love.filesystem.getInfo(file)
    if info then
      if info.type == "file" then
        -- don't copy files from the app, reading from root directory reads from BOTH internal storage as well as the main game files
        -- but we only want to copy files in the save directory
        if love.filesystem.getRealDirectory(file) == self.saveDirectory then
          self:logEvent("Reading file " .. file .. " into memory")
          fileTree[folderName].files[v] = { type = "file", content = getFileContent(file), path = file }
          coroutine.yield()
        end
      elseif info.type == "directory" then
        self:recursiveRead(file, fileTree[folderName].files)
      end
    end
  end
	return fileTree
end

function AndroidMigration.recursiveWrite(self, fileTree)
  for i, properties in pairs(fileTree) do
    if properties.type == "directory" then
      self:logEvent("Creating folder " .. properties.path .. " in " .. DATA_LOCATION .. " storage")
      if not love.filesystem.getInfo(properties.path, "directory") then
        love.filesystem.createDirectory(properties.path)
      else
        self:logEvent("Folder " .. properties.path .. " already exists in " .. DATA_LOCATION .. " storage")
      end
      coroutine.yield()
      self:recursiveWrite(properties.files)
    elseif properties.type == "file" then
      self:logEvent("Writing file " .. properties.path .. " to " .. DATA_LOCATION .. " storage")
      if love.filesystem.getInfo(properties.path, "file") then
        love.filesystem.remove(properties.path)
      end
      local new_file = love.filesystem.newFile(properties.path)
      new_file:open("w")
      local success, message = new_file:write(properties.content.content, properties.content.size)
      new_file:close()
      coroutine.yield()

      if success == false then
        self:logEvent("failure to write file " .. properties.path .. "\n" .. message)
        self:writeLog()
        error("failure to write file " .. properties.path .. "\n" .. message)
      end
    end
  end
end

-- returns true if fileTree2 contains all keys and values also present in filetree1
function AndroidMigration:recursiveCompare(fileTree1, fileTree2)
  for key, value in pairs(fileTree1) do
    if value.type == fileTree2[key].type and
       value.path == fileTree2[key].path then
      if value.type == "file" then
        return  value.content.size == fileTree2[key].content.size and
                value.content.content == fileTree2[key].content.content
      else
        return self:recursiveCompare(value.files, fileTree2[key].files)
      end
    end
  end

  return true
end
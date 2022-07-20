require("util")

local DragAndDrop = {
  existingAssets = {},
  imported = {},
  invalid = {},
  unknown = {},
  validDirNames = { "characters", "panels", "puzzles", "stages", "themes" }
}




function DragAndDrop.importMods(self, assetType)
  local files = DragAndDrop.getSubDirs(DragAndDrop.modDir .. "/" ..assetType)
  local paFiles = DragAndDrop.getSubDirs(assetType)
  for j = 1, #files do
    local dir = assetType.."/"..files[j]
    local file = DragAndDrop.modDir .. "/"..dir
    if self:validateMod(assetType, file) then
      -- does the mod already exist?
      if not table.contains(paFiles, file) then
        -- no, let's go
        recursive_copy(file, dir)
        self.imported[#self.imported+1] = dir
      else
        -- save mod name to prompt user for decision later
        self.existingAssets[#self.existingAssets+1] = { source = file, assetType = assetType, destination = dir }
      end
    else
      self.invalid[#self.invalid+1] = file
    end
  end
end

function DragAndDrop.validateMod(self, type, dirName)
  return true
end

function DragAndDrop.promptOverwrite(self, assetName)
  return false
end

function love.filedropped(file)
  DragAndDrop:acceptFile(file:getFilename())
end

function love.directorydropped(path)
  DragAndDrop:acceptFile(path)
end

function DragAndDrop.acceptFile(self, path)
  if CLICK_MENUS[#CLICK_MENUS] and #CLICK_MENUS[#CLICK_MENUS].buttons > 0 and
  CLICK_MENUS[#CLICK_MENUS].buttons[#CLICK_MENUS[#CLICK_MENUS].buttons].stringText == loc("mm_quit") then
    DragAndDrop.modDir = DragAndDrop.mountModDirectory(path)
    if DragAndDrop.modDir then
      local droppedFiles = table.getIntersection(DragAndDrop.validDirNames, DragAndDrop.getSubDirs(DragAndDrop.modDir))
  
      for i = 1, #droppedFiles do
        local assetType = droppedFiles[i]
        self:importMods(assetType)
      end
  
      for i = 1, #self.existingAssets do
        -- prompt
        if self:promptOverwrite(self.existingAssets[i]) then
          recursive_copy(self.existingAssets[i].source, self.existingAssets[i].destination)
        end
      end
  
      -- report about unknown files and invalid mods
      love.filesystem.unmount(DragAndDrop.modDir)
      end
    end
end

-- returns the name under which the mod directory was mounted
-- returns nil if no mods were found
function DragAndDrop.mountModDirectory(path)
  love.filesystem.mount(path, "droppedDir")
  local modDirectory = DragAndDrop.getModDirectory("droppedDir")
  if modDirectory then
    return modDirectory
  else
    love.filesystem.unmount(path)
  end
end

function DragAndDrop.getModDirectory(path)
  local modDirectory = nil
  if love.filesystem.getInfo(path, "directory") then
    local droppedDirs = DragAndDrop.getSubDirs(path)
    if #table.getIntersection(DragAndDrop.validDirNames, droppedDirs) > 0 then
      modDirectory = path
    else
      for i = 1, #droppedDirs do
        modDirectory = DragAndDrop.getModDirectory(path .. "/" .. droppedDirs[i])
        if modDirectory then
          break
        end
      end
    end
  end

  return modDirectory
end

function DragAndDrop.getSubDirs(path)
  local files = love.filesystem.getDirectoryItems(path)
  files = table.filter(files, function(file) 
    return love.filesystem.getInfo(path .. "/" .. file, "directory")
  end)
  return files
end
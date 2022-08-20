require("util")
require("table_util")

local DragAndDrop = {
  existingAssets = {},
  imported = {},
  invalid = {},
  unknown = {},
  validDirNames = { "characters", "panels", "puzzles", "stages", "themes" }
}

function DragAndDrop.importMods(self, assetType)
  local files = DragAndDrop.getSubDirs(DragAndDrop.modDir .. "/" ..assetType)
  for j = 1, #files do
    local dir = assetType.."/"..files[j]
    local mod = DragAndDrop:loadMod(dir, assetType)
    if self.modIsValid(mod) then
      if not self.modExists(mod) then
        recursive_copy(mod.fullDirectory, dir)
        self.imported[#self.imported+1] = mod
      else
        -- save mod name to prompt user for decision later
        self.existingAssets[#self.existingAssets+1] = mod
      end
    else
      self.invalid[#self.invalid+1] = mod.fullDirectory
    end
  end
end

function DragAndDrop.loadMod(self, directory, assetType)
  local mod = {}
  mod.directoryName = directory
  mod.fullDirectory = self.modDir .. "/" .. directory
  mod.targetDirectory = assetType .. "/" .. directory
  mod.assetType = assetType
  local config_file = love.filesystem.newFile(mod.fullDirectory .. "/config.json", "r")
  if config_file then
    mod.config = {}
    local configJson = config_file:read(config_file:getSize())
    for k, v in pairs(json.decode(configJson)) do
      mod.config[k] = v
    end

    mod.files = love.filesystem.getDirectoryItems(mod.fullDirectory)
  end

  return mod
end

function DragAndDrop.modIsValid(mod)
  if mod.assetType ~= "puzzles" then
    return mod.config ~= nil
  end
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
  if self.inMainMenu() then
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

      for _, mod in pairs(self.imported) do
        -- load the mod into the game
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

function DragAndDrop.inMainMenu()
  return CLICK_MENUS[#CLICK_MENUS] and #CLICK_MENUS[#CLICK_MENUS].buttons > 0 and
  CLICK_MENUS[#CLICK_MENUS].buttons[#CLICK_MENUS[#CLICK_MENUS].buttons].stringText == loc("mm_quit")
end

function DragAndDrop.modExists(mod)
  if mod.assetType == "characters" then
    return table.contains(characters_ids, mod.config.id)
  elseif mod.assetType == "panels" then
    return table.contains(panels_ids, mod.config.id)
  elseif mod.assetType == "puzzles" then
    -- change this once puzzles are organized better
    return false
  elseif mod.assetType == "stages" then
    return table.contains(stages_ids, mod.config.id)
  elseif mod.assetType == "themes" then
    return table.contains(DragAndDrop.getSubDirs("themes"), mod.directoryName)
  end
  return false
end
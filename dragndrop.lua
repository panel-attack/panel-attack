require("util")
require("table_util")

local lfs = love.filesystem

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
    local mod = DragAndDrop:loadMod(files[j], assetType)
    if self.modIsValid(mod) then
      if not self.modExists(mod) then
        recursive_copy(mod.fullDirectory, mod.targetDirectory)
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
  mod.fullDirectory = self.modDir .. "/" .. assetType.. "/" .. directory
  mod.targetDirectory = assetType .. "/" .. directory
  mod.assetType = assetType
  local config_file = lfs.newFile(mod.fullDirectory .. "/config.json", "r")
  if config_file then
    mod.config = {}
    local configJson = config_file:read(config_file:getSize())
    for k, v in pairs(json.decode(configJson)) do
      mod.config[k] = v
    end

    mod.files = lfs.getDirectoryItems(mod.fullDirectory)
  end

  return mod
end

function DragAndDrop.modIsValid(mod)
  if mod.assetType == "puzzles" then
    local puzzleFile = lfs.newFile(mod.fullDirectory, "r")
    if puzzleFile then
      local puzzleContent = puzzleFile:read(puzzleFile:getSize())
      return json.isValid(puzzleContent)
    else
      return false
    end
  elseif mod.assetType == "themes" then
    return mod.config ~= nil
  else
    return mod.config.id ~= nil
  end
end

local overwritePrompt = "The imported mod %s already exists, do you wish to overwrite the existing version?"
function DragAndDrop.promptOverwrite(assetName)
  -- TODO: We can't draw directly when coming from the love.filedropped or love.directorydropped callback
  -- reason being that we are not on the main thread (and in fact not even in a coroutine we could yield in)
  while true do
    GAME.backgroundImage:draw()
    gprint(string.format(overwritePrompt, assetName),15, 15, colors.white, 10)
    --gfx_q:push({love.graphics.draw, {string.format(overwritePrompt, assetName), 15, 15, nil, nil, nil, nil}})
    --gfx_q:push({love.graphics.draw, {"Press Escape for No, or Enter for Yes", 15, 45, nil, nil, nil, nil}})
    coroutine.yield()
    variable_step(
      function()
        if menu_escape() then
          return false
        elseif menu_enter() then
          return true
        end
      end
    )
  end
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
        if self.promptOverwrite(self.existingAssets[i]) then
          recursive_copy(self.existingAssets[i].source, self.existingAssets[i].destination)
          self.imported[#self.imported+1] = self.existingAssets[i]
        end
      end

      self:reloadModsBasedOnImport()

      -- TODO: report about unknown files and invalid mods
      lfs.unmount(DragAndDrop.modDir)
    end
  end
end

-- returns the name under which the mod directory was mounted
-- returns nil if no mods were found
function DragAndDrop.mountModDirectory(path)
  lfs.mount(path, "droppedDir")
  local modDirectory = DragAndDrop.getModDirectory("droppedDir")
  if modDirectory then
    return modDirectory
  else
    lfs.unmount(path)
  end
end

function DragAndDrop.getModDirectory(path)
  local modDirectory = nil
  if lfs.getInfo(path, "directory") then
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
  local files = lfs.getDirectoryItems(path)
  files = table.filter(files, function(file) 
    return lfs.getInfo(path .. "/" .. file, "directory")
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
    return table.contains(FileUtil.getFilteredDirectoryItems("themes"), mod.directoryName)
  end
  return false
end

function DragAndDrop.reloadModsBasedOnImport(self)
  if #self.imported > 0 then
    local mods = self.imported
    if table.trueForAny(mods, function(mod) return mod.assetType == "characters" end) then
      GAME:drawLoadingString(loc("ld_characters"))
      coroutine.yield()
      characters_init()
    end
  
    if table.trueForAny(mods, function(mod) return mod.assetType == "panels" end) then
      GAME:drawLoadingString(loc("ld_panels"))
      coroutine.yield()
      panels_init()
    end
  
    if table.trueForAny(mods, function(mod) return mod.assetType == "stages" end) then
      GAME:drawLoadingString(loc("ld_stages"))
      coroutine.yield()
      stages_init()
    end
  
    if table.trueForAny(mods, function(mod) return mod.assetType == "puzzles" end) then
      -- no loc string for loading puzzles and it's likely so fast that it's not worth it anyway
      read_puzzles()
    end
  
    -- themes get read inside of options.lua on the fly from disk based on directory name
    if table.filter(mods, function(mod) return mod.assetType == "themes" and mod.directoryName == config.theme end)  then
      -- that means a reinit is only necessary if the theme currently in use got updated
      GAME:drawLoadingString(loc("ld_theme"))
      coroutine.yield()
      theme_init()
    end
  end
end
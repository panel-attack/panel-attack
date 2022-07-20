require("util")

function love.directorydropped(path)
  if CLICK_MENUS[#CLICK_MENUS] and #CLICK_MENUS[#CLICK_MENUS].buttons > 0 and 
  CLICK_MENUS[#CLICK_MENUS].buttons[#CLICK_MENUS[#CLICK_MENUS].buttons].stringText == loc("mm_quit") then
    local getDirItems = love.filesystem.getDirectoryItems
    love.filesystem.mount(path, "droppedFolder")
    local pathSegments = love.system.getOS() == "Windows" and split(path, "\\") or split(path, "/")
    local dirName = pathSegments[#pathSegments]
    local droppedFiles = getDirItems("droppedFolder")
    local validFolderNames = { "characters", "panels", "puzzles", "stages", "themes" }
    local existingAssets = {}
    local imported = {}
    local invalid = {}
    local unknown = {}

    local function validateMod(type, folderName)
      return true
    end

    local function importMods(assetType)
      local files = getDirItems("droppedFolder/"..assetType)
      local paFiles = getDirItems(assetType)
      for j = 1, #files do
        local dir = assetType.."/"..files[j]
        local file = "droppedFolder/"..dir
        if validateMod(assetType, file) then
          -- does the mod already exist?
          if not table.contains(paFiles, file) then
            -- no, let's go
            recursive_copy(file, dir)
            imported[#imported+1] = dir
          else
            -- save mod name to prompt user for decision later
            existingAssets[#existingAssets+1] = { source = file, assetType = assetType, destination = dir }
          end
        else
          invalid[#invalid+1] = file
        end
      end
    end

    local function promptOverwrite(assetName)
      return false
    end

    for i = 1, #droppedFiles do
      local assetType = droppedFiles[i]
      if love.filesystem.getInfo(assetType, "directory")
          and table.contains(validFolderNames, assetType) then
        importMods(assetType)
      else
        unknown[#unknown+1] = dirName
      end
    end

    for i = 1, #existingAssets do
      -- prompt
      if promptOverwrite(existingAssets[i]) then
        recursive_copy(existingAssets[i].source, existingAssets[i].destination)
      end
    end

    -- report about unknown files and invalid mods
    love.filesystem.unmount("droppedFolder")
  end
end

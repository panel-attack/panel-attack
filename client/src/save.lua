local inputManager = require("common.lib.inputManager")
local fileUtils = require("client.src.FileUtils")
local logger = require("common.lib.logger")
local Puzzle = require("common.engine.Puzzle")
local PuzzleSet = require("client.src.PuzzleSet")

-- the save.lua file contains the read/write functions

local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

local save = {}

-- writes to the "keys.txt" file
function write_key_file()
  pcall(
    function()
      love.filesystem.write("keysV3.json", json.encode(inputManager:getSaveKeyMap()))
    end
  )
end

-- reads the "keys.txt" file
function save.read_key_file()
  local filename
  local migrateInputs = false

  if love.filesystem.getInfo("keysV3.json", "file") then
    filename = "keysV3.json"
  else
    filename = "keysV2.txt"
    migrateInputs = true
  end

  if not love.filesystem.getInfo(filename, "file") then
    return inputManager.inputConfigurations
  else
    local inputConfigs = fileUtils.readJsonFile(filename)

    if migrateInputs then
      -- migrate old input configs
      inputConfigs = inputManager:migrateInputConfigs(inputConfigs)
    end

    return inputConfigs
  end
end

-- reads the .txt file of the given path and filename
function save.read_txt_file(path_and_filename)
  local s
  s = love.filesystem.read(path_and_filename)
  if not s then
    s = "Failed to read file " .. path_and_filename
  else
    s = s:gsub("\r\n?", "\n")
  end
  return s or "Failed to read file"
end

-- writes to the "user_id.txt" file of the directory of the connected ip
function write_user_id_file(userID, serverIP)
  pcall(
    function()
      love.filesystem.createDirectory("servers/" .. serverIP)
      love.filesystem.write("servers/" .. serverIP .. "/user_id.txt", tostring(userID))
    end
  )
end

-- reads the "user_id.txt" file of the directory of the connected ip
function read_user_id_file(serverIP)
  local userID
  pcall(
    function()
      userID = love.filesystem.read("servers/" .. serverIP .. "/user_id.txt")
      userID = userID:match("^%s*(.-)%s*$")
    end
  )
  return userID
end

-- writes the stock puzzles
function write_puzzles()
  pcall(
    function()
      local currentPuzzles = fileUtils.getFilteredDirectoryItems("puzzles") or {}
      local customPuzzleExists = false
      for _, filename in pairs(currentPuzzles) do
        if love.filesystem.getInfo("puzzles/" .. filename) and filename ~= "stock (example).json" and filename ~= "README.txt" then
          customPuzzleExists = true
          break
        end
      end

      if customPuzzleExists == false then
        love.filesystem.createDirectory("puzzles")

        fileUtils.recursiveCopy("client/assets/default_data/puzzles", "puzzles")
      end
    end
  )
end

-- reads the selected puzzle file
function read_puzzles()
  pcall(
    function()
      -- if type(replay.in_buf) == "table" then
      -- replay.in_buf=table.concat(replay.in_buf)
      -- end

      puzzle_packs = fileUtils.getFilteredDirectoryItems("puzzles") or {}
      logger.debug("loading custom puzzles...")
      for _, filename in pairs(puzzle_packs) do
        logger.trace(filename)
        if love.filesystem.getInfo("puzzles/" .. filename) and filename ~= "README.txt" then
          logger.debug("loading custom puzzle set: " .. (filename or "nil"))
          local teh_json = love.filesystem.read("puzzles/" .. filename)
          local current_json = json.decode(teh_json) or {}
          if current_json["Version"] == 2 then
            for _, puzzleSet in pairs(current_json["Puzzle Sets"]) do
              local puzzleSetName = puzzleSet["Set Name"]
              local puzzles = {}
              for _, puzzle in pairs(puzzleSet["Puzzles"]) do
                local puzzle = Puzzle(puzzle["Puzzle Type"], puzzle["Do Countdown"], puzzle["Moves"], puzzle["Stack"], puzzle["Stop"], puzzle["Shake"])
                puzzles[#puzzles + 1] = puzzle
              end

              local puzzleSet = PuzzleSet(puzzleSetName, puzzles)
              GAME.puzzleSets[puzzleSetName] = puzzleSet
            end
          elseif current_json["Version"] ~= 2 and current_json["Version"] then
            error("Puzzle " .. filename .. " specifies invalid version " .. current_json["Version"])
          else -- old file format compatibility
            for set_name, puzzle_set in pairs(current_json) do
              local puzzles = {}
              for _, puzzleData in pairs(puzzle_set) do
                local puzzle = Puzzle("moves", true, puzzleData[2], puzzleData[1])
                puzzles[#puzzles + 1] = puzzle
              end

              local puzzleSet = PuzzleSet(set_name, puzzles)
              GAME.puzzleSets[set_name] = puzzleSet
            end
          end

          logger.debug("loaded above set")
        end
      end
    end
  )
end

function readAttackFile(path)
  if love.filesystem.getInfo(path, "file") then
    local jsonData = love.filesystem.read(path)
    local trainingConf, position, errorMsg = json.decode(jsonData)
    if trainingConf then
      if not trainingConf.name or type(trainingConf.name) ~= "string" then
        local filenameOnly = path:match('%' .. sep .. '?(.*)$')
        if filenameOnly ~= nil then
          trainingConf.name = fileUtils.getFileNameWithoutExtension(filenameOnly)
        end
      end
      return trainingConf
    else
      error("Error deserializing " .. path .. ": " .. errorMsg .. " at position " .. position)
    end
  end
end

function readAttackFiles(path)
  local results = {}
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for _, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path) then
      if lfs.getInfo(current_path).type == "directory" then
        readAttackFiles(current_path)
      else
        local training_conf = readAttackFile(current_path)
        if training_conf ~= nil then
          results[#results+1] = training_conf
        end
      end
    end
  end

  return results
end

function saveJSONToPath(data, state, path)
  love.filesystem.write(path, json.encode(data, state))
end

function print_list(t)
  for i, v in ipairs(t) do
    print(v)
  end
end

return save
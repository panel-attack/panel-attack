-- the save.lua file contains the read/write functions

local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")
local logger = require("logger")

-- writes to the "keys.txt" file
function write_key_file()
  pcall(
    function()
      local file = love.filesystem.newFile("keysV2.txt")
      file:open("w")
      file:write(json.encode(GAME.input.inputConfigurations))
      file:close()
    end
  )
end
-- reads the "keys.txt" file
function read_key_file()
  pcall(
    function()
      local inputConfigs = GAME.input.inputConfigurations
      local file = love.filesystem.newFile("keysV2.txt")
      file:open("r")
      local teh_json = file:read(file:getSize())
      file:close()
      local user_conf = json.decode(teh_json)
      for k, v in ipairs(user_conf) do
        inputConfigs[k] = v
      end

      GAME.input.inputConfigurations = inputConfigs
    end
  )
end

-- reads the .txt file of the given path and filename
function read_txt_file(path_and_filename)
  local s
  pcall(
    function()
      local file = love.filesystem.newFile(path_and_filename)
      file:open("r")
      s = file:read(file:getSize())
      file:close()
    end
  )
  if not s then
    s = "Failed to read file" .. path_and_filename
  else
    s = s:gsub("\r\n?", "\n")
  end
  return s or "Failed to read file"
end

-- writes to the "user_id.txt" file of the directory of the connected ip
function write_user_id_file()
  pcall(
    function()
      love.filesystem.createDirectory("servers/" .. GAME.connected_server_ip)
      local file = love.filesystem.newFile("servers/" .. GAME.connected_server_ip .. "/user_id.txt")
      file:open("w")
      file:write(tostring(my_user_id))
      file:close()
    end
  )
end

-- reads the "user_id.txt" file of the directory of the connected ip
function read_user_id_file()
  pcall(
    function()
      local file = love.filesystem.newFile("servers/" .. GAME.connected_server_ip .. "/user_id.txt")
      file:open("r")
      my_user_id = file:read()
      file:close()
      my_user_id = my_user_id:match("^%s*(.-)%s*$")
    end
  )
end

-- writes the stock puzzles
function write_puzzles()
  pcall(
    function()
      local currentPuzzles = FileUtil.getFilteredDirectoryItems("puzzles") or {}
      local customPuzzleExists = false
      for _, filename in pairs(currentPuzzles) do
        if love.filesystem.getInfo("puzzles/" .. filename) and filename ~= "stock (example).json" and filename ~= "README.txt" then
          customPuzzleExists = true
          break
        end
      end

      if customPuzzleExists == false then
        love.filesystem.createDirectory("puzzles")

        recursive_copy("default_data/puzzles", "puzzles")
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

      puzzle_packs = FileUtil.getFilteredDirectoryItems("puzzles") or {}
      logger.debug("loading custom puzzles...")
      for _, filename in pairs(puzzle_packs) do
        logger.trace(filename)
        if love.filesystem.getInfo("puzzles/" .. filename) and filename ~= "README.txt" then
          logger.debug("loading custom puzzle set: " .. (filename or "nil"))
          local current_set = {}
          local file = love.filesystem.newFile("puzzles/" .. filename)
          file:open("r")
          local teh_json = file:read(file:getSize())
          file:close()
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
        trainingConf.name = path:match(package.config:sub(1, 1) .. '(.*)$')
        trainingConf.name = FileUtil.getFileNameWithoutExtension(trainingConf.name)
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
  local raw_dir_list = FileUtil.getFilteredDirectoryItems(path)
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
  pcall(
    function()
      local file = love.filesystem.newFile(path)
      file:open("w")
      file:write(json.encode(data, state))
      file:close()
    end
  )
end

function print_list(t)
  for i, v in ipairs(t) do
    print(v)
  end
end

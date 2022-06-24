local config = require("config")
local config_metadata = require("config_metadata")
local replay_browser = require("replay_browser")

--- @module save
-- the save.lua file contains the read/write functions
local save = {}

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
function save.read_key_file()
  local file = love.filesystem.newFile("keysV2.txt")
  local ok, err = file:open("r")
  
  if not ok then
    return nil
  end
  
  local json_user_conf = file:read(file:getSize())
  file:close()
  
  local user_conf = json.decode(json_user_conf)
  
  return user_conf
end

-- reads the .txt file of the given path and filename
function save.read_txt_file(path_and_filename)
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

-- writes to the "conf.json" file
function write_conf_file()
  pcall(
    function()
      local file = love.filesystem.newFile("conf.json")
      file:open("w")
      file:write(json.encode(GAME.config))
      file:close()
    end
  )
end

-- writes to the "conf.json" file
function save.write_conf_file()
  pcall(
    function()
      local file = love.filesystem.newFile("conf.json")
      file:open("w")
      file:write(json.encode(GAME.config))
      file:close()
    end
  )
end

-- reads the "conf.json" file
-- falls back to the default config
function save.read_conf_file()
  local file = love.filesystem.newFile("conf.json")
  local ok, err = file:open("r")
  
  if not ok then
    return config
  end
  
  local json_user_config = file:read(file:getSize())
  local user_config = json.decode(json_user_config)
  
  -- do stuff using read_data.version for retrocompatibility here

  -- language_code, panels, character and stage are patched later on by their own subsystems, we store their values in config for now!
  for key, value in pairs(config) do
    if user_config[key] 
        and type(user_config[key]) == type(config[key]) 
        and (not config_metadata.isValid[key] or config_metadata.isValid[key](value)) then
      local user_value = user_config[key]
      if config_metadata.processValue[key] then
        user_value = config_metadata.processValue[key](user_value)
      end
      user_config[key] = user_value
    else
      user_config[key] = value
    end
  end

  file:close()
  return user_config
end

-- reads the "replay.txt" file
function save.read_replay_file()
  local file = love.filesystem.newFile("replay.txt")
  local ok, err = file:open("r")
  
  if not ok then
    return nil
  end
  
  local json_user_replays = file:read(file:getSize())
  local user_replays = json.decode(json_user_replays)
  
  if type(user_replays.in_buf) == "table" then
    user_replays.in_buf = table.concat(user_replays.in_buf)
    save.write_replay_file()
  end
  return user_replays
end

-- writes a replay file of the given path and filename
function save.write_replay_file(path, filename)
  pcall(
    function()
      local file
      if path and filename then
        love.filesystem.createDirectory(path)
        file = love.filesystem.newFile(path .. "/" .. filename)
        replay_browser.set_replay_browser_path(path)
      else
        file = love.filesystem.newFile("replay.txt")
      end
      file:open("w")
      print("Writing to Replay File")
      if replay.puzzle then
        replay.puzzle.in_buf = compress_input_string(replay.puzzle.in_buf)
        print("Compressed puzzle in_buf")
        print(replay.puzzle.in_buf)
      else
        print("No Puzzle")
      end
      if replay.endless then
        replay.endless.in_buf = compress_input_string(replay.endless.in_buf)
        print("Compressed endless in_buf")
        print(replay.endless.in_buf)
      else
        print("No Endless")
      end
      if replay.vs then
        replay.vs.I = compress_input_string(replay.vs.I)
        replay.vs.in_buf = compress_input_string(replay.vs.in_buf)
        print("Compressed vs I/in_buf")
      else
        print("No vs")
      end
      file:write(json.encode(replay))
      file:close()
    end
  )
end

-- writes a replay file of the given path and filename
function write_replay_file(path, filename)
  pcall(
    function()
      local file
      if path and filename then
        love.filesystem.createDirectory(path)
        file = love.filesystem.newFile(path .. "/" .. filename)
        set_replay_browser_path(path)
      else
        file = love.filesystem.newFile("replay.txt")
      end
      file:open("w")
      logger.debug("Writing to Replay File")
      if replay.puzzle then
        replay.puzzle.in_buf = compress_input_string(replay.puzzle.in_buf)
        logger.debug("Compressed puzzle in_buf")
        logger.debug(replay.puzzle.in_buf)
      else
        logger.debug("No Puzzle")
      end
      if replay.endless then
        replay.endless.in_buf = compress_input_string(replay.endless.in_buf)
        logger.debug("Compressed endless in_buf")
        logger.debug(replay.endless.in_buf)
      else
        logger.debug("No Endless")
      end
      if replay.vs then
        replay.vs.I = compress_input_string(replay.vs.I)
        replay.vs.in_buf = compress_input_string(replay.vs.in_buf)
        logger.debug("Compressed vs I/in_buf")
      else
        logger.debug("No vs")
      end
      file:write(json.encode(replay))
      file:close()
    end
  )
end

-- writes to the "user_id.txt" file of the directory of the connected ip
function write_user_id_file()
  pcall(
    function()
      love.filesystem.createDirectory("servers/" .. connected_server_ip)
      local file = love.filesystem.newFile("servers/" .. connected_server_ip .. "/user_id.txt")
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
      local file = love.filesystem.newFile("servers/" .. connected_server_ip .. "/user_id.txt")
      file:open("r")
      my_user_id = file:read()
      my_user_id = my_user_id:match("^%s*(.-)%s*$")
      file:close()
    end
  )
end

-- writes the stock puzzles
function write_puzzles()
  pcall(
    function()
      local currentPuzzles = love.filesystem.getDirectoryItems("puzzles") or {}
      local customPuzzleExists = false
      for _, filename in pairs(currentPuzzles) do
        if love.filesystem.getInfo("puzzles/" .. filename) and filename ~= ".DS_Store" and filename ~= "stock (example).json" and filename ~= "README.txt" then
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

      puzzle_packs = love.filesystem.getDirectoryItems("puzzles") or {}
      logger.debug("loading custom puzzles...")
      for _, filename in pairs(puzzle_packs) do
        logger.trace(filename)
        if love.filesystem.getInfo("puzzles/" .. filename) and filename ~= "README.txt" and filename ~= ".DS_Store" then
          logger.debug("loading custom puzzle set: " .. (filename or "nil"))
          local current_set = {}
          local file = love.filesystem.newFile("puzzles/" .. filename)
          file:open("r")
          local teh_json = file:read(file:getSize())
          local current_json = json.decode(teh_json) or {}
          if current_json["Version"] == 2 then
            for _, puzzleSet in pairs(current_json["Puzzle Sets"]) do
              local puzzleSetName = puzzleSet["Set Name"]
              local puzzles = {}
              for _, puzzle in pairs(puzzleSet["Puzzles"]) do
                local puzzle = Puzzle(puzzle["Puzzle Type"], puzzle["Do Countdown"], puzzle["Moves"], puzzle["Stack"])
                puzzles[#puzzles+1] = puzzle
              end

              local puzzleSet = PuzzleSet(puzzleSetName, puzzles)
              GAME.puzzleSets[puzzleSetName] = puzzleSet
            end
          else -- old file format compatibility
            for set_name, puzzle_set in pairs(current_json) do
              local puzzles = {}
              for _, puzzleData in pairs(puzzle_set) do
                local puzzle = Puzzle("moves", true, puzzleData[2], puzzleData[1])
                puzzles[#puzzles+1] = puzzle
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

function print_list(t)
  for i, v in ipairs(t) do
    print(v)
  end
end

-- copies a file from the given source to the given destination
function save.copy_file(source, destination)
  local lfs = love.filesystem
  local source_file = lfs.newFile(source)
  source_file:open("r")
  local source_size = source_file:getSize()
  temp = source_file:read(source_size)
  source_file:close()

  local new_file = lfs.newFile(destination)
  new_file:open("w")
  local success, message = new_file:write(temp, source_size)
  new_file:close()
end

-- copies a file from the given source to the given destination
function recursive_copy(source, destination)
  local lfs = love.filesystem
  local names = lfs.getDirectoryItems(source)
  local temp
  for i, name in ipairs(names) do
    local info = lfs.getInfo(source .. "/" .. name)
    if info and info.type == "directory" then
      logger.trace("calling recursive_copy(source" .. "/" .. name .. ", " .. destination .. "/" .. name .. ")")
      recursive_copy(source .. "/" .. name, destination .. "/" .. name)
    elseif info and info.type == "file" then
      local destination_info = lfs.getInfo(destination)
      if not destination_info or destination_info.type ~= "directory" then
        love.filesystem.createDirectory(destination)
      end
      logger.trace("copying file:  " .. source .. "/" .. name .. " to " .. destination .. "/" .. name)

      local source_file = lfs.newFile(source .. "/" .. name)
      source_file:open("r")
      local source_size = source_file:getSize()
      temp = source_file:read(source_size)
      source_file:close()

      local new_file = lfs.newFile(destination .. "/" .. name)
      new_file:open("w")
      local success, message = new_file:write(temp, source_size)
      new_file:close()

      if not success then
        logger.warn(message)
      end
    else
      logger.warn("name:  " .. name .. " isn't a directory or file?")
    end
  end
end

return save
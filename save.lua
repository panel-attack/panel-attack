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
      local user_conf = json.decode(teh_json)
      file:close()
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

-- writes to the "conf.json" file
function write_conf_file()
  pcall(
    function()
      local file = love.filesystem.newFile("conf.json")
      file:open("w")
      file:write(json.encode(config))
      file:close()
    end
  )
end

local use_music_from_values = {stage = true, often_stage = true, either = true, often_characters = true, characters = true}
local save_replays_values = {["with my name"] = true, anonymously = true, ["not at all"] = true}

-- reads the "conf.json" file
function read_conf_file()
  pcall(
    function()
      -- config current values are defined in globals.lua,
      -- we consider those values are currently in config

      local file = love.filesystem.newFile("conf.json")
      file:open("r")
      local read_data = {}
      local teh_json = file:read(file:getSize())
      for k, v in pairs(json.decode(teh_json)) do
        read_data[k] = v
      end

      -- do stuff using read_data.version for retrocompatibility here

      if type(read_data.theme) == "string" and love.filesystem.getInfo("themes/" .. read_data.theme) then
        config.theme = read_data.theme
      end

      -- language_code, panels, character and stage are patched later on by their own subsystems, we store their values in config for now!
      if type(read_data.language_code) == "string" then
        config.language_code = read_data.language_code
      end
      if type(read_data.panels) == "string" then
        config.panels = read_data.panels
      end
      if type(read_data.character) == "string" then
        config.character = read_data.character
      end
      if type(read_data.stage) == "string" then
        config.stage = read_data.stage
      end

      if type(read_data.ranked) == "boolean" then
        config.ranked = read_data.ranked
      end

      if type(read_data.vsync) == "boolean" then
        config.vsync = read_data.vsync
      end

      if type(read_data.use_music_from) == "string" and use_music_from_values[read_data.use_music_from] then
        config.use_music_from = read_data.use_music_from
      end

      if type(read_data.level) == "number" then
        config.level = bound(1, read_data.level, 10)
      end
      if type(read_data.endless_speed) == "number" then
        config.endless_speed = bound(1, read_data.endless_speed, 99)
      end
      if type(read_data.endless_difficulty) == "number" then
        config.endless_difficulty = bound(1, read_data.endless_difficulty, 3)
      end
      if type(read_data.endless_level) == "number" then
        config.endless_level = bound(1, read_data.endless_level, 11)
      end
      if type(read_data.puzzle_level) == "number" then
        config.puzzle_level = bound(1, read_data.puzzle_level, 11)
      end
      if type(read_data.puzzle_randomColors) == "boolean" then
        config.puzzle_randomColors = read_data.puzzle_randomColors
      end

      if type(read_data.name) == "string" then
        config.name = read_data.name
      end

      if type(read_data.master_volume) == "number" then
        config.master_volume = bound(0, read_data.master_volume, 100)
      end
      if type(read_data.SFX_volume) == "number" then
        config.SFX_volume = bound(0, read_data.SFX_volume, 100)
      end
      if type(read_data.music_volume) == "number" then
        config.music_volume = bound(0, read_data.music_volume, 100)
      end
      if type(read_data.input_repeat_delay) == "number" then
        config.input_repeat_delay = bound(1, read_data.input_repeat_delay, 50)
      end
      if type(read_data.portrait_darkness) == "number" then
        config.portrait_darkness = bound(0, read_data.portrait_darkness, 100)
      end
      if type(read_data.cardfx_scale) == "number" then
        config.cardfx_scale = bound(1, read_data.cardfx_scale, 200)
      end

      if type(read_data.debug_mode) == "boolean" then
        config.debug_mode = read_data.debug_mode
      end
      if type(read_data.show_fps) == "boolean" then
        config.show_fps = read_data.show_fps
      end
      if type(read_data.show_ingame_infos) == "boolean" then
        config.show_ingame_infos = read_data.show_ingame_infos
      end
      if type(read_data.ready_countdown_1P) == "boolean" then
        config.ready_countdown_1P = read_data.ready_countdown_1P
      end
      if type(read_data.danger_music_changeback_delay) == "boolean" then
        config.danger_music_changeback_delay = read_data.danger_music_changeback_delay
      end
      if type(read_data.enable_analytics) == "boolean" then
        config.enable_analytics = read_data.enable_analytics
      end
      if type(read_data.popfx) == "boolean" then
        config.popfx = read_data.popfx
      end

      if type(read_data.save_replays_publicly) == "string" and save_replays_values[read_data.save_replays_publicly] then
        config.save_replays_publicly = read_data.save_replays_publicly
      end

      if type(read_data.window_x) == "number" then
        config.window_x = read_data.window_x
      end
      if type(read_data.window_y) == "number" then
        config.window_y = read_data.window_y
      end
      if type(read_data.display) == "number" then
        config.display = read_data.display
      end
      if type(read_data.fullscreen) == "boolean" then
        config.fullscreen = read_data.fullscreen
      end
      if type(read_data.defaultPanelsCopied) == "boolean" then
        config.defaultPanelsCopied = read_data.defaultPanelsCopied
      end

      file:close()
    end
  )
end

-- reads the "replay.txt" file
function read_replay_file()
  pcall(
    function()
      local file = love.filesystem.newFile("replay.txt")
      file:open("r")
      local teh_json = file:read(file:getSize())
      replay = json.decode(teh_json)
      if type(replay.in_buf) == "table" then
        replay.in_buf = table.concat(replay.in_buf)
        write_replay_file()
      end
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
function copy_file(source, destination)
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

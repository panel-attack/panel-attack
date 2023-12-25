local lfs = require("lfs")
local logger = require("logger")
local csvfile = require("libraries.simplecsv")
local tableUtils = require("tableUtils")

function makeDirectory(path) 
  local status, error = pcall(
    function()
      lfs.mkdir(path)
    end
  )
  if not status then
    logger.error("Failed to make directory: " .. path .. " error: " .. error)
  end
end

function makeDirectoryRecursive(path)
  local sep, pStr = package.config:sub(1, 1), ""
  for dir in path:gmatch("[^" .. sep .. "]+") do
    pStr = pStr .. dir .. sep
    makeDirectory(pStr)
  end
end

function fileExists(name)
  local f=io.open(name,"r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function write_players_file(playerbase)
  if playerbase.filename == nil then
    return
  end

  local status, error = pcall(
    function()
      local f = assert(io.open(playerbase.filename, "w"))
      io.output(f)
      io.write(json.encode(playerbase.players))
      io.close(f)
    end
  )
  if not status then
    logger.error("Failed to write players file with error: " .. error)
  end
end

function read_players_file(playerbase)
  if playerbase.filename == nil then
    return
  end
  
  pcall(
    function()
      local f = io.open(playerbase.filename, "r")
      if f then
        io.input(f)
        local data = io.read("*all")
        playerbase.players = json.decode(data)
        logger.info(table.length(playerbase.players) .. " players loaded")
        io.close(f)
      end
    end
  )
end


function logGameResult(player1ID, player2ID, player1Won, rankedValue)
  local status, error = pcall(
    function()
      local f = assert(io.open("GameResults.csv", "a"))
      io.output(f)
      io.write(player1ID .. "," .. player2ID .. "," .. player1Won .. "," .. rankedValue .. "," .. os.time() .. "\n")
      io.close(f)
    end
  )
  if not status then
    logger.error("Failed to log game result: " .. error)
  end
end

function readGameResults()

  local filename = "GameResults.csv"

  local gameResults = nil
  pcall(
    function()
      gameResults = csvfile.read(filename)
    end
  )
  return gameResults
end

function write_error_report(error_report_json)
  local json_string = json.encode(error_report_json)
  if json_string:len() >= 5000 --[[5kB]] then
    return false
  end
  local sep = package.config:sub(1, 1)
  local now = os.date("*t", to_UTC(os.time()))
  local filename = "v" .. (error_report_json.engine_version or "000") .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec) .. "_" .. (error_report_json.name or "Unknown") .. "-ErrorReport.json"
  return pcall(
    function()
      local f = assert(io.open("reports" .. sep .. filename, "w"))
      io.output(f)
      io.write(json_string)
      io.close(f)
    end
  )
end

function write_leaderboard_file()
  local status, error = pcall(
    function()
      -- local f = assert(io.open("leaderboard.txt", "w"))
      -- io.output(f)
      -- io.write(json.encode(leaderboard.players))
      -- io.close(f)
      --now also write a CSV version of the file
      --local csv = "user_id,user_name,rating,placement_done,placement_rating,ranked_games_played,ranked_games_won,last_login_time"
      local sep = package.config:sub(1, 1)
      local leaderboard_table = {}
      local public_leaderboard_table = {}
      leaderboard_table[#leaderboard_table + 1] = {"user_id", "user_name", "rating", "placement_done", "placement_rating", "ranked_games_played", "ranked_games_won","last_login_time"}
      public_leaderboard_table[#public_leaderboard_table + 1] = {"user_name", "rating", "ranked_games_played"} --excluding ranked_games_won for now because it doesn't track properly, and user_id because they are secret.
      for user_id, v in pairs(leaderboard.players) do
        leaderboard_table[#leaderboard_table + 1] = {user_id, v.user_name, v.rating, tostring(v.placement_done or ""), v.placement_rating, v.ranked_games_played, v.ranked_games_won, v.last_login_time}
        public_leaderboard_table[#public_leaderboard_table + 1] = {v.user_name, v.rating, v.ranked_games_played}
      end
      csvfile.write("." .. sep .. "leaderboard.csv", leaderboard_table)
      makeDirectoryRecursive("." .. sep .. "ftp")
      csvfile.write("." .. sep .. "ftp" .. sep .. "PA_public_leaderboard.csv", public_leaderboard_table)
    end
  )
  if not status then
    logger.error("Failed to write leaderboard file with error: " .. error)
  end
end

function read_leaderboard_file()
  local filename = "./leaderboard.csv"

  local csv_table = {}
  local status, error = pcall(
    function()
      csv_table = csvfile.read(filename)
    end
  )
  if not status then
  elseif csv_table ~= nil and csv_table[2] then
    logger.debug("loading leaderboard.csv")
    for row = 2, #csv_table do
      csv_table[row][1] = tostring(csv_table[row][1])
      leaderboard.players[csv_table[row][1]] = {}
      for col = 1, #csv_table[1] do
        --Note csv_table[row][1] will be the player's user_id
        --csv_table[1][col] will be a property name such as "rating"
        if csv_table[row][col] == "" then
          csv_table[row][col] = nil
        end
        --player with this user_id gets this property equal to the csv_table cell's value
        if csv_table[1][col] == "user_name" then
          leaderboard.players[csv_table[row][1]][csv_table[1][col]] = tostring(csv_table[row][col])
        elseif csv_table[1][col] == "rating" then
          leaderboard.players[csv_table[row][1]][csv_table[1][col]] = tonumber(csv_table[row][col])
        elseif csv_table[1][col] == "placement_done" then
          leaderboard.players[csv_table[row][1]][csv_table[1][col]] = csv_table[row][col] and true and string.lower(csv_table[row][col]) ~= "false"
        else
          leaderboard.players[csv_table[row][1]][csv_table[1][col]] = csv_table[row][col]
        end
      end
    end
  end
end

function read_user_placement_match_file(user_id)
  return pcall(
    function()
      local sep = package.config:sub(1, 1)
      local csv_table = csvfile.read("./placement_matches/incomplete/" .. user_id .. ".csv")
      if not csv_table or #csv_table < 2 then
        logger.debug("csv_table from read_user_placement_match_file was nil or <2 length")
        return nil
      else
        logger.debug("csv_table from read_user_placement_match_file :")
        logger.debug(json.encode(csv_table))
      end
      local ret = {}
      for row = 2, #csv_table do
        csv_table[row][1] = tostring(csv_table[row][1]) --change the op_user_id to a string
        ret[#ret + 1] = {}
        for col = 1, #csv_table[1] do
          --Note csv_table[row][1] will be the player's user_id
          --csv_table[1][col] will be a property name such as "rating"
          if csv_table[row][col] == "" then
            csv_table[row][col] = nil
          end
          --player with this user_id gets this property equal to the csv_table cell's value
          if csv_table[1][col] == "op_name" then
            ret[#ret][csv_table[1][col]] = tostring(csv_table[row][col])
          elseif csv_table[1][col] == "op_rating" then
            ret[#ret][csv_table[1][col]] = tonumber(csv_table[row][col])
          elseif csv_table[1][col] == "op_user_id" then
            ret[#ret][csv_table[1][col]] = tostring(csv_table[row][col])
          elseif csv_table[1][col] == "outcome" then
            ret[#ret][csv_table[1][col]] = tonumber(csv_table[row][col])
          else
            ret[#ret][csv_table[1][col]] = csv_table[row][col]
          end
        end
      end
      logger.debug("read_user_placement_match_file ret: ")
      logger.debug(tostring(ret))
      logger.debug(json.encode(ret))
      return ret
    end
  )
end

function move_user_placement_file_to_complete(user_id)
  local status, error = pcall(
    function()
      local sep = package.config:sub(1, 1)
      makeDirectoryRecursive("./placement_matches/complete")
      local moved, err = os.rename("./placement_matches/incomplete/" .. user_id .. ".csv", "./placement_matches/complete/" .. user_id .. ".csv")
    end
  )
  if not status then
    logger.error("Failed to move user placement file to complete: " .. error)
  end
end

function write_user_placement_match_file(user_id, placement_matches)
  local sep = package.config:sub(1, 1)
  local pm_table = {}
  pm_table[#pm_table + 1] = {"op_user_id", "op_name", "op_rating", "outcome"}
  for k, v in ipairs(placement_matches) do
    pm_table[#pm_table + 1] = {v.op_user_id, v.op_name, v.op_rating, v.outcome}
  end
  makeDirectoryRecursive("placement_matches" .. sep .. "incomplete")
  local fullFileName = "placement_matches" .. sep .. "incomplete" .. sep .. user_id .. ".csv"
  local status, error = pcall(
    function()
      csvfile.write(fullFileName, pm_table)
    end
  )
  if not status then
    logger.error("Failed to write user placement match file: " .. fullFileName .. " with error: " .. error)
  end
end

function write_replay_file(replay, path, filename)
  local sep = package.config:sub(1, 1)
  local status, error = pcall(
    function()
      makeDirectoryRecursive(path)
      local f = assert(io.open(path .. sep .. filename, "w"))
      io.output(f)
      io.write(json.encode(replay))
      io.close(f)
    end
  )
  if not status then
    logger.error("Failed to write replay file: " .. path .. sep .. filename .. " with error: " .. error)
  end
end

function read_csprng_seed_file()
  pcall(
    function()
      local f = io.open("csprng_seed.txt", "r")
      if f then
        io.input(f)
        csprng_seed = io.read("*all")
        io.close(f)
      else
        csprng_seed = math.random(1,99999)
        print("csprng_seed.txt could not be read.  Writing a new csprng_seed.txt")
        local new_file = io.open("csprng_seed.txt", "w")
        if new_file then
          io.output(new_file)
          io.write(csprng_seed)
          io.close(new_file)
        end
      end
      if tonumber(csprng_seed) then
        local tempvar = tonumber(csprng_seed)
        csprng_seed = tempvar
      else
        error("ERROR: csprng_seed.txt content is not numeric.")
      end
    end
  )
end

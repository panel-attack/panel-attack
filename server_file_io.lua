local lfs = require("lfs")
local csvfile = require("simplecsv")

function os_rename(old_name, new_name)
  os.rename(old_name, new_name)
end

function isFile(name)
  if type(name) ~= "string" then
    return false
  end
  if not isDir(name) then
    return os.rename(name, name) and true or false
  -- note that the short evaluation is to
  -- return false instead of a possible nil
  end
  return false
end

function isFileOrDir(name)
  if type(name) ~= "string" then
    return false
  end
  return os.rename(name, name) and true or false
end

function isDir(name)
  if type(name) ~= "string" then
    return false
  end
  local cd = lfs.currentdir()
  local is = lfs.chdir(name) and true or false
  lfs.chdir(cd)
  return is
end

function mkDir(path)
  local sep, pStr = package.config:sub(1, 1), ""
  for dir in path:gmatch("[^" .. sep .. "]+") do
    pStr = pStr .. dir .. sep
    lfs.mkdir(pStr)
  end
end

function write_players_file()
  pcall(
    function()
      local f = assert(io.open("players.txt", "w"))
      io.output(f)
      io.write(json.encode(playerbase.players))
      io.close(f)
    end
  )
end

function read_players_file()
  pcall(
    function()
      local f = assert(io.open("players.txt", "r"))
      io.input(f)
      playerbase.players = json.decode(io.read("*all"))
      io.close(f)
    end
  )
end

function write_deleted_players_file()
  pcall(
    function()
      local f = assert(io.open("deleted_players.txt", "w"))
      io.output(f)
      io.write(json.encode(playerbase.players))
      io.close(f)
    end
  )
end

function read_deleted_players_file()
  pcall(
    function()
      local f = assert(io.open("deleted_players.txt", "r"))
      io.input(f)
      playerbase.deleted_players = json.decode(io.read("*all"))
      io.close(f)
    end
  )
end

function write_leaderboard_file()
  pcall(
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
      csvfile.write("." .. sep .. "ftp" .. sep .. "PA_public_leaderboard.csv", public_leaderboard_table)
    end
  )
end

function read_leaderboard_file()
  pcall(
    function()
      local csv_table = csvfile.read("./leaderboard.csv")
      if csv_table[2] then
        print("read leaderboard.csv")
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
      else
        print("failed to read any data from leaderboard.csv, checking for a leaderboard.txt")
        local f = assert(io.open("leaderboard.txt", "r"))
        io.input(f)
        leaderboard.players = json.decode(io.read("*all"))
        io.close(f)
      end
    end
  )
end

function read_user_placement_match_file(user_id)
  return pcall(
    function()
      local sep = package.config:sub(1, 1)
      local csv_table = csvfile.read("./placement_matches/incomplete/" .. user_id .. ".csv")
      if not csv_table or #csv_table < 2 then
        print("csv_table from read_user_placement_match_file was nil or <2 length")
        return nil
      else
        print("csv_table from read_user_placement_match_file :")
        print(json.encode(csv_table))
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
      print("read_user_placement_match_file ret: ")
      print(tostring(ret))
      print(json.encode(ret))
      return ret
    end
  )
end

function move_user_placement_file_to_complete(user_id)
  pcall(
    function()
      local sep = package.config:sub(1, 1)
      mkDir("./placement_matches/complete")
      local moved, err = os.rename("./placement_matches/incomplete/" .. user_id .. ".csv", "./placement_matches/complete/" .. user_id .. ".csv")
    end
  )
end

function write_user_placement_match_file(user_id, placement_matches)
  pcall(
    function()
      local sep = package.config:sub(1, 1)
      local pm_table = {}
      pm_table[#pm_table + 1] = {"op_user_id", "op_name", "op_rating", "outcome"}
      for k, v in ipairs(placement_matches) do
        pm_table[#pm_table + 1] = {v.op_user_id, v.op_name, v.op_rating, v.outcome}
      end
      mkDir("placement_matches" .. sep .. "incomplete")
      csvfile.write("placement_matches" .. sep .. "incomplete" .. sep .. user_id .. ".csv", pm_table)
    end
  )
end

function write_replay_file(replay, path, filename)
  pcall(
    function()
      local sep = package.config:sub(1, 1)
      print("about to open new replay file for writing")
      mkDir(path)
      local f = assert(io.open(path .. sep .. filename, "w"))
      print("past file open")
      io.output(f)
      io.write(json.encode(replay))
      io.close(f)
      print("finished write_replay_file()")
    end
  )
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
        print("csprng_seed.txt could not be read.  Writing a new default (2000) csprng_seed.txt")
        local new_file = io.open("csprng_seed.txt", "w")
        io.output(new_file)
        io.write("2000")
        io.close(new_file)
        csprng_seed = "2000"
      end
      if tonumber(csprng_seed) then
        local tempvar = tonumber(csprng_seed)
        csprng_seed = tempvar
      else
        print("ERROR: csprng_seed.txt content is not numeric.  Using default (2000) as csprng_seed")
        csprng_seed = 2000
      end
    end
  )
end

--old
-- function write_replay_file(replay_table, file_name) pcall(function()
-- local f = io.open(file_name, "w")
-- io.output(f)
-- io.write(json.encode(replay_table))
-- io.close(f)
-- end) end

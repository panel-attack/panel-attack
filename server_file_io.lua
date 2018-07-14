local lfs = require("lfs")

function isFile(name)
    if type(name)~="string" then return false end
    if not isDir(name) then
        return os.rename(name,name) and true or false
        -- note that the short evaluation is to
        -- return false instead of a possible nil
    end
    return false
end

function isFileOrDir(name)
    if type(name)~="string" then return false end
    return os.rename(name, name) and true or false
end

function isDir(name)
    if type(name)~="string" then return false end
    local cd = lfs.currentdir()
    local is = lfs.chdir(name) and true or false
    lfs.chdir(cd)
    return is
end

function mkDir(path)
  print("mkDir(path)")
  local sep, pStr = package.config:sub(1, 1), ""
  for dir in path:gmatch("[^" .. sep .. "]+") do
    pStr = pStr .. dir .. sep
    lfs.mkdir(pStr)
  end
  print("got to the end of mkDir(path)")
end

function write_players_file() pcall(function()
  local f = assert(io.open("players.txt", "w"))
  io.output(f)
  io.write(json.encode(playerbase.players))
  io.close(f)
end) end

function read_players_file() pcall(function()
  local f = assert(io.open("players.txt", "r"))
  io.input(f)
  playerbase.players = json.decode(io.read("*all"))
  io.close(f)
end) end

function write_deleted_players_file() pcall(function()
  local f = assert(io.open("deleted_players.txt", "w"))
  io.output(f)
  io.write(json.encode(playerbase.players))
  io.close(f)
end) end

function read_deleted_players_file() pcall(function()
  local f = assert(io.open("deleted_players.txt", "r"))
  io.input(f)
  playerbase.deleted_players = json.decode(io.read("*all"))
  io.close(f)
end) end

function write_leaderboard_file() pcall(function()
  local f = assert(io.open("leaderboard.txt", "w"))
  io.output(f)
  io.write(json.encode(leaderboard.players))
  io.close(f)
end) end

function read_leaderboard_file() pcall(function()
  local f = assert(io.open("leaderboard.txt", "r"))
  io.input(f)
  leaderboard.players = json.decode(io.read("*all"))
  io.close(f)
end) end

function write_replay_file(replay, path, filename) pcall(function()
  print("about to open new replay file for writing")
  mkDir(path)
  local f = assert(io.open(path.."/"..filename, "w"))
  print("past file open")
  io.output(f)
  io.write(json.encode(replay))
  io.close(f)
  print("finished write_replay_file()")
end) end

function read_csprng_seed_file() pcall(function()
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
end) end

--old
-- function write_replay_file(replay_table, file_name) pcall(function()
  -- local f = io.open(file_name, "w")
  -- io.output(f)
  -- io.write(json.encode(replay_table))
  -- io.close(f)
-- end) end
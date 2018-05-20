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
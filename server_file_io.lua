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
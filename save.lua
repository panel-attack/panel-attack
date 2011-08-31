function write_key_file() pcall(function()
  local file = love.filesystem.newFile("keys.txt")
  local to_write = {}
  for _,name in ipairs(key_names) do
    to_write[name] = _G[name]
  end
  file:open("w")
  file:write(json.encode(to_write))
  file:close()
end) end

function read_key_file() pcall(function()
  local file = love.filesystem.newFile("keys.txt")
  file:open("r")
  local teh_json = file:read(file:getSize())
  local user_conf = json.decode(teh_json)
  file:close()
  for _,name in ipairs(key_names) do
    _G[name] = user_conf[name] or _G[name]
  end
end) end

function read_replay_file() pcall(function()
  local file = love.filesystem.newFile("replay.txt")
  file:open("r")
  local teh_json = file:read(file:getSize())
  replay = json.decode(teh_json)
  if type(replay.in_buf) == "table" then
    replay.in_buf=table.concat(replay.in_buf)
    write_replay_file()
  end
end) end

function write_replay_file() pcall(function()
  local file = love.filesystem.newFile("replay.txt")
  file:open("w")
  file:write(json.encode(replay))
  file:close()
end) end

-- Used to load and write data to files.
-- Stores user configs and game states

local sep = package.config:sub(1, 1) -- determines os directory separator (i.e. "/" or "\")

-- write keys.txt file
function write_key_file() pcall(function()
  local file = love.filesystem.newFile("keys.txt")
  file:open("w")
  file:write(json.encode(K))
  file:close()
end) end

-- read keys.txt file
function read_key_file() pcall(function()
  local K=K
  local file = love.filesystem.newFile("keys.txt")
  file:open("r")
  local teh_json = file:read(file:getSize())
  -- load user config
  local user_conf = json.decode(teh_json)
  file:close()
  -- TODO: remove this later, it just converts the old format.
  if #user_conf == 0 then
    local new_conf = {}
    for k,v in pairs(user_conf) do
      new_conf[k:sub(3)] = v
    end
    user_conf = {new_conf, {}, {}, {}}
  end
  for k,v in ipairs(user_conf) do
    keyboard[k]=v
  end
end) end

-- read given txt file
function read_txt_file(path_and_filename)
  assert(path_and_filename)
  local file_size
  pcall(function()
    local file = love.filesystem.newFile(path_and_filename)
    file:open("r")
    file_size= file:read(file:getSize())
    file:close()
  end)
  if not file_size then
    file_size  = "Failed to read file"..path_and_filename
  else
    -- substitute multiple newlines for one newline
    file_size = file_size:gsub('\r\n?', '\n')
  end
  return file_size or "Failed to read file"
 end

-- write configuration to JSON file
function write_conf_file() pcall(function()
  local file = love.filesystem.newFile("conf.json")
  file:open("w")
  file:write(json.encode(config))
  file:close()
end) end

-- read configuration from JSON file
function read_conf_file() pcall(function()
  local file = love.filesystem.newFile("conf.json")
  file:open("r")
  local teh_json = file:read(file:getSize())
  for k,v in pairs(json.decode(teh_json)) do
    config[k] = v
  end
  file:close()
end) end

-- read replay file
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

-- write replay file to default path
function write_replay_file() pcall(function()
  local file = love.filesystem.newFile("replay.txt")
  file:open("w")
  file:write(json.encode(replay))
  file:close()
end) end

-- Override function to write replay file to specific path
function write_replay_file(path, filename) pcall(function()
  assert(path)
  assert(filename)
  love.filesystem.createDirectory(path)
  local file = love.filesystem.newFile(path.."/"..filename)
  file:open("w")
  file:write(json.encode(replay))
  file:close()
end) end

-- write user id file
function write_user_id_file() pcall(function()
  love.filesystem.createDirectory("servers/"..connected_server_ip)
  local file = love.filesystem.newFile("servers/"..connected_server_ip.."/user_id.txt")
  file:open("w")
  file:write(tostring(my_user_id))
  file:close()
end) end

-- read user id file
function read_user_id_file() pcall(function()
  local file = love.filesystem.newFile("servers/"..connected_server_ip.."/user_id.txt")
  file:open("r")
  my_user_id = file:read()
  file:close()
end) end

-- this function is never called
function print_list(t)
  assert(t)
  for i, v in ipairs(t) do
    print(v)
  end
end

-- copy recursively from files in source
function recursive_copy(source, destination)
  assert(source)
  assert(destination)
  local lfs = love.filesystem
  local names = lfs.getDirectoryItems(source)
  local temp
  for i, name in ipairs(names) do
    if lfs.isDirectory(source.."/"..name) then
      print("calling recursive_copy(source".."/"..name..", ".. destination.."/"..name..")")
      recursive_copy(source.."/"..name, destination.."/"..name)

    elseif lfs.isFile(source.."/"..name) then
      if not lfs.isDirectory(destination) then
       love.filesystem.createDirectory(destination)
      end
      print("copying file:  "..source.."/"..name.." to "..destination.."/"..name)

      local source_file = lfs.newFile(source.."/"..name)
      source_file:open("r")
      local source_size = source_file:getSize()
      temp = source_file:read(source_size)
      source_file:close()

      local new_file = lfs.newFile(destination.."/"..name)
      new_file:open("w")
      local success, message =  new_file:write(temp, source_size)
      new_file:close()

      print(message)
    else
      print("name:  "..name.." isn't a directory or file?")
    end
  end
end

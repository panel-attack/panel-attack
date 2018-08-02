local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

function write_key_file() pcall(function()
  local file = love.filesystem.newFile("keys.txt")
  file:open("w")
  file:write(json.encode(K))
  file:close()
end) end

function read_key_file() pcall(function()
  local K=K
  local file = love.filesystem.newFile("keys.txt")
  file:open("r")
  local teh_json = file:read(file:getSize())
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
    K[k]=v
  end
end) end
function read_txt_file(path_and_filename)
  local s
  pcall(function()
    local file = love.filesystem.newFile(path_and_filename)
    file:open("r")
    s = file:read(file:getSize())
    file:close()
  end)
  if not s then
    s = "Failed to read file"..path_and_filename
  else
  s = s:gsub('\r\n?', '\n')
  end
  return s or "Failed to read file"
 end

function write_conf_file() pcall(function()
  local file = love.filesystem.newFile("conf.json")
  file:open("w")
  file:write(json.encode(config))
  file:close()
end) end

function read_conf_file() pcall(function()
  local file = love.filesystem.newFile("conf.json")
  file:open("r")
  local teh_json = file:read(file:getSize())
  for k,v in pairs(json.decode(teh_json)) do
    config[k] = v
  end
  file:close()
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

function write_replay_file(path, filename) pcall(function()
  love.filesystem.createDirectory(path)
  local file = love.filesystem.newFile(path.."/"..filename)
  file:open("w")
  file:write(json.encode(replay))
  file:close()
end) end

function write_user_id_file() pcall(function()
  love.filesystem.createDirectory("servers/"..connected_server_ip)
  local file = love.filesystem.newFile("servers/"..connected_server_ip.."/user_id.txt")
  file:open("w")
  file:write(tostring(my_user_id))
  file:close()
end) end

function read_user_id_file() pcall(function()
  local file = love.filesystem.newFile("servers/"..connected_server_ip.."/user_id.txt")
  file:open("r")
  my_user_id = file:read()
  file:close()
end) end

function print_list(t)
  for i, v in ipairs(t) do
    print(v)
  end
end

function recursive_copy(source, destination)
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
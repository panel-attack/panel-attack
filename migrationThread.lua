local function log(msg)
  love.filesystem.append("migration.log", msg)
end

local function readFile(filename)
  local content, size = love.filesystem.read(filename)
  if not content then
    local msg = "Failed to read file " .. filename
    love.thread.getChannel("migration"):push(msg)
    log(msg)
  end

  return content
end

local function writeFile(filename, content)
  local success, message = love.filesystem.write(filename, content)
  if not success then
    local msg = "Failed to write to file " .. filename .. ": " .. message
    love.thread.getChannel("migration"):push(msg)
    log(msg)
  end
end

-- copies a file from the given source to the given destination
local function recursive_copy(source, destination)
  local lfs = love.filesystem
  local names = lfs.getDirectoryItems(source)
  log("\nCopying directory " .. source .. " with content\n  " .. table.concat(names, "\n  "))
  for i, name in ipairs(names) do
    local sourceName = source .. "/" .. name
    local destinationName = destination .. "/" .. name
    local info = lfs.getInfo(sourceName)
    if info and info.type == "directory" then
      love.filesystem.createDirectory(destinationName)
      recursive_copy(sourceName, destinationName)
    elseif info and info.type == "file" then
      local content = readFile(sourceName)
      if content then
        writeFile(destinationName, content)
      end
    end
  end

  love.thread.getChannel("migration"):push("Copied\n" .. source .. "\nto\n" .. destination)
end

love.filesystem.remove("migration.log")

local source, destination = ...

recursive_copy(source, destination)
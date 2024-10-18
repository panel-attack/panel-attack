local function log(msg)
  love.filesystem.append("migration.log", msg)
end

-- copies a file from the given source to the given destination
local function recursive_copy(source, destination)
  local lfs = love.filesystem
  local names = lfs.getDirectoryItems(source)
  log("\nCopying directory " .. source .. " with content\n  " .. table.concat(names, "\n  "))
  local temp
  for i, name in ipairs(names) do
    local info = lfs.getInfo(source .. "/" .. name)
    if info and info.type == "directory" then
      recursive_copy(source .. "/" .. name, destination .. "/" .. name)
    elseif info and info.type == "file" then
      local destination_info = lfs.getInfo(destination)
      if not destination_info or destination_info.type ~= "directory" then
        love.filesystem.createDirectory(destination)
      end

      local content, size = love.filesystem.read(source .. "/" .. name)
      local source_file = lfs.newFile(source .. "/" .. name)
      source_file:open("r")
      local source_size = source_file:getSize()
      temp = source_file:read(source_size)
      source_file:close()

      local new_file = lfs.newFile(destination .. "/" .. name)
      new_file:open("w")
      local success, message = new_file:write(temp, source_size)
      new_file:close()
    end
  end

  love.thread.getChannel("migration"):push("Copied\n" .. source .. "\nto\n" .. destination)
end

love.filesystem.remove("migration.log")

local source, destination = ...

recursive_copy(source, destination)
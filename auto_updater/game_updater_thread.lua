local socket = require("socket")
local http = require("socket.http")
require("love.timer")


function download_available_versions(server_url, timeout, max_size, timestamp_file)
  local body = ""
  local all_versions = {}

  http.request{
    url=server_url, 
    create=function()
      local req_sock = socket.tcp()
      -- note the second parameter here
      if timeout then req_sock:settimeout(timeout, 't') end

      return req_sock
    end,
    sink=function(chunk, err)
      if chunk == nil then return false end

      body = body..chunk
      return max_size == nil or #body < max_size
    end
  }

  if body ~= "" then
    for w in body:gmatch('<a href="([/%w_-]+)%.love">') do
      all_versions[#all_versions+1] = w:gsub("^/[/%w_-]+/", "")
    end
  end

  if #all_versions > 0 then
    table.sort(all_versions, function(a,b) return a>b end)
    for i=1,#all_versions do
      all_versions[i] = all_versions[i]..'.love'
    end

    if timestamp_file then
      love.filesystem.write(timestamp_file, os.time())
    end
  end

  love.thread.getChannel("download_available_versions"):push(all_versions)
end

function download_file(server_filepath, local_filepath)
  local body = http.request(server_filepath)
  love.filesystem.write(local_filepath, body)

  love.thread.getChannel("download_file"):push(true)
end

function download_lastest_version(server_url, local_path, version_file, local_version)
  download_available_versions(server_url, nil, nil)
  local versions = nil
  while versions == nil do
    versions = love.thread.getChannel("download_available_versions"):pop()
    love.timer.sleep(0.2)
  end
  if #versions > 0 and versions[1] ~= local_version then
    download_file(server_url.."/"..versions[1], local_path..versions[1])
    local downloaded = nil
    while downloaded == nil do
      downloaded = love.thread.getChannel("download_file"):pop()
      love.timer.sleep(0.2)
    end

    if downloaded then
      love.filesystem.write(version_file, versions[1])
      love.thread.getChannel("download_lastest_version"):push(true)
      return
    end
  end
  love.thread.getChannel("download_lastest_version"):push(false)
end


local ftable = { 
  download_available_versions= download_available_versions,
  download_file= download_file,
  download_lastest_version= download_lastest_version,

}

ftable[select(1, ...)](select(2, ...))
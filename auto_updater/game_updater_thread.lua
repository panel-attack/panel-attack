local socket = require("socket")
local http = require("socket.http")

local fname = select(1, ...)

function thread_async_download_available_versions(server_url, timeout, max_size)
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
  end

  love.thread.getChannel(fname):push(all_versions)
end

function thread_async_download_file(server_url, local_path)
  local body = http.request(server_url)
  love.filesystem.write(local_path, body)

  love.thread.getChannel(fname):push(true)
end

local ftable = { 
  download_available_versions= thread_async_download_available_versions,
  download_file= thread_async_download_file,

}

ftable[fname](select(2, ...))
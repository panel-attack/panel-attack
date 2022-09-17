require("class")
local logger = require("logger")

-- Utility methods for drawing
FileUtil =
  class(
  function(self)
    
  end
)

function FileUtil.getFilteredDirectoryItems(path)
  local results = {}

  local directoryList = love.filesystem.getDirectoryItems(path)
  for i = 1, #directoryList do
    local file = directoryList[i]
    
    local startOfFile = string.sub(file, 0, string.len(prefix_of_ignored_dirs))
   -- macOS sometimes puts these files in folders without warning, they are never useful for PA, so filter them.
    if startOfFile ~= prefix_of_ignored_dirs and file ~= ".DS_Store" then
      results[#results+1] = file
    end
  end

  return results
end
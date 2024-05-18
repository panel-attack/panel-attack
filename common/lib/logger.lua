local os = require("os")
local socket
if love then
  -- love comes with luasocket
  socket = require("socket")
else
  socket = require("common.lib.socket")
end

local logger = {
  messages = {}
}

local TRACE = 0 -- Log something that is very detailed verbose debug logging
local DEBUG = 1 -- Log something that is only useful when debugging
local INFO = 2 -- Log something that is useful in most normal conditions
local WARN = 3 -- Log something that could be a problem
local ERROR = 4 -- Log something that definitely is a problem

local LOG_LEVEL = DEBUG

-- See comments above about when you should use each logging level
function logger.trace(msg)
  if LOG_LEVEL <= TRACE then
    direct_log("TRACE", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.debug(msg)
  if LOG_LEVEL <= DEBUG then
    direct_log("DEBUG", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.info(msg)
  if LOG_LEVEL <= INFO then
    direct_log(" INFO", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.warn(msg)
  if LOG_LEVEL <= WARN then
    direct_log(" WARN", msg);
  end
end

-- See comments above about when you should use each logging level
function logger.error(msg)
  if LOG_LEVEL <= ERROR then
    direct_log("ERROR", msg);
  end
end

function direct_log(prefix, msg)
  local socket_millis = math.floor(socket.gettime()%1 * 1000)

  -- Lua date format strings reference: https://www.lua.org/pil/22.1.html
  -- %x - Date
  -- %X - Time
  local message = string.format("%s.%03d %s:%s", os.date("%x %X"), socket_millis, prefix, msg)
  logger.messages[#logger.messages+1] = message
  print(message)
  -- note the space in the string below is on purpose
  if SERVER_MODE == nil and (prefix == "ERROR" or prefix == " WARN") then
    love.filesystem.append("warnings.txt", message .. "\n")
  end
end

return logger;

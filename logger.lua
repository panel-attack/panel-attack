local os = require("os")
local socket = require("socket")

local logger = {}

local TRACE = 0
local DEBUG = 1
local INFO = 2
local WARN = 3
local ERROR = 4

local LOG_LEVEL = WARN

function logger.trace(msg)
    if LOG_LEVEL <= TRACE then
        direct_log("TRACE", msg);
    end
end

function logger.debug(msg)
    if LOG_LEVEL <= DEBUG then
        direct_log("DEBUG", msg);
    end
end

function logger.info(msg)
    if LOG_LEVEL <= INFO then
        direct_log(" INFO", msg);
    end
end

function logger.warn(msg)
    if LOG_LEVEL <= WARN then
        direct_log(" WARN", msg);
    end
end

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
    local message = os.date("%x %X") .. "." .. socket_millis .. " " .. prefix .. ": " .. msg
    print(message)
    if prefix == "ERROR" or prefix == "WARN" then
      love.filesystem.append("warnings.txt", message .. "\n")
    end
end

return logger;

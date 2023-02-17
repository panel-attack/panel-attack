local logger = require("logger")
local utf8 = require("utf8Additions")

local NetworkProtocol = {}

local char = string.char
local byte = string.byte
local floor = math.floor



local serverMessageTypeToLength = {E = 4, I = 2, L = 2, G = 1, H = 1, N = 1, U = 2}
local clientMessageTypeToLength = {E = 4, F = 4, H = 4, I = 2, L = 2, U = 2}

NetworkProtocol.serverMessageTypes = { opponentInput = {"U", 2} }

local messageEndMarker = "←J←"

-- Creates a JSON message string
function NetworkProtocol.markedMessageForTypeAndBody(type, body)
  return type .. body .. messageEndMarker
end

-- Returns the next message in the queue, or nil if none / error
function NetworkProtocol.getMessageFromString(messageBuffer, isServerMessage)
  assert(isServerMessage ~= nil)

  if string.len(messageBuffer) == 0 then
    return nil
  end

  local type = string.sub(messageBuffer, 1, 1)
  if type == "J" or type == "I" or type == "U" then
    local finishStart, finishEnd = string.find(messageBuffer, messageEndMarker)
    if finishStart ~= nil then
      local message = string.sub(messageBuffer, 2, finishStart-1)
      local remainingBuffer = string.sub(messageBuffer, finishEnd+1)
      return type, message, remainingBuffer
    else
      logger.trace("not all data recieved, waiting")
      return nil
    end
  else
    local len = 0
    if isServerMessage then
      len = serverMessageTypeToLength[type]
    else
      len = clientMessageTypeToLength[type]
    end

    if len == nil or len > string.len(messageBuffer) then
      logger.trace("not all data recieved, waiting")
      return nil
    end

    local message = string.sub(messageBuffer, 2, len)
    local remainingBuffer = string.sub(messageBuffer, len+1)
    return type, message, remainingBuffer
  end
end

function NetworkProtocol.J(lengthString)
  -- local codePointResult = nil
  -- for _, codePoint in utf8.codes(lengthString) do
  --   codePointResult = codePoint
  --   break
  -- end
  local result = byte(string.sub(lengthString, 1, 1)) * 65536 + byte(string.sub(lengthString, 2, 2)) * 256 + byte(string.sub(lengthString, 3, 3))
  --local result = codePointResult - START_LATIN_NUMBER
  return result
end

function NetworkProtocol.JSONlengthFromString(lengthString)
  -- local codePointResult = nil
  -- for _, codePoint in utf8.codes(lengthString) do
  --   codePointResult = codePoint
  --   break
  -- end
  local result = byte(string.sub(lengthString, 1, 1)) * 65536 + byte(string.sub(lengthString, 2, 2)) * 256 + byte(string.sub(lengthString, 3, 3))
  --local result = codePointResult - START_LATIN_NUMBER
  return result
end

function NetworkProtocol.JSONStringFromLength(length)
  local result = char(floor(length / 65536)) .. char(floor((length / 256) % 256)) .. char(length % 256)
  --local result = utf8.char(length + START_LATIN_NUMBER)
  return result
end

return NetworkProtocol
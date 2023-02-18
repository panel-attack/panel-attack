local logger = require("logger")
local utf8 = require("utf8Additions")

local NetworkProtocol = {}

local messageEndMarker = "←J←"

-- All the types sent by clients and servers
-- Prefix is what is put at the front of the message
-- Then size data follows in normal single byte sequence.
-- if size is nil then a variable utf8 byte sequence follows terminated by messageEndMarker
NetworkProtocol.clientMessageTypes = { 
  jsonMessage = {prefix="J", size=nil}, -- Generic JSON message sent from the client
  playerInput = {prefix="I", size=nil}, -- Player input (touch or controller) from the client
  acknowledgedPing = {prefix="E", size=1}, -- Respond back from the servers ping to confirm we are still connected
  versionCheck = {prefix="H", size=4} -- Sent on initial connection with the VERSION number to confirm client and server agree
}
NetworkProtocol.clientPrefixToMessageType = {}
for _, value in pairs(NetworkProtocol.clientMessageTypes) do
  NetworkProtocol.clientPrefixToMessageType[value.prefix] = value
end

NetworkProtocol.serverMessageTypes = { 
  jsonMessage = {prefix="J", size=nil}, -- Generic JSON message sent from the server
  opponentInput = {prefix="I", size=nil}, -- Player input (touch or controller) sent to the client about it's opponent
  secondOpponentInput = {prefix="U", size=nil}, -- Player input (touch or controller) sent to the client for player two if spectating
  versionCorrect = {prefix="H", size=1}, -- Sent to the client if the VERSION they sent is allowed
  versionWrong = {prefix="N", size=1}, -- Sent to the client if the VERSION they sent is not allowed
  ping = {prefix="E", size=1} -- Sent to the client to confirm they are still connected
}
NetworkProtocol.serverPrefixToMessageType = {}
for _, value in pairs(NetworkProtocol.serverMessageTypes) do
  NetworkProtocol.serverPrefixToMessageType[value.prefix] = value
end

-- Creates a UTF8 message string with the type at the beginning and the end marker at the end
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

  local messageType = nil
  if isServerMessage then
    messageType = NetworkProtocol.serverPrefixToMessageType[type]
  else
    messageType = NetworkProtocol.clientPrefixToMessageType[type]
  end

  if messageType and messageType.size == nil then
    local finishStart, finishEnd = string.find(messageBuffer, messageEndMarker)
    if finishStart ~= nil then
      local message = string.sub(messageBuffer, 2, finishStart-1)
      local remainingBuffer = string.sub(messageBuffer, finishEnd+1)
      return type, message, remainingBuffer
    else
      logger.trace("not all UTF8 data recieved, waiting: " .. messageBuffer)
      return nil
    end
  else
    if messageType == nil then
      logger.error("Got invalid message type: " .. type)
      return nil
    end
    local len = messageType.size
    if len > string.len(messageBuffer) then
      logger.trace("not all base message for type " .. type .. ", waiting: " .. messageBuffer)
      return nil
    end

    local message = string.sub(messageBuffer, 2, len)
    local remainingBuffer = string.sub(messageBuffer, len+1)
    return type, message, remainingBuffer
  end
end

return NetworkProtocol
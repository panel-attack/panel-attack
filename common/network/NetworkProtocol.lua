local logger = require("common.lib.logger")

local NetworkProtocol = {}

-- Version 001 was super legacy
-- Version 002 we supported unicode JSON
-- Version 003 we updated login requirements and started sending the network version
NetworkProtocol.NETWORK_VERSION = "003"

local messageEndMarker = "←J←"

-- All the types sent by clients and servers
-- Prefix is what is put at the front of the message
-- Then size data follows in normal single byte sequence.
-- if size is nil then a variable utf8 byte sequence follows terminated by messageEndMarker
NetworkProtocol.clientMessageTypes = { 
  jsonMessage = {prefix="J", size=nil}, -- Generic JSON message sent from the client
  playerInput = {prefix="I", size=nil}, -- Player input (touch or controller) from the client
  acknowledgedPing = {prefix="E", size=1}, -- Respond back from the servers ping to confirm we are still connected
  versionCheck = {prefix="H", size=4} -- Sent on initial connection with the NETWORK_VERSION number to confirm client and server agree
}
NetworkProtocol.clientPrefixToMessageType = {}
for _, value in pairs(NetworkProtocol.clientMessageTypes) do
  NetworkProtocol.clientPrefixToMessageType[value.prefix] = value
end

NetworkProtocol.serverMessageTypes = { 
  jsonMessage = {prefix="J", size=nil}, -- Generic JSON message sent from the server
  opponentInput = {prefix="I", size=nil}, -- Player input (touch or controller) sent to the client about it's opponent
  secondOpponentInput = {prefix="U", size=nil}, -- Player input (touch or controller) sent to the client for player two if spectating
  versionCorrect = {prefix="H", size=1}, -- Sent to the client if the NETWORK_VERSION they sent is allowed
  versionWrong = {prefix="N", size=1}, -- Sent to the client if the NETWORK_VERSION they sent is not allowed
  ping = {prefix="E", size=1} -- Sent to the client to confirm they are still connected
}
NetworkProtocol.serverPrefixToMessageType = {}
for _, value in pairs(NetworkProtocol.serverMessageTypes) do
  NetworkProtocol.serverPrefixToMessageType[value.prefix] = value
end

-- Returns if the message type prefix is one of the ones that happens all the time (ping or player input) 
-- thus may be too verbose to print all the time in debug
function NetworkProtocol.isMessageTypeVerbose(type)
  if type == NetworkProtocol.serverMessageTypes.ping.prefix or 
    type == NetworkProtocol.serverMessageTypes.opponentInput.prefix or 
    type == NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix then
    return true
  end
  return false
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
      logger.trace("not all UTF8 data received, waiting: " .. messageBuffer)
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
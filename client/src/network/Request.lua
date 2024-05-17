local class = require("class")
local Response = require("network.Response")
local NetworkProtocol = require("network.NetworkProtocol")
local consts = require("consts")
local logger = require("logger")

local Request = class(function(self, tcpClient, messageType, messageText, responseTypes)
  self.tcpClient = tcpClient
  self.messageType = messageType
  self.messageText = messageText
  self.responseTypes = responseTypes
end)

function Request.toJsonMessage(messageText)
  local jsonResult = nil
  local status, errorString = pcall(
    function()
      jsonResult = json.encode(messageText)
    end
  )
  if status == false and error and type(errorString) == "string" then
      error("Crash encoding JSON: " .. table_to_string(messageText) .. " with error: " .. errorString)
  end
  return NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.clientMessageTypes.jsonMessage.prefix, jsonResult)
end

-- sends the request, updates awaitingResponse status field
function Request:send()
  local message
  if self.messageType.prefix == "J" then
    message = Request.toJsonMessage(self.messageText)
  elseif self.messageType.prefix == "H" then
    message = NetworkProtocol.clientMessageTypes.versionCheck.prefix .. NetworkProtocol.NETWORK_VERSION
  else
    error("Trying to send a message with message type " .. table_to_string(self.messageType) .. " that has no interaction defined")
  end
  logger.debug("Sending message: " .. message)
  self.tcpClient:send(message)

  -- in network, all responses from the server get mapped into "json" responses
  if self.responseTypes and #self.responseTypes > 0 then
    return Response(self.responseTypes)
  else
    return nil
  end
end

return Request
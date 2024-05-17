local logger = require("common.lib.logger")
local socket = require("socket")
local NetworkProtocol = require("common.network.NetworkProtocol")
local ClientMessages = require("client.src.network.ClientProtocol")
require("client.src.TimeQueue")
local class = require("common.lib.class")
local Request = require("client.src.network.Request")

local TcpClient = class(function(tcpClient)
  -- holds data fragments
  tcpClient.data = ""
  --connectionUptime counts "E" messages, not seconds
  tcpClient.connectionUptime = 0
  tcpClient.receivedMessageQueue = ServerQueue()
  tcpClient.delayedProcessing = false
  math.randomseed(os.time())
  for i = 1, 4 do
    math.random()
  end
end)

-- setup the network connection on the given IP and port
function TcpClient:connectToServer(ip, port)
  self.ip = ip
  self.port = port or 49569
  self.socket = socket.tcp()
  self.socket:settimeout(7)
  local result, err = self.socket:connect(self.ip, self.port)
  if not result then
    return err == "already connected"
  end
  self.socket:setoption("tcp-nodelay", true)
  self.socket:settimeout(0)
  return true
end

function TcpClient:isConnected()
  return self.socket and self.socket:getpeername() ~= nil
end

-- Appends all data from the socket to TcpClient.data
-- returns false if something went wrong
function TcpClient:readSocket()
  if not self.socket then
    return
  end
  -- receive(*a) means to receive data until the connection closes!
  -- combined with a timeout of 0 means we're streaming data because the receival always gets interrupted before the connection closes
  local data, error, partialData = self.socket:receive("*a")
  -- complete data is returned to data (but it should always be empty)
  -- error lists the reason why the data receival was interrupted (should normally be "timeout")
  -- all partial data lands as data fragments in the partialdata variable
  if error == "timeout" then
    -- "timeout" is an expected scenario, the connection is still active
    -- in case of an error, data is always nil so there is no danger of overwriting
    data = partialData
  end
  if data and data:len() > 0 then
    -- append data to our unprocessed data so far
    self.data = self.data .. data
  end
  if error == "closed" then
    logger.warn("the connection was closed while trying to stream data")
    -- technically we might want to discard our current data but it should already recover on its own
    return false
  end
  -- When done, return true, so we know things went okay
  return true
end

function TcpClient:resetNetwork()
  self.connectionUptime = 0
  self.ip = ""
  self.port = 0
  if self.socket then
    self.socket:close()
  end
  self.socket = nil
end

function TcpClient:sendMessage(stringData)
  if self:isConnected() then
    local fullMessageSent, error, partialBytesSent = self.socket:send(stringData)
    if fullMessageSent then
      --logger.trace("json bytes sent in one go: " .. tostring(fullMessageSent))
      return true
    else
      logger.error("Error sending network message: " .. (error or "") .. " only sent " .. (partialBytesSent or "0") .. "bytes")
      return false
    end
  else
    return false
  end
end

function TcpClient:updateNetwork(dt)
  if self.delayedProcessing then
    self.sendNetworkQueue:update(dt)
    local data = self.sendNetworkQueue:popIfReady()
    while data do
      self:sendMessage(data)
      data = self.sendNetworkQueue:popIfReady()
    end

    self.receiveNetworkQueue:update(dt)
    data = self.receiveNetworkQueue:popIfReady()
    while data do
      self:queueMessage(data[1], data[2])
      data = self.receiveNetworkQueue:popIfReady()
    end
  end
end

local sendMinLag = 0
local sendMaxLag = 0
local receiveMinLag = 3
local receiveMaxLag = receiveMinLag

-- send the given message through
function TcpClient:send(stringData)
  if not self.socket then
    return false
  end
  if self.delayedProcessing then
    local lagSeconds = (math.random() * (sendMaxLag - sendMinLag)) + sendMinLag
    self.sendNetworkQueue:push(stringData, lagSeconds)
    -- bold assumption that the later send will work
    return true
  else
    return self:sendMessage(stringData)
  end
end

--activate delayedProcessing, used for testing laggy sends and receives
function TcpClient:activateDelayedProcessing()
  self.sendNetworkQueue = TimeQueue()
  self.receiveNetworkQueue = TimeQueue()
  self.delayedProcessing = true
end

-- deactivate delayedProcessing
function TcpClient:deactivateDelayedProcessing()
  self.sendNetworkQueue:clear()
  self.receiveNetworkQueue:clear()
  self:updateNetwork(0)
  self.delayedProcessing = false
end

-- Adds the message to the network queue or processes it immediately in a couple cases
function TcpClient:queueMessage(type, data)
  if type == NetworkProtocol.serverMessageTypes.opponentInput.prefix or type == NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix then
    local dataMessage = {}
    dataMessage[type] = data
    logger.trace("Queuing: " .. type .. " with data:" .. data)
    self.receivedMessageQueue:push(dataMessage)
  elseif type == NetworkProtocol.serverMessageTypes.versionCorrect.prefix then
    -- make responses to client H messages processable by treating them like a json response
    self.receivedMessageQueue:push({versionCompatible = true})
  elseif type == NetworkProtocol.serverMessageTypes.versionWrong.prefix then
    -- make responses to client H messages processable by treating them like a json response
    self.receivedMessageQueue:push({versionCompatible = false})
  elseif type == NetworkProtocol.serverMessageTypes.ping.prefix then
    self:send(NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix)
    self.connectionUptime = self.connectionUptime + 1
  elseif type == NetworkProtocol.serverMessageTypes.jsonMessage.prefix then
    local current_message = json.decode(data)
    if not current_message then
      error(loc("nt_msg_err", (data or "nil")))
    end
    logger.trace("Queuing JSON: " .. dump(current_message))
    self.receivedMessageQueue:push(current_message)
  end
end

function TcpClient:dropOldInputMessages()
  while true do
    local message = self.receivedMessageQueue:top()
    if not message then
      break
    end

    if not message[NetworkProtocol.serverMessageTypes.opponentInput.prefix] and not message[NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix] then
      break -- Found a non user input message. Stop. Future data is for next game
    else
      self.receivedMessageQueue:pop() -- old data, drop it
    end
  end
end

function TcpClient:sendErrorReport(errorData)
  self:sendRequest(ClientMessages.sendErrorReport(errorData))
end

-- Processes messages that came in from the server
-- Returns false if the connection is broken.
function TcpClient:processIncomingMessages()
  if not self:readSocket() then
    -- Something went wrong while receiving data.
    -- Bail out and return.
    return false
  end
  while true do
    local type, message, remaining = NetworkProtocol.getMessageFromString(self.data, true)
    if type then
      if self.delayedProcessing then
        -- in stoner mode, don't directly send the message but add it to a timed queue with a delay instead
        local lagSeconds = (math.random() * (receiveMaxLag - receiveMinLag)) + receiveMinLag
        self.receiveNetworkQueue:push({type, message}, lagSeconds)
      else
        self:queueMessage(type, message)
      end
      self.data = remaining
    else
      break
    end
  end
  -- Return true when finished successfully.
  return true
end

function TcpClient:sendRequest(requestData)
  local request = Request(self, requestData.messageType, requestData.messageText, requestData.responseTypes)
  return request:send()
end

return TcpClient
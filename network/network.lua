local consts = require("consts")
local logger = require("logger")
local input = require("inputManager")
local NetworkProtocol = require("network.NetworkProtocol")
local TouchDataEncoding = require("engine.TouchDataEncoding")
local ClientRequests = require("network.ClientProtocol")
require("TimeQueue")
local class = require("class")

local TcpClient = class(function(tcpClient)
  -- holds data fragments
  tcpClient.data = ""
  --connectionUptime counts "E" messages, not seconds
  tcpClient.connectionUptime = 0
  tcpClient.receivedMessageQueue = ServerQueue()
  tcpClient.sendNetworkQueue = TimeQueue()
  tcpClient.receiveNetworkQueue = TimeQueue()
end)

-- setup the network connection on the given IP and port
function TcpClient:connectToServer(ip, port)
  self.ip = ip
  self.port = port
  self.socket = socket.tcp()
  self.socket:settimeout(7)
  local result, err = self.socket:connect(ip, port or 49569)
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
function TcpClient:flushSocket()
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
    -- "timeout" is the expected scenario
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

local function processDataToSend(stringData)
  -- accessing the client in this way is a dirty workaround
  -- owed to the fact that TimeQueue were written under the assumption that the socket was global
  if GAME.tcpClient:isConnected() then
    local fullMessageSent, error, partialBytesSent = GAME.tcpClient.socket:send(stringData)
    if fullMessageSent then
      --logger.trace("json bytes sent in one go: " .. tostring(fullMessageSent))
    else
      logger.error("Error sending network message: " .. (error or "") .. " only sent " .. (partialBytesSent or "0") .. "bytes")
    end
  end
end

local function processDataToReceive(data)
  -- accessing the client in this way is a dirty workaround
  -- owed to the fact that TimeQueue were written under the assumption that the socket was global
  GAME.tcpClient:queueMessage(data[1], data[2])
end

function TcpClient:updateNetwork(dt)
  self:update(dt, processDataToSend)
  self:update(dt, processDataToReceive)
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
  if not STONER_MODE then
    self:processDataToSend(stringData)
  else
    local lagSeconds = (math.random() * (sendMaxLag - sendMinLag)) + sendMinLag
    self.sendNetworkQueue:push(stringData, lagSeconds)
  end
  return true
end

-- Cleans up "stonermode" used for testing laggy sends
function TcpClient:undo_stonermode()
  self.sendNetworkQueue:clearAndProcess(self.processDataToSend)
  self.receiveNetworkQueue:clearAndProcess(self.processDataToReceive)
  STONER_MODE = false
end

-- Adds the message to the network queue or processes it immediately in a couple cases
function TcpClient:queueMessage(type, data)
  if type == NetworkProtocol.serverMessageTypes.opponentInput.prefix or type == NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix then
    local dataMessage = {}
    dataMessage[type] = data
    logger.debug("Queuing: " .. type .. " with data:" .. data)
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
    logger.debug("Queuing JSON: " .. dump(current_message))
    self.receivedMessageQueue:push(current_message)
  end
end

-- Drops all "game data" messages prior to the next server "J" message.
function TcpClient:drop_old_data_messages()
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

-- Process all game data messages in the queue
function process_all_data_messages()
  local messages = GAME.tcpClient.receivedMessageQueue:pop_all_with(NetworkProtocol.serverMessageTypes.opponentInput.prefix, NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix)
  for _, msg in ipairs(messages) do
    for type, data in pairs(msg) do
      logger.debug("Processing: " .. type .. " with data:" .. data)
      process_data_message(type, data)
    end
  end
end

-- Handler for the various "game data" message types
function process_data_message(type, data)
  if type == NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix then
    GAME.battleRoom.match.P1:receiveConfirmedInput(data)
  elseif type == NetworkProtocol.serverMessageTypes.opponentInput.prefix then
    GAME.battleRoom.match.P2:receiveConfirmedInput(data)
  end
end

function TcpClient:sendErrorReport(errorData)
  ClientRequests.sendErrorReport(errorData)
end

-- Processes messages that came in from the server
-- Returns false if the connection is broken.
function TcpClient:processIncomingMessages()
  if not self:flushSocket() then
    -- Something went wrong while receiving data.
    -- Bail out and return.
    return false
  end
  while true do
    local type, message, remaining = NetworkProtocol.getMessageFromString(self.data, true)
    if type then
      if not STONER_MODE then
        self:queueMessage(type, message)
      else
        local lagSeconds = (math.random() * (receiveMaxLag - receiveMinLag)) + receiveMinLag
        self.receiveNetworkQueue:push({type, message}, lagSeconds)
      end
      self.data = remaining
    else
      break
    end
  end
  -- Return true when finished successfully.
  return true
end

function Stack.handle_input_taunt(self)

  if input.isDown["TauntUp"] and self:can_taunt() and #characters[self.character].sounds.taunt_up > 0 then
    self.taunt_up = math.random(#characters[self.character].sounds.taunt_up)
    if GAME.tcpClient:isConnected() then
      ClientRequests.sendTaunt("up", self.taunt_up)
    end
  elseif input.isDown["TauntDown"] and self:can_taunt() and #characters[self.character].sounds.taunt_down > 0 then
    self.taunt_down = math.random(#characters[self.character].sounds.taunt_down)
    if GAME.tcpClient:isConnected() then
      ClientRequests.sendTaunt("down", self.taunt_down)
    end
  end
end

local touchIdleInput = TouchDataEncoding.touchDataToLatinString(false, 0, 0, 6)
function Stack.idleInput(self) 
  return (self.inputMethod == "touch" and touchIdleInput) or base64encode[1]
end

function Stack.send_controls(self)
  if self.is_local and GAME.tcpClient:isConnected() and #self.confirmedInput > 0 and self.opponentStack and #self.opponentStack.confirmedInput == 0 then
    -- Send 1 frame at clock time 0 then wait till we get our first input from the other player.
    -- This will cause a player that got the start message earlierer than the other player to wait for the other player just once.
    -- print("self.confirmedInput="..(self.confirmedInput or "nil"))
    -- print("self.input_buffer="..(self.input_buffer or "nil"))
    -- print("send_controls returned immediately")
    return
  end

  local playerNumber = self.which
  local to_send
  if self.inputMethod == "controller" then
    to_send = base64encode[
      ((input.isDown["Raise1"] or input.isDown["Raise2"] or input.isPressed["Raise1"] or input.isPressed["Raise2"]) and 32 or 0) + 
      ((input.isDown["Swap1"] or input.isDown["Swap2"]) and 16 or 0) + 
      ((input.isDown["Up"] or input.isPressed["Up"]) and 8 or 0) + 
      ((input.isDown["Down"] or input.isPressed["Down"]) and 4 or 0) + 
      ((input.isDown["Left"] or input.isPressed["Left"]) and 2 or 0) + 
      ((input.isDown["Right"] or input.isPressed["Right"]) and 1 or 0) + 1
    ]
  elseif self.inputMethod == "touch" then
    to_send = self.touchInputController:encodedCharacterForCurrentTouchInput()
  end
  if GAME.tcpClient:isConnected() then
    local message = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.clientMessageTypes.playerInput.prefix, to_send)
    GAME.tcpClient:send(message)
  end

  self:handle_input_taunt()

  self:receiveConfirmedInput(to_send)
end

return TcpClient
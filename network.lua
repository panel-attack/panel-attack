local consts = require("consts")
local logger = require("logger")
local NetworkProtocol = require("NetworkProtocol")
local TouchDataEncoding = require("engine.TouchDataEncoding")
require("TimeQueue")

-- TODO: Move this all into a proper class

local TCP_sock = nil

-- Expected length for each message type
local leftovers = "" -- Everything currently in the data queue

function network_connected()
  return TCP_sock ~= nil
end

-- Grabs data from the socket
-- returns false if the socket closed
function readSocket()
  if not TCP_sock then
    return
  end

  local data, error, partialData = TCP_sock:receive("*a")
  -- "timeout" is a common "error" that just means there is currently nothing to read but the connection is still active
  if error then
    data = partialData
  end
  if data and data:len() > 0 then
    leftovers = leftovers .. data
  end
  if error == "closed" then
    return false
  end
  return true
end

function resetNetwork()
  connection_up_time = 0
  GAME.connected_server_ip = ""
  GAME.connected_network_port = nil
  match_type = ""
  if TCP_sock then
    TCP_sock:close()
  end
  TCP_sock = nil
end

function processDataToSend(stringData) 
  if TCP_sock then
    local fullMessageSent, error, partialBytesSent = TCP_sock:send(stringData)
    if fullMessageSent then
      --logger.trace("json bytes sent in one go: " .. tostring(fullMessageSent))
    else
      logger.error("Error sending network message: " .. (error or "") .. " only sent " .. (partialBytesSent or "0") .. "bytes")
    end
  end
end

function processDataToReceive(data) 
  queue_message(data[1], data[2])
end

function updateNetwork(dt)
  GAME.sendNetworkQueue:update(dt, processDataToSend)
  GAME.receiveNetworkQueue:update(dt, processDataToReceive)
end

local sendMinLag = 0
local sendMaxLag = 0
local receiveMinLag = 3
local receiveMaxLag = receiveMinLag

-- send the given message through
function net_send(stringData)
  if not TCP_sock then
    return false
  end
  if not STONER_MODE then
    processDataToSend(stringData)
  else
    local lagSeconds = (math.random() * (sendMaxLag - sendMinLag)) + sendMinLag
    GAME.sendNetworkQueue:push(stringData, lagSeconds)
  end
  return true
end

-- Send a json message with the "J" type
function json_send(obj)
  local jsonResult = nil
  local status, errorString = pcall(
    function()
      jsonResult = json.encode(obj)
    end
  )
  if status == false and error and type(errorString) == "string" then
      error("Crash sending JSON: " .. table_to_string(obj) .. " with error: " .. errorString)
  end
  local message = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.clientMessageTypes.jsonMessage.prefix, jsonResult)
  return net_send(message)
end

-- Cleans up "stonermode" used for testing laggy sends
function undo_stonermode()
  GAME.sendNetworkQueue:clearAndProcess(processDataToSend)
  GAME.receiveNetworkQueue:clearAndProcess(processDataToReceive)
  STONER_MODE = false
end

local got_H = false

-- list of spectators
function spectator_list_string(list)
  local str = ""
  for k, v in ipairs(list) do
    str = str .. v
    if k < #list then
      str = str .. "\n"
    end
  end
  if str ~= "" then
    str = loc("pl_spectators") .. "\n" .. str
  end
  return str
end

-- Adds the message to the network queue or processes it immediately in a couple cases
function queue_message(type, data)
  if type == NetworkProtocol.serverMessageTypes.opponentInput.prefix or type == NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix then
    local dataMessage = {}
    dataMessage[type] = data
    logger.debug("Queuing: " .. type .. " with data:" .. data)
    server_queue:push(dataMessage)
  elseif type == NetworkProtocol.serverMessageTypes.versionCorrect.prefix then
    got_H = true
  elseif type == NetworkProtocol.serverMessageTypes.versionWrong.prefix then
    error(loc("nt_ver_err"))
  elseif type == NetworkProtocol.serverMessageTypes.ping.prefix then
    net_send(NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix)
    connection_up_time = connection_up_time + 1 --connection_up_time counts "E" messages, not seconds
  elseif type == NetworkProtocol.serverMessageTypes.jsonMessage.prefix then
    local current_message = json.decode(data)
    this_frame_messages[#this_frame_messages + 1] = current_message
    if not current_message then
      error(loc("nt_msg_err", (data or "nil")))
    end
    if current_message.spectators then
      spectators_string = spectator_list_string(current_message.spectators)
      return
    end
    logger.debug("Queuing JSON: " .. dump(current_message))
    server_queue:push(current_message)
  end
end

-- Drops all "game data" messages prior to the next server "J" message.
function drop_old_data_messages()
  while true do
    local message = server_queue:top()
    if not message then
      break
    end

    if not message[NetworkProtocol.serverMessageTypes.opponentInput.prefix] and not message[NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix] then
      break -- Found a non user input message. Stop. Future data is for next game
    else
      server_queue:pop() -- old data, drop it
    end
  end
end

-- Process all game data messages in the queue
function process_all_data_messages()
  local messages = server_queue:pop_all_with(NetworkProtocol.serverMessageTypes.opponentInput.prefix, NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix)
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
    P1:receiveConfirmedInput(data)
  elseif type == NetworkProtocol.serverMessageTypes.opponentInput.prefix then
    P2:receiveConfirmedInput(data)
  end
end

-- setup the network connection on the given IP and port
function network_init(ip, network_port)
  TCP_sock = socket.tcp()
  TCP_sock:settimeout(7)
  if not TCP_sock:connect(ip, network_port or 49569) then
    return false
  end
  TCP_sock:setoption("tcp-nodelay", true)
  TCP_sock:settimeout(0)
  got_H = false
  net_send(NetworkProtocol.clientMessageTypes.versionCheck.prefix .. VERSION)
  return true
end

function sendLoginRequest()
  assert(config.name and config.save_replays_publicly)

  --attempt login
  local my_user_id = read_user_id_file(GAME.connected_server_ip)
  if not my_user_id then
    my_user_id = "need a new user id"
  end
  if CUSTOM_USER_ID then
    my_user_id = CUSTOM_USER_ID
  end

  local sent_json = {
    login_request = true,
    user_id = my_user_id,
    name = config.name,
    level = config.level,
    inputMethod = config.inputMethod or "controller",
    panels_dir = config.panels,
    character = config.character,
    character_is_random = ((config.character == random_character_special_value or characters[config.character]:is_bundle()) and config.character or nil),
    stage = config.stage,
    ranked = config.ranked,
    stage_is_random = ((config.stage == random_stage_special_value or stages[config.stage]:is_bundle()) and config.stage or nil),
    save_replays_publicly = config.save_replays_publicly
  }
  sent_json.character_display_name = sent_json.character_is_random and "" or characters[config.character].display_name
  json_send(sent_json)
end

function send_error_report(errorData)
  TCP_sock = socket.tcp()
  TCP_sock:settimeout(7)
  if not TCP_sock:connect(consts.SERVER_LOCATION, 59569) then
    return false
  end
  TCP_sock:settimeout(0)
  local errorFull = { error_report = errorData }
  json_send(errorFull)
  resetNetwork()
  return true
end

function connection_is_ready()
  return got_H
end

-- Processes messages that came in from the server
-- Returns false if the connection is broken.
function do_messages()
  if not readSocket() then
    -- Something went wrong while receiving data.
    -- Bail out and return.
    return false
  end
  while true do
    local type, message, remaining = NetworkProtocol.getMessageFromString(leftovers, true)
    if type then
      if not STONER_MODE then
        queue_message(type, message)
      else
        local lagSeconds = (math.random() * (receiveMaxLag - receiveMinLag)) + receiveMinLag
        GAME.receiveNetworkQueue:push({type, message}, lagSeconds)
      end
      leftovers = remaining
    else
      break
    end
  end
  -- Return true when finished successfully.
  return true
end

function request_game(opponentName)
  json_send({game_request = {sender = config.name, receiver = opponentName}})
end

function request_spectate(roomNr)
  json_send({spectate_request = {sender = config.name, roomNumber = roomNr}})
end

function Stack.handle_input_taunt(self)

  if player_taunt_up(self.which) and self:can_taunt() and #characters[self.character].sounds.taunt_up > 0 then
    self.taunt_up = math.random(#characters[self.character].sounds.taunt_up)
    if TCP_sock then
      json_send({taunt = true, type = "taunt_ups", index = self.taunt_up})
    end
  elseif player_taunt_down(self.which) and self:can_taunt() and #characters[self.character].sounds.taunt_down > 0 then
    self.taunt_down = math.random(#characters[self.character].sounds.taunt_down)
    if TCP_sock then
      json_send({taunt = true, type = "taunt_downs", index = self.taunt_down})
    end
  end
end

local touchIdleInput = TouchDataEncoding.touchDataToLatinString(false, 0, 0, 6)
function Stack.idleInput(self) 
  return (self.inputMethod == "touch" and touchIdleInput) or base64encode[1]
end

function Stack.send_controls(self)

  if self.is_local and TCP_sock and #self.confirmedInput > 0 and self.opponentStack and #self.opponentStack.confirmedInput == 0 then
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
    (player_raise(playerNumber) and 32 or 0) + 
    (player_swap(playerNumber) and 16 or 0) + 
    (player_up(playerNumber) and 8 or 0) + 
    (player_down(playerNumber) and 4 or 0) + 
    (player_left(playerNumber) and 2 or 0) + 
    (player_right(playerNumber) and 1 or 0) + 1
    ]
  elseif self.inputMethod == "touch" then
    to_send = self.touchInputController:encodedCharacterForCurrentTouchInput()
  end
  if TCP_sock then
    local message = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.clientMessageTypes.playerInput.prefix, to_send)
    net_send(message)
  end

  self:handle_input_taunt()

  self:receiveConfirmedInput(to_send)
end

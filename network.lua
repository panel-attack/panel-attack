local logger = require("logger")

local TCP_sock = nil

-- Expected length for each message type
local type_to_length = {G = 1, H = 1, N = 1, E = 4, P = 121, O = 121, I = 2, Q = 121, R = 121, L = 2, U = 2}
local leftovers = "" -- Everything currently in the data queue
local wait = coroutine.yield
local floor = math.floor
local char = string.char
local byte = string.byte

function network_connected()
  return TCP_sock ~= nil
end

-- Grabs data from the socket
-- returns false if something went wrong
function flush_socket()
  if not TCP_sock then
    return
  end
  local junk, err, data = TCP_sock:receive("*a")
  -- lol, if it returned successfully then that's bad!
  if not err then
    -- Return false, so we know things went badly
    return false
  end
  leftovers = leftovers .. data
  -- When done, return true, so we know things went okay
  return true
end

function resetNetwork()
  logged_in = 0
  connection_up_time = 0
  GAME.connected_server_ip = ""
  GAME.connected_network_port = nil
  current_server_supports_ranking = false
  match_type = ""
  if TCP_sock then
    TCP_sock:close()
  end
  TCP_sock = nil
end

-- Returns the next message in the queue, or nil if none / error
function get_message()
  if string.len(leftovers) == 0 then
    return nil
  end
  local len
  local type, gap = string.sub(leftovers, 1, 1), 0
  if type == "J" then
    if string.len(leftovers) >= 4 then
      len = byte(string.sub(leftovers, 2, 2)) * 65536 + byte(string.sub(leftovers, 3, 3)) * 256 + byte(string.sub(leftovers, 4, 4))
      --logger.trace("json message has length "..len)
      gap = 3
    else
      return nil
    end
  else
    len = type_to_length[type] - 1
  end
  if len + gap + 1 > string.len(leftovers) then
    return nil
  end
  local ret = string.sub(leftovers, 2 + gap, len + gap + 1)
  leftovers = string.sub(leftovers, len + gap + 2)
  return type, ret
end

local lag_q = Queue() -- only used for debugging
local lastSendTime = nil
local minLagSeconds = 0
local maxLagSeconds = 1
local lagIncrease = 1
local lagSeconds = minLagSeconds
local lagCount = 0

-- send the given message through
function net_send(...)
  if not TCP_sock then
    return false
  end
  if not STONER_MODE then
    TCP_sock:send(...)
  else
    if lastSendTime == nil then
      lastSendTime = love.timer.getTime()
    end
    lag_q:push({...})
    local currentTime = love.timer.getTime()
    local timeDifference = currentTime - lastSendTime
    if timeDifference > lagSeconds then
      while lag_q:len() > 0 do
        TCP_sock:send(unpack(lag_q:pop()))
      end
      lagSeconds = (math.random() * (maxLagSeconds - minLagSeconds)) + minLagSeconds
      lagCount = lagCount + 1
      lagSeconds = lagSeconds + (lagIncrease * lagCount)
      lastSendTime = love.timer.getTime()
    end
  end
  return true
end

-- Send a json message with the "J" type
function json_send(obj)
  local json = json.encode(obj)
  local len = json:len()
  local prefix = "J" .. char(floor(len / 65536)) .. char(floor((len / 256) % 256)) .. char(len % 256)
  return net_send(prefix .. json)
end

-- Cleans up "stonermode" used for testing laggy sends
function undo_stonermode()
  while lag_q:len() ~= 0 do
    TCP_sock:send(unpack(lag_q:pop()))
  end
  lastSendTime = nil
  lagCount = 0
  lagSeconds = minLagSeconds
  STONER_MODE = false
end

local got_H = false

-- Logs the network message if needed
function printNetworkMessageForType(type)
  local result = false
  if type ~= "I" and type ~= "U" then
    result = true
  end
  return result
end

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
  if type == "P" or type == "O" or type == "U" or type == "I" or type == "Q" or type == "R" then
    local dataMessage = {}
    dataMessage[type] = data
    if printNetworkMessageForType(type) then
      --logger.debug("Queuing: " .. type .. " with data:" .. data)
    end
    server_queue:push(dataMessage)
  elseif type == "L" then
    error(loc("nt_ver_err"))
  elseif type == "H" then
    got_H = true
  elseif type == "N" then
    error(loc("nt_ver_err"))
  elseif type == "E" then
    net_send("F" .. data)
    connection_up_time = connection_up_time + 1 --connection_up_time counts "E" messages, not seconds
  elseif type == "J" then
    local current_message = json.decode(data)
    this_frame_messages[#this_frame_messages + 1] = current_message
    if not current_message then
      error(loc("nt_msg_err", (data or "nil")))
    end
    if current_message.spectators then
      spectator_list = current_message.spectators
      spectators_string = spectator_list_string(current_message.spectators)
      return
    end
    if printNetworkMessageForType(type) then
      --logger.debug("Queuing: " .. type .. " with data:" .. dump(current_message))
    end
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

    if not message["P"] and not message["O"] and not message["U"] and not message["I"] and not message["Q"] and not message["R"] then
      break -- Found a "J" message. Stop. Future data is for next game
    else
      server_queue:pop() -- old data, drop it
    end
  end
end

-- Process all game data messages in the queue
function process_all_data_messages()
  local messages = server_queue:pop_all_with("P", "O", "U", "I", "Q", "R")
  for _, msg in ipairs(messages) do
    for type, data in pairs(msg) do
      if printNetworkMessageForType(type) then
        logger.debug("Processing: " .. type .. " with data:" .. data)
      end
      process_data_message(type, data)
    end
  end
end

-- Handler for the various "game data" message types
function process_data_message(type, data)
  if type == "P" then
    
  elseif type == "O" then
    
  elseif type == "U" then
    P1:receiveConfirmedInput(data)
  elseif type == "I" then
    P2:receiveConfirmedInput(data)
  elseif type == "Q" then
    
  elseif type == "R" then
    
  end
end

-- setup the network connection on the given IP and port
function network_init(ip, network_port)
  TCP_sock = socket.tcp()
  TCP_sock:settimeout(7)
  if not TCP_sock:connect(ip, network_port or 49569) then --for official server
    --if not TCP_sock:connect(ip,59569) then --for beta server
    --error(loc("nt_conn_timeout"))
    return false
  end
  TCP_sock:setoption("tcp-nodelay", true)
  TCP_sock:settimeout(0)
  got_H = false
  net_send("H" .. VERSION)
  assert(config.name and config.save_replays_publicly)
  local sent_json = {
    name = config.name,
    level = config.level,
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
  return true
end

function send_error_report(errorData)
  TCP_sock = socket.tcp()
  TCP_sock:settimeout(7)
  if not TCP_sock:connect("18.188.43.50", 59569) then --for official server
    return false
  end
  TCP_sock:settimeout(0)
  local errorFull = { error_report = errorData }
  json_send(errorFull)
  resetNetwork()
  return true
end

function connection_is_ready()
  return got_H and #this_frame_messages > 0
end

-- Processes messages that came in from the server
-- Returns false if the connection is broken.
function do_messages()
  if not flush_socket() then
    -- Something went wrong while receiving data.
    -- Bail out and return.
    return false
  end
  while true do
    local type, data = get_message()
    if type then
      queue_message(type, data)
    else
      break
    end
  end
  -- Return true when finished successfully.
  return true
end

function request_game(name)
  json_send({game_request = {sender = config.name, receiver = name}})
end

function request_spectate(roomNr)
  json_send({spectate_request = {sender = config.name, roomNumber = roomNr}})
end

function Stack.handle_input_taunt(self)

  if player_taunt_up(self.which) and self:can_taunt() and #characters[self.character].sounds.taunt_ups > 0 then
    self.taunt_up = math.random(#characters[self.character].sounds.taunt_ups)
    if TCP_sock then
      json_send({taunt = true, type = "taunt_ups", index = self.taunt_up})
    end
  elseif player_taunt_down(self.which) and self:can_taunt() and #characters[self.character].sounds.taunt_downs > 0 then
    self.taunt_down = math.random(#characters[self.character].sounds.taunt_downs)
    if TCP_sock then
      json_send({taunt = true, type = "taunt_downs", index = self.taunt_down})
    end
  end
end

function Stack.idleInput(self) 
  return base64encode[1]
end

function Stack.send_controls(self)

  if self.is_local and TCP_sock and string.len(self.confirmedInput) > 0 and self.garbage_target and string.len(self.garbage_target.confirmedInput) == 0 then
    -- Send 1 frame at CLOCK time 0 then wait till we get our first input from the other player.
    -- This will cause a player that got the start message earlierer than the other player to wait for the other player just once.
    return
  end

  local playerNumber = self.which
  local to_send = base64encode[
    (player_raise(playerNumber) and 32 or 0) + 
    (player_swap(playerNumber) and 16 or 0) + 
    (player_up(playerNumber) and 8 or 0) + 
    (player_down(playerNumber) and 4 or 0) + 
    (player_left(playerNumber) and 2 or 0) + 
    (player_right(playerNumber) and 1 or 0) + 1
    ]

  if TCP_sock then
    net_send("I" .. to_send)
  end

  self:handle_input_taunt()

  self:receiveConfirmedInput(to_send)
end

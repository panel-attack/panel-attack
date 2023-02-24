require("class")
local logger = require("logger")
local NetworkProtocol = require("NetworkProtocol")

local time = os.time
local utf8 = require("utf8Additions")
require("tests.utf8AdditionsTests")

-- Represents a connection to a specific player. Responsible for sending and receiving messages
Connection =
  class(
  function(s, socket, index, server)
    s.index = index
    s.socket = socket
    s.leftovers = ""
    s.state = "needs_name"
    s.room = nil
    s.last_read = time()
    s.player_number = 0 -- 0 if not a player in a room, 1 if player "a" in a room, 2 if player "b" in a room
    s.logged_in = false --whether connection has successfully logged into the rating system.
    s.user_id = nil
    s.wants_ranked_match = false
    s.server = server
    s.inputMethod = "controller"
  end
)

function Connection.login(self, user_id)
  --returns whether the login was successful
  --print("Connection.login was called!")
  self.user_id = user_id
  self.logged_in = false
  local IP_logging_in, port = self.socket:getpeername()
  logger.debug("New login attempt:  " .. IP_logging_in .. ":" .. port)
  if is_banned(IP_logging_in) then
    deny_login(self, "Awaiting ban timeout")
  elseif not self.name then
    deny_login(self, "Player has no name")
    logger.warn("Login failure: Player has no name")
  elseif not self.user_id then
    deny_login(self, "Client did not send a user_id in the login request")
  elseif self.user_id == "need a new user id" and self.name then

    if playerbase:nameTaken("", self.name) then
      self:send({choose_another_name = {reason = "That player name is already taken"}})
      logger.warn("Login failure: Player tried to create a new user with an already taken name: " .. self.name)
    else 
      logger.debug(self.name .. " needs a new user id!")
      local their_new_user_id
      while not their_new_user_id or playerbase.players[their_new_user_id] do
        their_new_user_id = generate_new_user_id()
      end
      playerbase:update(their_new_user_id, self.name)
      self:send({login_successful = true, new_user_id = their_new_user_id})
      self.user_id = their_new_user_id
      self.logged_in = true
      logger.info("New user: " .. self.name .. " was created")
      self.server.database:insertNewPlayer(their_new_user_id, self.name)
      self.server.database:insertPlayerELOChange(their_new_user_id, 0, 0)
    end
  elseif not playerbase.players[self.user_id] then
    deny_login(self, "The user_id provided was not found on this server")
    logger.warn("Login failure: " .. self.name .. " specified an invalid user_id")
  elseif playerbase.players[self.user_id] ~= self.name then
    if playerbase:nameTaken(self.user_id, self.name) then
      self:send({choose_another_name = {reason = "That player name is already taken"}})
      logger.warn("Login failure: Player (" .. self.user_id .. ") tried to use already taken name: " .. self.name)
    else 
      local the_old_name = playerbase.players[self.user_id]
      playerbase:update(self.user_id, self.name)
      if leaderboard.players[self.user_id] then
        leaderboard.players[self.user_id].user_name = self.name
      end
      self.logged_in = true
      self:send({login_successful = true, name_changed = true, old_name = the_old_name, new_name = self.name})
      self.server.database:updatePlayerUsername(self.user_id, self.name)
      logger.warn("Login successful and " .. self.user_id .. " changed name " .. the_old_name .. " to " .. self.name)
    end
  elseif playerbase.players[self.user_id] then
    self.logged_in = true
    self:send({login_successful = true})
  else
    deny_login(self, "Unknown")
  end

  if self.logged_in then
    leaderboard:update_timestamp(user_id)
    self.server:setLobbyChanged()
  end

  return self.logged_in
end

function Connection.menu_state(self)
  local state = {cursor = self.cursor, stage = self.stage, stage_is_random = self.stage_is_random, ready = self.ready, character = self.character, character_is_random = self.character_is_random, character_display_name = self.character_display_name, panels_dir = self.panels_dir, level = self.level, ranked = self.wants_ranked_match, inputMethod = self.inputMethod}
  return state
  --note: player_number here is the player_number of the connection as according to the server, not the "which" of any Stack
end

function Connection.send(self, stuff)
  if type(stuff) == "table" then
    local json = json.encode(stuff)
    stuff = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.serverMessageTypes.jsonMessage.prefix, json)
    logger.debug("Connection " .. self.index .. " Sending JSON: " .. stuff)
  else
    if type(stuff) == "string" then
      local type = stuff[1]
      if NetworkProtocol.isMessageTypeVerbose(type) == false then
        logger.debug("Connection " .. self.index .. " sending " .. stuff)
      end
    end
  end
  local retry_count = 0
  local times_to_retry = 5
  local foo = {}
  while not foo[1] and retry_count <= 5 do
    foo = {self.socket:send(stuff)}
    if not foo[1] then
      logger.debug("Connection.send failed. will retry...")
      retry_count = retry_count + 1
    end
  end
  if not foo[1] then
    logger.debug("Closing connection for " .. (self.name or "nil") .. ". Connection.send failed after " .. times_to_retry .. " retries were attempted")
    self:close()
  end
end

function Connection.opponent_disconnected(self)
  self.opponent = nil
  self.state = "lobby"
  self.server:setLobbyChanged()
  if self.room then
    logger.debug("Closing room for " .. (self.name or "nil") .. " because opponent disconnected.")
    self.server:closeRoom(self.room)
  end
  self:send({leave_room = true})
end

function Connection.setup_game(self)
  if self.state ~= "spectating" then
    self.state = "playing"
  end
  self.server:setLobbyChanged()
  self.vs_mode = true
  self.metal = false
end

function Connection.close(self)
  logger.debug("Closing connection to " .. self.index)
  if self.state == "lobby" then
    self.server:setLobbyChanged()
  end
  if self.room and (self.room.a.name == self.name or self.room.b.name == self.name) then
    logger.trace("about to close room for " .. (self.name or "nil") .. ".  Connection.close was called")
    self.server:closeRoom(self.room)
  elseif self.room then
    self.server:removeSpectator(self.room, self)
  end
  self.server:clear_proposals(self.name)
  if self.opponent then
    self.opponent:opponent_disconnected()
  end
  if self.name then
    self.server.name_to_idx[self.name] = nil
  end
  self.server.socket_to_idx[self.socket] = nil
  self.server.connections[self.index] = nil
  self.socket:close()
end

-- Handle NetworkProtocol.clientMessageTypes.versionCheck
function Connection.H(self, version)
  if version ~= VERSION and not ANY_ENGINE_VERSION_ENABLED then
    self:send(NetworkProtocol.serverMessageTypes.versionWrong.prefix)
  else
    self:send(NetworkProtocol.serverMessageTypes.versionCorrect.prefix)
  end
end

-- Handle NetworkProtocol.clientMessageTypes.playerInput
function Connection.I(self, message)
  if self.opponent then
    local iMessage = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.serverMessageTypes.opponentInput.prefix, message)
    self.opponent:send(iMessage)
    if not self.room then
      logger.warn("WARNING: missing room")
      logger.warn(self.name)
      logger.warn("doesn't have a room, we are wondering if this disconnects spectators")
    end
    if self.player_number == 1 and self.room then
      local uMessage = NetworkProtocol.markedMessageForTypeAndBody(NetworkProtocol.serverMessageTypes.secondOpponentInput.prefix, message)
      self.room:send_to_spectators(uMessage)
      self.room.replay.vs.in_buf = self.room.replay.vs.in_buf .. message
    elseif self.player_number == 2 and self.room then
      self.room:send_to_spectators(iMessage)
      self.room.replay.vs.I = self.room.replay.vs.I .. message
    end
  end
end

-- Handle clientMessageTypes.acknowledgedPing
function Connection.E(self, message)
end

-- Handle clientMessageTypes.jsonMessage
function Connection.J(self, message)
  message = json.decode(message)
  local response
  if message.error_report then -- Error report is checked for first so that a full login is not required
    logger.warn("Recieved an error report.")
    if not write_error_report(message.error_report) then
      logger.error("The error report was either too large or had an I/O failure when attempting to write the file.")
    end
    self:close() -- After sending the error report, the client will throw the error, so end the connection.
    return
  elseif self.state == "needs_name" then
    if not message.name or message.name == "" then
      logger.warn("connection didn't send a name")
      response = {choose_another_name = {reason = "Name cannot be blank"}}
      self:send(response)
      return
    elseif string.lower(message.name) == "anonymous" then
      logger.warn('connection tried to use name "anonymous"')
      response = {choose_another_name = {reason = 'Username cannot be "anonymous"'}}
      self:send(response)
      return
    elseif message.name:lower():match("d+e+f+a+u+l+t+n+a+m+e?") then
      logger.warn('connection tried to use name "defaultname", or a variation of it')
      response = {choose_another_name = {reason = 'Username cannot be "defaultname" or a variation of it'}}
      self:send(response)
      return
    elseif self.server.name_to_idx[message.name] then
      logger.debug("connection sent name: " .. message.name)
      local names = {}
      for _, v in pairs(self.server.connections) do
        names[#names + 1] = v.name -- fine if name is nil :o
      end
      response = {choose_another_name = {used_names = names}}
      self:send(response)
    elseif message.name:find("[^_%w]") then
      response = {choose_another_name = {reason = "Usernames are limited to alphanumeric and underscores"}}
      self:send(response)
    elseif utf8.len(message.name) > NAME_LENGTH_LIMIT then
      response = {choose_another_name = {reason = "The name length limit is " .. NAME_LENGTH_LIMIT .. " characters"}}
      self:send(response)
    else
      self.name = message.name
      self.character = message.character
      self.character_is_random = message.character_is_random
      self.character_display_name = message.character_display_name
      self.stage = message.stage
      self.stage_is_random = message.stage_is_random
      self.panels_dir = message.panels_dir
      self.level = message.level
      self.inputMethod = (message.inputMethod or "controller")
      self.save_replays_publicly = message.save_replays_publicly
      self.wants_ranked_match = message.ranked
      self.state = "lobby"
      self.server.name_to_idx[self.name] = self.index
      -- Don't update lobby yet, we will do that when they are logged in
    end
  elseif message.login_request then
    self:login(message.user_id)
  elseif message.logout then
    self:close()
  elseif self.state == "lobby" and message.game_request then
    if message.game_request.sender == self.name then
      self.server:propose_game(message.game_request.sender, message.game_request.receiver, message)
    end
  elseif message.leaderboard_request then
    self:send({leaderboard_report = leaderboard:get_report(self)})
  elseif message.spectate_request then
    local requestedRoom = self.server:roomNumberToRoom(message.spectate_request.roomNumber)
    if self.state ~= "lobby" then
      if requestedRoom then
        logger.debug("removing " .. self.name .. " from room nr " .. message.spectate_request.roomNumber)
        self.server:removeSpectator(requestedRoom, self)
      else
        logger.warn("could not find room to remove " .. self.name)
        self.state = "lobby"
      end
    end
    if requestedRoom and requestedRoom:state() == "character select" then
      logger.debug("adding " .. self.name .. " to room nr " .. message.spectate_request.roomNumber)
      self.server:addSpectator(requestedRoom, self)
    elseif requestedRoom and requestedRoom:state() == "playing" then
      logger.debug("adding " .. self.name .. " to room nr " .. message.spectate_request.roomNumber)
      self.server:addSpectator(requestedRoom, self)
    else
      -- TODO: tell the client the join request failed, couldn't find the room.
      logger.warn("couldn't find room")
    end
  elseif self.state == "character select" and message.menu_state then
    self.level = message.menu_state.level
    self.inputMethod = (message.menu_state.inputMethod or "controller") --one day we will require message to include input method, but it is not this day.
    self.character = message.menu_state.character
    self.character_is_random = message.menu_state.character_is_random
    self.character_display_name = message.menu_state.character_display_name
    self.stage = message.menu_state.stage
    self.stage_is_random = message.menu_state.stage_is_random
    self.ready = message.menu_state.ready
    self.cursor = message.menu_state.cursor
    self.panels_dir = message.menu_state.panels_dir
    self.wants_ranked_match = message.menu_state.ranked
    logger.debug("about to check for rating_adjustment_approval for " .. self.name .. " and " .. self.opponent.name)
    if self.wants_ranked_match or self.opponent.wants_ranked_match then
      local ranked_match_approved, reasons = self.room:rating_adjustment_approved()
      if ranked_match_approved then
        if not reasons[1] then
          reasons = nil
        end
        self.room:send({ranked_match_approved = true, caveats = reasons})
      else
        self.room:send({ranked_match_denied = true, reasons = reasons})
      end
    end

    if self.ready and self.opponent.ready then
      self.room.replay = {}
      self.room.replay.vs = {
        P = "",
        O = "",
        I = "",
        Q = "",
        R = "",
        in_buf = "",
        P1_level = self.room.a.level,
        P2_level = self.room.b.level,
        P1_inputMethod = self.room.a.inputMethod,
        P2_inputMethod = self.room.b.inputMethod,
        P1_char = self.room.a.character,
        P2_char = self.room.b.character,
        ranked = self.room:rating_adjustment_approved(),
        do_countdown = true
      }
      if self.player_number == 1 then
        self.server:start_match(self, self.opponent)
      else
        self.server:start_match(self.opponent, self)
      end
    else
      self.opponent:send(message)
      message.player_number = self.player_number
      logger.debug("about to send match start to spectators of " .. (self.name or "nil") .. " and " .. (self.opponent.name or "nil"))
      self.room:send_to_spectators(message) -- TODO: may need to include in the message who is sending the message
    end
  elseif self.state == "playing" and message.taunt then
    message.player_number = self.player_number
    self.opponent:send(message)
    self.room:send_to_spectators(message)
  elseif self.state == "playing" and message.game_over then
    self.room.game_outcome_reports[self.player_number] = message.outcome
    if self.room:resolve_game_outcome(self.server.database) then
      logger.debug("\n*******************************")
      logger.debug("***" .. self.room.a.name .. " " .. self.room.win_counts[1] .. " - " .. self.room.win_counts[2] .. " " .. self.room.b.name .. "***")
      logger.debug("*******************************\n")
      self.room.game_outcome_reports = {}
      self.room:character_select()
    end
  elseif (self.state == "playing" or self.state == "character select") and message.leave_room then
    local op = self.opponent
    self:opponent_disconnected()
    op:opponent_disconnected()
    if self.room and self.room.spectators then
      for k, v in pairs(self.room.spectators) do
        v:opponent_disconnected()
      end
    end
  elseif (self.state == "spectating") and message.leave_room then
    self.server:removeSpectator(self.room, self)
  end
end

function Connection.read(self)
  local junk, err, data = self.socket:receive("*a")
  if not err then
    data = junk
  end
  if data and data:len() > 0 then
    self:data_received(data)
  end
end

function Connection.data_received(self, data)
  self.last_read = time()
  self.leftovers = self.leftovers .. data

  while true do
    local type, message, remaining = NetworkProtocol.getMessageFromString(self.leftovers, false)
    if type then
      self:processMessage(type, message)
      self.leftovers = remaining
    else
      break
    end
  end
end

function Connection:processMessage(messageType, data)
  if messageType ~= NetworkProtocol.clientMessageTypes.acknowledgedPing.prefix then
    logger.trace(self.index .. "- processing message:" .. messageType .. " data: " .. data)
  end
  local status, error = pcall(
      function()
        self[messageType](self, data)
      end
    )
  if status == false and error and type(error) == "string" then
    logger.error("pcall error results: " .. tostring(error))
  end
end


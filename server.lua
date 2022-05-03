local socket = require("socket")
local logger = require("logger")
require("class")
json = require("dkjson")
require("stridx")
require("gen_panels")
require("csprng")
require("server_file_io")
require("util")
require("timezones")
local lfs = require("lfs")

local byte = string.byte
local char = string.char
local pairs = pairs
local ipairs = ipairs
local random = math.random
local lobby_changed = false
local time = os.time
local floor = math.floor
local TIMEOUT = 10
local CHARACTERSELECT = "character select" -- room states
local PLAYING = "playing" -- room states
local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

local VERSION = "045"
local type_to_length = {H = 4, E = 4, F = 4, P = 8, I = 2, L = 2, Q = 8, U = 2}
local INDEX = 1 -- GLOBAL counter of the next available connection index
local connections = {}
local ROOMNUMBER = 1
local rooms = {}
local name_to_idx = {} -- mapping of names to their connection unique INDEX
local socket_to_idx = {}
local proposals = {}
local playerbases = {}
local loaded_placement_matches = {
  incomplete = {},
  complete = {}
}

function addPublicPlayerData(players, playerName, player) 
  if not players or not player then
    return
  end

  if not players[playerName] then
    players[playerName] = {}
  end

  if player.rating then
    players[playerName].rating = round(player.rating)
  end

  if player.ranked_games_played then
    players[playerName].ranked_games_played = player.ranked_games_played
  end
end

function lobby_state()
  local names = {}
  local players = {}
  for _, v in pairs(connections) do
    if v.state == "lobby" then
      names[#names + 1] = v.name
      addPublicPlayerData(players, v.name, leaderboard.players[v.user_id])
    end
  end
  local spectatableRooms = {}
  for _, v in pairs(rooms) do
    spectatableRooms[#spectatableRooms + 1] = {roomNumber = v.roomNumber, name = v.name, a = v.a.name, b = v.b.name, state = v:state()}
    addPublicPlayerData(players, v.a.name, leaderboard.players[v.a.user_id])
    addPublicPlayerData(players, v.b.name, leaderboard.players[v.b.user_id])
  end
  return {unpaired = names, spectatable = spectatableRooms, players = players}
end

function propose_game(sender, receiver, message)
  local s_c, r_c = name_to_idx[sender], name_to_idx[receiver]
  if s_c then
    s_c = connections[s_c]
  end
  if r_c then
    r_c = connections[r_c]
  end
  if s_c and s_c.state == "lobby" and r_c and r_c.state == "lobby" then
    proposals[sender] = proposals[sender] or {}
    proposals[receiver] = proposals[receiver] or {}
    if proposals[sender][receiver] then
      if proposals[sender][receiver][receiver] then
        create_room(s_c, r_c)
      end
    else
      r_c:send(message)
      local prop = {[sender] = true}
      proposals[sender][receiver] = prop
      proposals[receiver][sender] = prop
    end
  end
end

function clear_proposals(name)
  if proposals[name] then
    for othername, _ in pairs(proposals[name]) do
      proposals[name][othername] = nil
      if proposals[othername] then
        proposals[othername][name] = nil
      end
    end
    proposals[name] = nil
  end
end

function create_room(a, b)
  lobby_changed = true
  clear_proposals(a.name)
  clear_proposals(b.name)
  local new_room = Room(a, b)
  local a_msg, b_msg = {create_room = true}, {create_room = true}
  a_msg.your_player_number = 1
  a_msg.op_player_number = 2
  a_msg.opponent = new_room.b.name
  b_msg.opponent = new_room.a.name
  new_room.b.cursor = "__Ready"
  new_room.a.cursor = "__Ready"
  b_msg.your_player_number = 2
  b_msg.op_player_number = 1
  a_msg.a_menu_state = new_room.a:menu_state()
  a_msg.b_menu_state = new_room.b:menu_state()
  b_msg.b_menu_state = new_room.b:menu_state()
  b_msg.a_menu_state = new_room.a:menu_state()
  new_room.a.opponent = new_room.b
  new_room.b.opponent = new_room.a

  new_room:prepare_character_select()
  a_msg.ratings = new_room.ratings
  b_msg.ratings = new_room.ratings
  a_msg.rating_updates = true
  b_msg.rating_updates = true

  new_room.a:send(a_msg)
  new_room.b:send(b_msg)
end

function start_match(a, b)
  if (a.player_number ~= 1) then
    logger.info("Match starting, players a and b need to be swapped.")
    a, b = b, a
    if (a.player_number == 1) then
      logger.info("Success, player a now has player_number 1.")
    else
      logger.error("ERROR: player a still doesn't have player_number 1.")
    end
  end

  a.room.stage = math.random(1, 2) == 1 and a.stage or b.stage
  local msg = {
    match_start = true,
    ranked = false,
    stage = a.room.stage,
    player_settings = {character = a.character, character_display_name = a.character_display_name, level = a.level, panels_dir = a.panels_dir, player_number = a.player_number},
    opponent_settings = {character = b.character, character_display_name = b.character_display_name, level = b.level, panels_dir = b.panels_dir, player_number = b.player_number}
  }
  local room_is_ranked, reasons = a.room:rating_adjustment_approved()
  if room_is_ranked then
    a.room.replay.vs.ranked = true
    msg.ranked = true
    if leaderboard.players[a.user_id] then
      msg.player_settings.rating = round(leaderboard.players[a.user_id].rating)
    else
      msg.player_settings.rating = DEFAULT_RATING
    end
    if leaderboard.players[b.user_id] then
      msg.opponent_settings.rating = round(leaderboard.players[b.user_id].rating)
    else
      msg.opponent_settings.rating = DEFAULT_RATING
    end
  end
  a.room.replay.vs.seed = math.random(1,9999999)
  msg.seed = a.room.replay.vs.seed
  a.room.replay.vs.P1_name = a.name
  a.room.replay.vs.P2_name = b.name
  a.room.replay.vs.P1_char = a.character
  a.room.replay.vs.P2_char = b.character
  a:send(msg)
  a.room:send_to_spectators(msg)
  msg.player_settings, msg.opponent_settings = msg.opponent_settings, msg.player_settings
  b:send(msg)
  lobby_changed = true
  a:setup_game()
  b:setup_game()
  if not a.room then
    logger.error("ERROR: In start_match, Player A " .. (a.name or "nil") .. " doesn't have a room\nCannot run setup_game() for spectators!")
  end
  for k, v in pairs(a.room.spectators) do
    v:setup_game()
  end
end

Room =
  class(
  function(self, a, b)
    --TODO: it would be nice to call players a and b something more like self.players[1] and self.players[2]
    self.a = a --player a
    self.b = b --player b
    self.stage = nil
    self.name = a.name .. " vs " .. b.name
    self.roomNumber = ROOMNUMBER
    ROOMNUMBER = ROOMNUMBER + 1
    self.a.room = self
    self.b.room = self
    self.spectators = {}
    self.win_counts = {}
    self.win_counts[1] = 0
    self.win_counts[2] = 0
    local a_rating, b_rating
    local a_placement_match_progress, b_placement_match_progress

    if a.user_id then
      if leaderboard.players[a.user_id] and leaderboard.players[a.user_id].rating then
        a_rating = round(leaderboard.players[a.user_id].rating)
      end
      local a_qualifies, a_progress = qualifies_for_placement(a.user_id)
      if not (leaderboard.players[a.user_id] and leaderboard.players[a.user_id].placement_done) and not a_qualifies then
        a_placement_match_progress = a_progress
      end
    end

    if b.user_id then
      if leaderboard.players[b.user_id] and leaderboard.players[b.user_id].rating then
        b_rating = round(leaderboard.players[b.user_id].rating or 0)
      end
      local b_qualifies, b_progress = qualifies_for_placement(b.user_id)
      if not (leaderboard.players[b.user_id] and leaderboard.players[b.user_id].placement_done) and not b_qualifies then
        b_placement_match_progress = b_progress
      end
    end

    self.ratings = {
      {old = a_rating or 0, new = a_rating or 0, difference = 0, league = get_league(a_rating or 0), placement_match_progress = a_placement_match_progress},
      {old = b_rating or 0, new = b_rating or 0, difference = 0, league = get_league(b_rating or 0), placement_match_progress = b_placement_match_progress}
    }

    self.game_outcome_reports = {}
    rooms[self.roomNumber] = self
  end
)

function Room.character_select(self)
  self:prepare_character_select()
  self:send({character_select = true, create_room = true, rating_updates = true, ratings = self.ratings, a_menu_state = self.a:menu_state(), b_menu_state = self.b:menu_state()})
end

function Room.prepare_character_select(self)
  logger.debug("Called Server.lua Room.character_select")
  self.a.state = "character select"
  self.b.state = "character select"
  if self.a.player_number and self.a.player_number ~= 0 and self.a.player_number ~= 1 then
    logger.info("initializing room. player a does not have player_number 1. Swapping players a and b")
    self.a, self.b = self.b, self.a
    if self.a.player_number == 1 then
      logger.info("Success. player a has player_number 1 now.")
    else
      logger.error("ERROR. Player a still doesn't have player_number 1")
    end
  else
    self.a.player_number = 1
    self.b.player_number = 2
  end
  self.a.cursor = "__Ready"
  self.b.cursor = "__Ready"
  self.a.ready = false
  self.b.ready = false
  -- local msg = {spectate_request_granted = true, spectate_request_rejected = false, rating_updates=true, ratings=self.ratings, a_menu_state=self.a:menu_state(), b_menu_state=self.b:menu_state()}
  -- for k,v in ipairs(self.spectators) do
  -- self.spectators[k]:send(msg)
  -- end
end

function Room.state(self)
  if self.a.state == "character select" then
    return CHARACTERSELECT
  elseif self.a.state == "playing" then
    return PLAYING
  else
    return self.a.state
  end
end

function Room.is_spectatable(self)
  return self.a.state == "character select"
end

function Room.add_spectator(self, new_spectator_connection)
  new_spectator_connection.state = "spectating"
  new_spectator_connection.room = self
  self.spectators[#self.spectators + 1] = new_spectator_connection
  logger.info(new_spectator_connection.name .. " joined " .. self.name .. " as a spectator")
  msg = {
    spectate_request_granted = true,
    spectate_request_rejected = false,
    rating_updates = true,
    ratings = self.ratings,
    a_menu_state = self.a:menu_state(),
    b_menu_state = self.b:menu_state(),
    win_counts = self.win_counts,
    match_start = replay_of_match_so_far ~= nil,
    stage = self.stage,
    replay_of_match_so_far = self.replay,
    ranked = self:rating_adjustment_approved(),
    player_settings = {character = self.a.character, character_display_name = self.a.character_display_name, level = self.a.level, player_number = self.a.player_number},
    opponent_settings = {character = self.b.character, character_display_name = self.b.character_display_name, level = self.b.level, player_number = self.b.player_number}
  }
  if COMPRESS_SPECTATOR_REPLAYS_ENABLED then
    msg.replay_of_match_so_far.vs.in_buf = compress_input_string(msg.replay_of_match_so_far.vs.in_buf)
    msg.replay_of_match_so_far.vs.I = compress_input_string(msg.replay_of_match_so_far.vs.I)
  end
  new_spectator_connection:send(msg)
  msg = {spectators = self:spectator_names()}
  logger.debug("sending spectator list: " .. json.encode(msg))
  self:send(msg)
  lobby_changed = true
end

function Room.spectator_names(self)
  local list = {}
  for k, v in pairs(self.spectators) do
    list[#list + 1] = v.name
  end
  return list
end

function Room.remove_spectator(self, connection)
  for k, v in pairs(self.spectators) do
    if v.name == connection.name then
      self.spectators[k].state = "lobby"
      logger.info(connection.name .. " left " .. self.name .. " as a spectator")
      self.spectators[k] = nil
      connection.room = nil
      lobby_changed = true
    end
  end
  msg = {spectators = self:spectator_names()}
  logger.debug("sending spectator list: " .. json.encode(msg))
  self:send(msg)
end

function Room.close(self)
  if self.a then
    self.a.player_number = 0
    self.a.state = "lobby"
    self.a.room = nil
  end
  if self.b then
    self.b.player_number = 0
    self.b.state = "lobby"
    self.b.room = nil
  end
  for k, v in pairs(self.spectators) do
    if v.room then
      v.room = nil
      v.state = "lobby"
    end
  end
  if rooms[self.roomNumber] then
    rooms[self.roomNumber] = nil
  end
  self:send_to_spectators({leave_room = true})
end

function roomNumberToRoom(roomNr)
  for k, v in pairs(rooms) do
    if rooms[k].roomNumber and rooms[k].roomNumber == roomNr then
      return v
    end
  end
end

--TODO: maybe support multiple playerbases
Playerbase =
  class(
  function(s, name)
    s.name = name
    s.players = {}
    --{["e2016ef09a0c7c2fa70a0fb5b99e9674"]="Bob",
    --["d28ac48ba5e1a82e09b9579b0a5a7def"]="Alice"}
    s.deleted_players = {}
    playerbases[#playerbases + 1] = s
  end
)

function Playerbase:update(user_id, user_name)
  self.players[user_id] = user_name
  write_players_file()
end

-- returns true if the name is taken by a different user already
function Playerbase:nameTaken(userID, playerName)

  for key, value in pairs(self.players) do
    if value:lower() == playerName:lower() then
      if key ~= userID then
        return true
      end
    end
  end

  return false
end

function Playerbase.delete_player(self, user_id)
  -- returns whether a player was deleted
  if self.players[user_id] then
    self.deleted_players[user_id] = self.players[user_id]
    self.players[user_id] = nil
    write_players_file()
    write_deleted_players_file()
    return true
  else
    return false
  end
end

function generate_new_user_id()
  new_user_id = cs_random()
  logger.debug("new_user_id: " .. new_user_id)
  return tostring(new_user_id)
end

--TODO: support multiple leaderboards
Leaderboard =
  class(
  function(s, name)
    s.name = name
    s.players = {} -- user_id -> user_id,user_name,rating,placement_done,placement_rating,ranked_games_played,ranked_games_won,last_login_time
  end
)

function Leaderboard.update(self, user_id, new_rating, match_details)
  logger.debug("in Leaderboard.update")
  if self.players[user_id] then
    self.players[user_id].rating = new_rating
  else
    self.players[user_id] = {rating = new_rating}
  end
  if match_details and match_details ~= "" then
    for k, v in pairs(match_details) do
      self.players[user_id].ranked_games_won = (self.players[user_id].games_won or 0) + v.outcome
      self.players[user_id].ranked_games_played = (self.players[user_id].ranked_games_played or 0) + 1
    end
  end
  logger.debug("new_rating = " .. new_rating)
  logger.debug("about to write_leaderboard_file")
  write_leaderboard_file()
  logger.debug("done with Leaderboard.update")
end

function Leaderboard.get_report(self, user_id_of_requester)
  --returns the leaderboard as an array sorted from highest rating to lowest,
  --with usernames from playerbase.players instead of user_ids
  --ie report[1] will give the highest rating player's user_name and how many points they have. Like this:
  --report[1] might return {user_name="Alice",rating=2250}
  --report[2] might return {user_name="Bob",rating=2100,is_you=true} if Bob requested the leaderboard
  local report = {}
  local leaderboard_player_count = 0
  --count how many entries there are in self.players since #self.players will not give us an accurate answer for sparse tables
  for k, v in pairs(self.players) do
    leaderboard_player_count = leaderboard_player_count + 1
  end
  for k, v in pairs(self.players) do
    for insert_index = 1, leaderboard_player_count do
      local player_is_leaderboard_requester = nil
      if playerbase.players[k] then --only include in the report players who are still listed in the playerbase
        if v.placement_done then --don't include players who haven't finished placement
          if v.rating then -- don't include entries who's rating is nil (which shouldn't happen anyway)
            if k == user_id_of_requester then
              player_is_leaderboard_requester = true
            end
            if report[insert_index] and report[insert_index].rating and v.rating >= report[insert_index].rating then
              table.insert(report, insert_index, {user_name = playerbase.players[k], rating = v.rating, is_you = player_is_leaderboard_requester})
              break
            elseif insert_index == leaderboard_player_count or #report == 0 then
              table.insert(report, {user_name = playerbase.players[k], rating = v.rating, is_you = player_is_leaderboard_requester}) -- at the end of the table.
              break
            end
          end
        end
      end
    end
  end
  for k, v in pairs(report) do
    v.rating = round(v.rating)
  end
  return report
end

function Leaderboard.update_timestamp(self, user_id)
  if self.players[user_id] then
    local timestamp = os.time()
    self.players[user_id].last_login_time = timestamp
    write_leaderboard_file()
    logger.info(user_id .. "'s login timestamp has been updated to " .. timestamp)
  else
    logger.info(user_id .. " is not on the leaderboard, so no timestamp will be assigned at this time.")
  end
end

Connection =
  class(
  function(s, socket)
    s.index = INDEX
    INDEX = INDEX + 1
    connections[s.index] = s
    socket_to_idx[socket] = s.index
    s.socket = socket
    s.leftovers = ""
    s.state = "needs_name"
    s.room = nil
    s.last_read = time()
    s.player_number = 0 -- 0 if not a player in a room, 1 if player "a" in a room, 2 if player "b" in a room
    s.logged_in = false --whether connection has successfully logged into the rating system.
    s.user_id = nil
    s.wants_ranked_match = false --TODO: let the user change wants_ranked_match
  end
)

function Connection.menu_state(self)
  state = {cursor = self.cursor, stage = self.stage, stage_is_random = self.stage_is_random, ready = self.ready, character = self.character, character_is_random = self.character_is_random, character_display_name = self.character_display_name, panels_dir = self.panels_dir, level = self.level, ranked = self.wants_ranked_match}
  return state
  --note: player_number here is the player_number of the connection as according to the server, not the "which" of any Stack
end

function Connection.send(self, stuff)
  if type(stuff) == "table" then
    local json = json.encode(stuff)
    local len = json:len()
    local prefix = "J" .. char(floor(len / 65536)) .. char(floor((len / 256) % 256)) .. char(len % 256)
    --print(byte(prefix[1]), byte(prefix[2]), byte(prefix[3]), byte(prefix[4]))
    logger.debug("sending json " .. json)
    stuff = prefix .. json
  else
    if stuff[1] ~= "I" and stuff[1] ~= "U" and stuff[1] ~= "E" then
      logger.debug("sending non-json " .. stuff)
    end
  end
  local retry_count = 0
  local times_to_retry = 5
  local foo = {}
  while not foo[1] and retry_count <= 5 do
    foo = {self.socket:send(stuff)}
    if stuff[1] ~= "I" and stuff[1] ~= "U" and stuff[1] ~= "E" then
      logger.trace(unpack(foo))
    end
    if not foo[1] then
      logger.warn("WARNING: Connection.send failed. will retry...")
      retry_count = retry_count + 1
    end
  end
  if not foo[1] then
    logger.warn("Closing connection for " .. (self.name or "nil") .. ". During Connection.send, foo[1] was nil after " .. times_to_retry .. " retries were attempted")
    self:close()
  end
end

function Connection.login(self, user_id)
  --returns whether the login was successful
  --print("Connection.login was called!")
  self.user_id = user_id
  self.logged_in = false
  local IP_logging_in, port = self.socket:getpeername()
  logger.info("New login attempt:  " .. IP_logging_in .. ":" .. port)
  if is_banned(IP_logging_in) then
    deny_login(self, "Awaiting ban timeout")
  elseif not self.name then
    deny_login(self, "Player has no name")
    logger.warn("Login failure: Player has no name")
  elseif not self.user_id then
    deny_login(self, "Client did not send a user_id in the login request")
    success = false
  elseif self.user_id == "need a new user id" and self.name then

    if playerbase:nameTaken("", self.name) then
      self:send({choose_another_name = {reason = "That player name is already taken"}})
      logger.warn("Login failure: Player tried to create a new user with an already taken name: " .. self.name)
    else 
      logger.info(self.name .. " needs a new user id!")
      local their_new_user_id
      while not their_new_user_id or playerbase.players[their_new_user_id] do
        their_new_user_id = generate_new_user_id()
      end
      playerbase:update(their_new_user_id, self.name)
      self:send({login_successful = true, new_user_id = their_new_user_id})
      self.user_id = their_new_user_id
      self.logged_in = true
      logger.info("Connection with name " .. self.name .. " was assigned a new user_id")
    end
  elseif not playerbase.players[self.user_id] then
    deny_login(self, "The user_id provided was not found on this server")
    logger.warn("Login failure: " .. self.name .. " specified an invalid user_id")
  elseif playerbase.players[self.user_id] ~= self.name then
    if playerbase:nameTaken(self.user_id, self.name) then
      self:send({choose_another_name = {reason = "That player name is already taken"}})
      logger.warn("Login failure: Player tried to use already taken name: " .. self.name)
    else 
      local the_old_name = playerbase.players[self.user_id]
      playerbase:update(self.user_id, self.name)
      if leaderboard.players[self.user_id] then
        leaderboard.players[self.user_id].user_name = self.name
      end
      self.logged_in = true
      self:send({login_successful = true, name_changed = true, old_name = the_old_name, new_name = self.name})
      logger.warn("Login successful and changed name " .. the_old_name .. " to " .. self.name)
    end
  elseif playerbase.players[self.user_id] then
    self.logged_in = true
    self:send({login_successful = true})
  else
    deny_login(self, "Unknown")
  end

  if self.logged_in then
    self:send(lobby_state())
    leaderboard:update_timestamp(user_id)
  end

  return self.logged_in
end

--TODO: revisit this to determine whether it is good.
function deny_login(connection, reason)
  local new_violation_count = 0
  local IP, port = connection.socket:getsockname()
  if is_banned(IP) then
    --don't adjust ban_list
  elseif ban_list[IP] and reason == "The user_id provided was not found on this server" then
    ban_list[IP].violation_count = ban_list[IP].violation_count + 1
    ban_list[IP].unban_time = os.time() + 60 * ban_list[IP].violation_count
  elseif reason == "The user_id provided was not found on this server" then
    ban_list[IP] = {violation_count = 1, unban_time = os.time() + 60}
  else
    ban_list[IP] = {violation_count = 0, unban_time = os.time()}
  end
  ban_list[IP].user_name = connection.name or ""
  ban_list[IP].reason = reason
  connection:send(
    {
      login_denied = true,
      reason = reason,
      ban_duration = math.floor((ban_list[IP].unban_time - os.time()) / 60) .. "min" .. ((ban_list[IP].unban_time - os.time()) % 60) .. "sec",
      violation_count = ban_list[IP].violation_count
    }
  )
  logger.warn("login denied.  Reason:  " .. reason)
end

function unban(connection)
  local IP, port = connection.socket:getsockname()
  if ban_list[IP] then
    ban_list[IP] = nil
  end
end

function is_banned(IP)
  local is_banned = false
  if ban_list[IP] and ban_list[IP].unban_time - os.time() > 0 then
    is_banned = true
  end
  return is_banned
end

function Connection.opponent_disconnected(self)
  self.opponent = nil
  self.state = "lobby"
  lobby_changed = true
  if self.room then
    logger.info("Closing room for " .. (self.name or "nil") .. " because opponent disconnected.")
    self.room:close()
  end
  self:send({leave_room = true})
end

function Connection.setup_game(self)
  if self.state ~= "spectating" then
    self.state = "playing"
  end
  lobby_changed = true --TODO: remove this line when we implement joining games in progress
  self.vs_mode = true
  self.metal = false
  self.rows_left = 14 + random(1, 8)
  self.prev_metal_col = nil
  self.metal_col = nil
  self.first_seven = nil
end

function Connection.close(self)
  if self.state == "lobby" then
    lobby_changed = true
  end
  if self.room and (self.room.a.name == self.name or self.room.b.name == self.name) then
    logger.info("about to close room for " .. (self.name or "nil") .. ".  Connection.close was called")
    self.room:close()
  elseif self.room then
    self.room:remove_spectator(self)
  end
  clear_proposals(self.name)
  if self.opponent then
    self.opponent:opponent_disconnected()
  end
  if self.name then
    name_to_idx[self.name] = nil
  end
  socket_to_idx[self.socket] = nil
  connections[self.index] = nil
  self.socket:close()
end

function Connection.H(self, version)
  if version ~= VERSION and not ANY_ENGINE_VERSION_ENABLED then
    self:send("N")
  else
    self:send("H")
  end
end

function Connection.I(self, message)
  if self.opponent then
    self.opponent:send("I" .. message)
    if not self.room then
      logger.warn("WARNING: missing room")
      logger.warn(self.name)
      logger.warn("doesn't have a room, we are wondering if this disconnects spectators")
    end
    if self.player_number == 1 and self.room then
      self.room:send_to_spectators("U" .. message)
      self.room.replay.vs.in_buf = self.room.replay.vs.in_buf .. message
    elseif self.player_number == 2 and self.room then
      self.room:send_to_spectators("I" .. message)
      self.room.replay.vs.I = self.room.replay.vs.I .. message
    end
  end
end

function Room.send_to_spectators(self, message)
  --TODO: maybe try to do this in a different thread?
  for k, v in pairs(self.spectators) do
    if v then
      v:send(message)
    end
  end
end

function Room.send(self, message)
  if self.a then
    self.a:send(message)
  end
  if self.b then
    self.b:send(message)
  end
  self:send_to_spectators(message)
end

function Room.resolve_game_outcome(self)
  --Note: return value is whether the outcome could be resolved
  if not self.game_outcome_reports[1] or not self.game_outcome_reports[2] then
    return false
  else
    local outcome = nil
    if self.game_outcome_reports[1] ~= self.game_outcome_reports[2] then
      --if clients disagree, the server needs to decide the outcome, perhaps by watching a replay it had created during the game.
      --for now though...
      logger.warn("clients " .. self.a.name .. " and " .. self.b.name .. " disagree on their game outcome. So the server will declare a tie.")
      outcome = 0
    else
      outcome = self.game_outcome_reports[1]
    end
    logger.info("resolve_game_outcome says: " .. outcome)
    --outcome is the player number of the winner, or 0 for a tie
    if self.a.save_replays_publicly ~= "not at all" and self.b.save_replays_publicly ~= "not at all" then
      --use UTC time for dates on replays
      local now = os.date("*t", to_UTC(os.time()))
      local path = "ftp" .. sep .. "replays" .. sep .. "v" .. VERSION .. sep .. string.format("%04d" .. sep .. "%02d" .. sep .. "%02d", now.year, now.month, now.day)
      local rep_a_name, rep_b_name = self.a.name, self.b.name
      if self.a.save_replays_publicly == "anonymously" then
        rep_a_name = "anonymous"
        self.replay.P1_name = "anonymous"
      end
      if self.b.save_replays_publicly == "anonymously" then
        rep_b_name = "anonymous"
        self.replay.P2_name = "anonymous"
      end
      --sort player names alphabetically for folder name so we don't have a folder "a-vs-b" and also "b-vs-a"
      --don't switch to put "anonymous" first though
      if rep_b_name < rep_a_name and rep_b_name ~= "anonymous" then
        path = path .. sep .. rep_b_name .. "-vs-" .. rep_a_name
      else
        path = path .. sep .. rep_a_name .. "-vs-" .. rep_b_name
      end
      local filename = "v" .. VERSION .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec) .. "-" .. rep_a_name .. "-L" .. self.replay.vs.P1_level .. "-vs-" .. rep_b_name .. "-L" .. self.replay.vs.P2_level
      if self.replay.vs.ranked then
        filename = filename .. "-Ranked"
      else
        filename = filename .. "-Casual"
      end
      if outcome == 1 or outcome == 2 then
        filename = filename .. "-P" .. outcome .. "wins"
      elseif outcome == 0 then
        filename = filename .. "-draw"
      end
      filename = filename .. ".txt"
      if self.replay.vs and COMPRESS_REPLAYS_ENABLED then
        self.replay.vs.I = compress_input_string(self.replay.vs.I)
        self.replay.vs.in_buf = compress_input_string(self.replay.vs.in_buf)
        logger.debug("Compressed vs I/in_buf")
        logger.info("saving compressed replay as " .. path .. sep .. filename)
      else
        logger.info("saving replay as " .. path .. sep .. filename)
      end
      write_replay_file(self.replay, path, filename)
    else
      logger.info("replay not saved because a player didn't want it saved")
    end
    self.replay = nil
    if outcome == 0 then
      logger.info("tie.  Nobody scored")
      --do nothing. no points or rating adjustments for ties.
      return true
    else
      local someone_scored = false
      for i = 1, 2, 1 --[[or Number of players if we implement more than 2 players]] do
        logger.debug("checking if player " .. i .. " scored...")
        if outcome == i then
          logger.info("Player " .. i .. " scored")
          self.win_counts[i] = self.win_counts[i] + 1
          adjust_ratings(self, i)
          someone_scored = true
        end
      end
      if someone_scored then
        local msg = {win_counts = self.win_counts}
        self.a:send(msg)
        self.b:send(msg)
        self:send_to_spectators(msg)
      end
      return true
    end
  end
end

function Room.rating_adjustment_approved(self)
  --returns whether both players in the room have game states such that rating adjustment should be approved
  local players = {self.a, self.b}
  local reasons = {}
  local caveats = {}
  local prev_player_level = players[1].level
  local both_players_are_placed = nil

  if PLACEMENT_MATCHES_ENABLED then
    if leaderboard.players[players[1].user_id] and leaderboard.players[players[1].user_id].placement_done and leaderboard.players[players[2].user_id] and leaderboard.players[players[2].user_id].placement_done then
      --both players are placed on the leaderboard.
      both_players_are_placed = true
    elseif not (leaderboard.players[players[1].user_id] and leaderboard.players[players[1].user_id].placement_done) and not (leaderboard.players[players[2].user_id] and leaderboard.players[players[2].user_id].placement_done) then
      reasons[#reasons + 1] = "Neither player has finished enough placement matches against already ranked players"
    end
  else
    both_players_are_placed = true
  end
  -- don't let players use the same account
  if players[1].user_id == players[2].user_id then
    reasons[#reasons + 1] = "Players cannot use the same account"
  end

  --don't let players too far apart in rating play ranked
  local ratings = {}
  for k, v in ipairs(players) do
    if leaderboard.players[v.user_id] then
      if not leaderboard.players[v.user_id].placement_done and leaderboard.players[v.user_id].placement_rating then
        ratings[k] = leaderboard.players[v.user_id].placement_rating
      elseif leaderboard.players[v.user_id].rating and leaderboard.players[v.user_id].rating ~= 0 then
        ratings[k] = leaderboard.players[v.user_id].rating
      else
        ratings[k] = DEFAULT_RATING
      end
    else
      ratings[k] = DEFAULT_RATING
    end
  end
  if math.abs(ratings[1] - ratings[2]) > RATING_SPREAD_MODIFIER * ALLOWABLE_RATING_SPREAD_MULITPLIER then
    reasons[#reasons + 1] = "Players' ratings are too far apart"
  end

  local player_level_out_of_bounds_for_ranked = false
  for i = 1, 2 do --we'll change 2 here when more players are allowed.
    if (players[i].level < MIN_LEVEL_FOR_RANKED or players[i].level > MAX_LEVEL_FOR_RANKED) then
      player_level_out_of_bounds_for_ranked = true
    end
  end
  if player_level_out_of_bounds_for_ranked then
    reasons[#reasons + 1] = "Only levels between " .. MIN_LEVEL_FOR_RANKED .. " and " .. MAX_LEVEL_FOR_RANKED .. " are allowed for ranked play."
  end
  if players[1].level ~= players[2].level then
    reasons[#reasons + 1] = "Levels don't match"
  end
  for player_number = 1, 2 do
    if not playerbase.players[players[player_number].user_id] or not players[player_number].logged_in or playerbase.deleted_players[players[player_number].user_id] then
      reasons[#reasons + 1] = players[player_number].name .. " didn't log in"
    end
    if not players[player_number].wants_ranked_match then
      reasons[#reasons + 1] = players[player_number].name .. " doesn't want ranked"
    end
  end
  if reasons[1] then
    return false, reasons
  else
    if PLACEMENT_MATCHES_ENABLED and not both_players_are_placed and ((leaderboard.players[players[1].user_id] and leaderboard.players[players[1].user_id].placement_done) or (leaderboard.players[players[2].user_id] and leaderboard.players[players[2].user_id].placement_done)) then
      caveats[#caveats + 1] = "Note: Rating adjustments for these matches will be processed when the newcomer finishes placement."
    end
    return true, caveats
  end
end

function calculate_rating_adjustment(Rc, Ro, Oa, k) -- -- print("calculating expected outcome for") -- print(players[player_number].name.." Ranking: "..leaderboard.players[players[player_number].user_id].rating)
  --[[ --Algorithm we are implementing, per community member Bbforky:
      Formula for Calculating expected outcome:
      RATING_SPREAD_MODIFIER = 400
      Oe=1/(1+10^((Ro-Rc)/RATING_SPREAD_MODIFIER)))

      Oe= Expected Outcome
      Ro= Current rating of opponent
      Rc= Current rating

      Formula for Calculating new rating:

      Rn=Rc+k(Oa-Oe)

      Rn=New Rating
      Oa=Actual Outcome (0 for loss, 1 for win)
      k= Constant (Probably will use 10)
  ]] -- print("vs")
  -- print(players[player_number].opponent.name.." Ranking: "..leaderboard.players[players[player_number].opponent.user_id].rating)
  Oe = 1 / (1 + 10 ^ ((Ro - Rc) / RATING_SPREAD_MODIFIER))
  -- print("expected outcome: "..Oe)
  Rn = Rc + k * (Oa - Oe)
  return Rn
end

function adjust_ratings(room, winning_player_number)
  logger.info("We'd be adjusting the rating of " .. room.a.name .. " and " .. room.b.name .. ". Player " .. winning_player_number .. " wins!")
  local players = {room.a, room.b}
  local continue = true
  local placement_match_progress
  --check that it's ok to adjust ratings
  continue, reasons = room:rating_adjustment_approved()
  if continue then
    room.ratings = {}
    for player_number = 1, 2 do
      --if they aren't on the leaderboard yet, give them the default rating
      if not leaderboard.players[players[player_number].user_id] or not leaderboard.players[players[player_number].user_id].rating then
        leaderboard.players[players[player_number].user_id] = {user_name = playerbase.players[players[player_number].user_id], rating = DEFAULT_RATING}
        logger.info("Gave " .. playerbase.players[players[player_number].user_id] .. " a new rating of " .. DEFAULT_RATING)
        if not PLACEMENT_MATCHES_ENABLED then
          leaderboard.players[players[player_number].user_id].placement_done = true
        end
        write_leaderboard_file()
      end
    end
    local placement_done = {}
    for player_number = 1, 2 do
      placement_done[players[player_number].user_id] = leaderboard.players[players[player_number].user_id].placement_done
    end
    for player_number = 1, 2 do
      local k, Oa  --max point change per match, actual outcome
      room.ratings[player_number] = {}
      if placement_done[players[player_number].user_id] == true then
        k = 10
      else
        k = 50
      end
      if players[player_number].player_number == winning_player_number then
        Oa = 1
      else
        Oa = 0
      end
      if placement_done[players[player_number].user_id] then
        if placement_done[players[player_number].opponent.user_id] then
          logger.info("Player " .. player_number .. " played a non-placement ranked match.  Updating his rating now.")
          room.ratings[player_number].new = calculate_rating_adjustment(leaderboard.players[players[player_number].user_id].rating, leaderboard.players[players[player_number].opponent.user_id].rating, Oa, k)
        else
          logger.info("Player " .. player_number .. " played ranked against an unranked opponent.  We'll process this match when his opponent has finished placement")
          room.ratings[player_number].placement_matches_played = leaderboard.players[players[player_number].user_id].ranked_games_played
          room.ratings[player_number].new = round(leaderboard.players[players[player_number].user_id].rating)
          room.ratings[player_number].old = round(leaderboard.players[players[player_number].user_id].rating)
          room.ratings[player_number].difference = 0
        end
      else -- this player has not finished placement
        if placement_done[players[player_number].opponent.user_id] then
          logger.info("Player " .. player_number .. " (unranked) just played a placement match against a ranked player.")
          logger.info("Adding this match to the list of matches to be processed when player finishes placement")
          load_placement_matches(players[player_number].user_id)
          local pm_count = #loaded_placement_matches.incomplete[players[player_number].user_id]

          loaded_placement_matches.incomplete[players[player_number].user_id][pm_count + 1] = {
            op_user_id = players[player_number].opponent.user_id,
            op_name = playerbase.players[players[player_number].opponent.user_id],
            op_rating = leaderboard.players[players[player_number].opponent.user_id].rating,
            outcome = Oa
          }
          logger.debug("PRINTING PLACEMENT MATCHES FOR USER")
          logger.debug(json.encode(loaded_placement_matches.incomplete[players[player_number].user_id]))
          write_user_placement_match_file(players[player_number].user_id, loaded_placement_matches.incomplete[players[player_number].user_id])

          --adjust newcomer's placement_rating
          if not leaderboard.players[players[player_number].user_id] then
            leaderboard.players[players[player_number].user_id] = {}
          end
          leaderboard.players[players[player_number].user_id].placement_rating = calculate_rating_adjustment(leaderboard.players[players[player_number].user_id].placement_rating or DEFAULT_RATING, leaderboard.players[players[player_number].opponent.user_id].rating, Oa, PLACEMENT_MATCH_K)
          logger.info("New newcomer rating: " .. leaderboard.players[players[player_number].user_id].placement_rating)
          leaderboard.players[players[player_number].user_id].ranked_games_played = (leaderboard.players[players[player_number].user_id].ranked_games_played or 0) + 1
          if Oa == 1 then
            leaderboard.players[players[player_number].user_id].ranked_games_won = (leaderboard.players[players[player_number].user_id].ranked_games_won or 0) + 1
          end

          local process_them, reason = qualifies_for_placement(players[player_number].user_id)
          if process_them then
            local op_player_number = players[player_number].opponent.player_number
            logger.debug("op_player_number: " .. op_player_number)
            room.ratings[player_number].old = 0
            if not room.ratings[op_player_number] then
              room.ratings[op_player_number] = {}
            end
            room.ratings[op_player_number].old = round(leaderboard.players[players[op_player_number].user_id].rating)
            process_placement_matches(players[player_number].user_id)

            room.ratings[player_number].new = round(leaderboard.players[players[player_number].user_id].rating)

            room.ratings[player_number].difference = round(room.ratings[player_number].new - room.ratings[player_number].old)
            room.ratings[player_number].league = get_league(room.ratings[player_number].new)

            room.ratings[op_player_number].new = round(leaderboard.players[players[op_player_number].user_id].rating)

            room.ratings[op_player_number].difference = round(room.ratings[op_player_number].new - room.ratings[op_player_number].old)
            room.ratings[op_player_number].league = get_league(room.ratings[player_number].new)
            return
          else
            placement_match_progress = reason
          end
        else
          logger.error("Neither player is done with placement.  We should not have gotten to this line of code")
        end
        if not process_them then
          room.ratings[player_number].new = 0
          room.ratings[player_number].old = 0
          room.ratings[player_number].difference = 0
        end
      end
      logger.debug("room.ratings[" .. player_number .. "].new = " .. (room.ratings[player_number].new or ""))
    end
    --check that both player's new room.ratings are numeric (and not nil)
    if not process_them then
      for player_number = 1, 2 do
        if tonumber(room.ratings[player_number].new) then
          continue = true
        else
          logger.warn(players[player_number].name .. "'s new rating wasn't calculated properly.  Not adjusting the rating for this match")
          continue = false
        end
      end
    end
    if continue and not process_them then
      --now that both new room.ratings have been calculated properly, actually update the leaderboard
      for player_number = 1, 2 do
        logger.info(playerbase.players[players[player_number].user_id])
        logger.info("Old rating:" .. leaderboard.players[players[player_number].user_id].rating)
        room.ratings[player_number].old = leaderboard.players[players[player_number].user_id].rating
        leaderboard.players[players[player_number].user_id].ranked_games_played = (leaderboard.players[players[player_number].user_id].ranked_games_played or 0) + 1
        leaderboard:update(players[player_number].user_id, room.ratings[player_number].new)
        logger.info("New rating:" .. leaderboard.players[players[player_number].user_id].rating)
      end
      for player_number = 1, 2 do
        --round and calculate rating gain or loss (difference) to send to the clients
        if placement_done[players[player_number].user_id] then
          room.ratings[player_number].old = round(room.ratings[player_number].old or leaderboard.players[players[player_number].user_id].rating)
          room.ratings[player_number].new = round(room.ratings[player_number].new or leaderboard.players[players[player_number].user_id].rating)
          room.ratings[player_number].difference = room.ratings[player_number].new - room.ratings[player_number].old
        else
          room.ratings[player_number].old = 0
          room.ratings[player_number].new = 0
          room.ratings[player_number].difference = 0
          room.ratings[player_number].placement_match_progress = placement_match_progress
        end
        room.ratings[player_number].league = get_league(room.ratings[player_number].new)
      end
    -- msg = {rating_updates=true, ratings=room.ratings, placement_match_progress=placement_match_progress}
    -- room:send(msg)
    end
  else
    logger.info("Not adjusting ratings.  " .. reasons[1])
  end
end

function load_placement_matches(user_id)
  logger.debug("Requested loading placement matches for user_id:  " .. (user_id or "nil"))
  if not loaded_placement_matches.incomplete[user_id] then
    local read_success, matches = read_user_placement_match_file(user_id)
    if read_success then
      loaded_placement_matches.incomplete[user_id] = matches or {}
      logger.debug("loaded placement matches from file:")
    else
      loaded_placement_matches.incomplete[user_id] = {}
      logger.error("error reading placement matches file")
    end
    logger.debug(tostring(loaded_placement_matches.incomplete[user_id]))
    logger.debug(json.encode(loaded_placement_matches.incomplete[user_id]))
  else
    logger.info("Didn't load placement matches from file. It is already loaded")
  end
end

function qualifies_for_placement(user_id)
  --local placement_match_win_ratio_requirement = .2
  load_placement_matches(user_id)
  local placement_matches_played = #loaded_placement_matches.incomplete[user_id]
  if not PLACEMENT_MATCHES_ENABLED then
    return false, ""
  elseif (leaderboard.players[user_id] and leaderboard.players[user_id].placement_done) then
    return false, "user is already placed"
  elseif placement_matches_played < PLACEMENT_MATCH_COUNT_REQUIREMENT then
    return false, placement_matches_played .. "/" .. PLACEMENT_MATCH_COUNT_REQUIREMENT .. " placement matches played."
  -- else
  -- local win_ratio
  -- local win_count
  -- for i=1,placement_matches_played do
  -- win_count = win_count + loaded_placement_matches.incomplete[user_id][i].outcome
  -- end
  -- win_ratio = win_count / placement_matches_played
  -- if win_ratio < placement_match_win_ratio_requirement then
  -- return false, "placement win ratio is currently "..round(win_ratio*100).."%.  "..round(placement_match_win_ratio_requirement*100).."% is required for placement."
  -- end
  end
  return true
end

function process_placement_matches(user_id)
  local rating = DEFAULT_RATING
  local k = 20 -- adjusts max points gained or lost per match
  load_placement_matches(user_id)
  local placement_matches = loaded_placement_matches.incomplete[user_id]
  if #placement_matches < 1 then
    logger.error("Failed to process placement matches because we couldn't find any")
    return
  end

  --[[We are moving some of this code such that placement_rating for the newcomer is calculated as the placement matches are played, rather than at the end of placement.
  --Calculate newcomer's rating
  for i=1, #placement_matches do
    print("Newcomer: "..leaderboard.players[user_id].rating.." "..placement_matches[i].op_name..": "..placement_matches[i].op_rating.." Outcome: "..placement_matches[i].outcome)
    rating = calculate_rating_adjustment(rating, placement_matches[i].op_rating, placement_matches[i].outcome, k)
    print("New newcomer rating: "..rating)
  end
  leaderboard.players[user_id].user_name = playerbase.players[user_id]
  leaderboard.players[user_id].rating = rating
  --local win_ratio
  local win_count = 0
  for i=1,#loaded_placement_matches.incomplete[user_id] do
    win_count = win_count + loaded_placement_matches.incomplete[user_id][i].outcome
  end
  leaderboard.players[user_id].ranked_games_played = #loaded_placement_matches.incomplete[user_id]
  leaderboard.players[user_id].ranked_games_won = win_count
  --win_ratio = win_count / placement_matches_played  -- TODO: perhaps record this
  leaderboard.players[user_id].placement_rating = rating
  --]]
  --assign the current placement_rating as the newcomer's official rating.
  leaderboard.players[user_id].rating = leaderboard.players[user_id].placement_rating
  leaderboard.players[user_id].placement_done = true
  logger.info("FINAL PLACEMENT RATING for " .. (playerbase.players[user_id] or "nil") .. ": " .. leaderboard.players[user_id].rating or "nil")

  --Calculate changes to opponents ratings for placement matches won/lost
  logger.info("adjusting opponent rating(s) for these placement matches")
  for i = 1, #placement_matches do
    if placement_matches[i].outcome == 0 then
      op_outcome = 1
    else
      op_outcome = 0
    end
    local op_rating_change = calculate_rating_adjustment(placement_matches[i].op_rating, leaderboard.players[user_id].placement_rating, op_outcome, 10) - placement_matches[i].op_rating
    leaderboard.players[placement_matches[i].op_user_id].rating = leaderboard.players[placement_matches[i].op_user_id].rating + op_rating_change
    leaderboard.players[placement_matches[i].op_user_id].ranked_games_played = (leaderboard.players[placement_matches[i].op_user_id].ranked_games_played or 0) + 1
    leaderboard.players[placement_matches[i].op_user_id].ranked_games_won = (leaderboard.players[placement_matches[i].op_user_id].ranked_games_won or 0) + op_outcome
  end
  leaderboard.players[user_id].placement_done = true
  write_leaderboard_file()
  move_user_placement_file_to_complete(user_id)
end

function get_league(rating)
  if not rating then
    return leagues[1].league --("Newcomer")
  end
  for i = 1, #leagues do
    if i == #leagues or leagues[i + 1].min_rating > rating then
      return leagues[i].league
    end
  end
  return "LeagueNotFound"
end

-- got pong
function Connection.F(self, message)
end

local ok_ncolors = {}
for i = 2, 7 do
  ok_ncolors[i .. ""] = true
end
function Connection.P(self, message)
  if not ok_ncolors[message[1]] then
    return
  end
  local ncolors = 0 + message[1]
  local ret = make_panels(ncolors, string.sub(message, 2, 7), self)
  if self.first_seven and self.opponent and ((self.level < 9 and self.opponent.level < 9) or (self.level >= 9 and self.opponent.level >= 9)) then
    self.opponent.first_seven = self.first_seven
  end
  self:send("P" .. ret)
  if self.player_number == 1 then
    self.room:send_to_spectators("P" .. ret)
    self.room.replay.vs.P = self.room.replay.vs.P .. ret
  elseif self.player_number == 2 then
    self.room:send_to_spectators("O" .. ret)
    self.room.replay.vs.O = self.room.replay.vs.O .. ret
  end
  if self.opponent then
    self.opponent:send("O" .. ret)
  end
end

function Connection.Q(self, message)
  if not ok_ncolors[message[1]] then
    return
  end
  local ncolors = 0 + message[1]
  local ret = make_gpanels(ncolors, string.sub(message, 2, 7))
  self:send("Q" .. ret)
  if self.player_number == 1 then
    self.room:send_to_spectators("Q" .. ret)
    self.room.replay.vs.Q = self.room.replay.vs.Q .. ret
  elseif self.player_number == 2 then
    self.room:send_to_spectators("R" .. ret)
    self.room.replay.vs.R = self.room.replay.vs.R .. ret
  end
  if self.opponent then
    self.opponent:send("R" .. ret)
  end
end

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
    elseif name_to_idx[message.name] then
      logger.info("connection sent name: " .. message.name)
      local names = {}
      for _, v in pairs(connections) do
        names[#names + 1] = v.name -- fine if name is nil :o
      end
      response = {choose_another_name = {used_names = names}}
      self:send(response)
    elseif message.name:find("[^_%w]") then
      response = {choose_another_name = {reason = "Usernames are limited to alphanumeric and underscores"}}
      self:send(response)
    elseif string.len(message.name) > NAME_LENGTH_LIMIT then
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
      self.save_replays_publicly = message.save_replays_publicly
      self.wants_ranked_match = message.ranked
      lobby_changed = true
      self.state = "lobby"
      name_to_idx[self.name] = self.index
    end
  elseif message.taunt then
    message.player_number = self.player_number
    self.opponent:send(message)
    self.room:send_to_spectators(message)
  elseif message.login_request then
    self:login(message.user_id)
  elseif message.logout then
    self:close()
  elseif self.state == "lobby" and message.game_request then
    if message.game_request.sender == self.name then
      propose_game(message.game_request.sender, message.game_request.receiver, message)
    end
  elseif message.leaderboard_request then
    self:send({leaderboard_report = leaderboard:get_report(self)})
  elseif message.spectate_request then
    local requestedRoom = roomNumberToRoom(message.spectate_request.roomNumber)
    if self.state ~= "lobby" then
      if requestedRoom then
        logger.info("removing " .. self.name .. " from room nr " .. message.spectate_request.roomNumber)
        requestedRoom:remove_spectator()
      else
        logger.warn("could not find room to remove " .. self.name)
        self.state = "lobby"
      end
    end
    if requestedRoom and requestedRoom:state() == CHARACTERSELECT then
      -- TODO: allow them to join
      logger.info("join allowed")
      logger.info("adding " .. self.name .. " to room nr " .. message.spectate_request.roomNumber)
      requestedRoom:add_spectator(self)
    elseif requestedRoom and requestedRoom:state() == PLAYING then
      logger.info("join-in-progress allowed")
      logger.info("adding " .. self.name .. " to room nr " .. message.spectate_request.roomNumber)
      requestedRoom:add_spectator(self)
    else
      -- TODO: tell the client the join request failed, couldn't find the room.
      logger.warn("couldn't find room")
    end
  elseif self.state == "character select" and message.menu_state then
    self.level = message.menu_state.level
    self.character = message.menu_state.character
    self.character_is_random = message.menu_state.character_is_random
    self.character_display_name = message.menu_state.character_display_name
    self.stage = message.menu_state.stage
    self.stage_is_random = message.menu_state.stage_is_random
    self.ready = message.menu_state.ready
    self.cursor = message.menu_state.cursor
    self.panels_dir = message.menu_state.panels_dir
    self.wants_ranked_match = message.menu_state.ranked
    logger.info("about to check for rating_adjustment_approval for " .. self.name .. " and " .. self.opponent.name)
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
        P1_char = self.room.a.character,
        P2_char = self.room.b.character,
        ranked = self.room:rating_adjustment_approved(),
        do_countdown = true
      }
      if self.player_number == 1 then
        start_match(self, self.opponent)
      else
        start_match(self.opponent, self)
      end
    else
      self.opponent:send(message)
      message.player_number = self.player_number
      logger.info("about to send match start to spectators of " .. (self.name or "nil") .. " and " .. (self.opponent.name or "nil"))
      self.room:send_to_spectators(message) -- TODO: may need to include in the message who is sending the message
    end
  elseif self.state == "playing" and message.game_over then
    self.room.game_outcome_reports[self.player_number] = message.outcome
    if self.room:resolve_game_outcome() then
      logger.info("\n*******************************")
      logger.info("***" .. self.room.a.name .. " " .. self.room.win_counts[1] .. " - " .. self.room.win_counts[2] .. " " .. self.room.b.name .. "***")
      logger.info("*******************************\n")
      self.room.game_outcome_reports = {}
      self.room:character_select()
    end
  elseif (self.state == "playing" or self.state == "character select") and message.leave_room then
    --[[local msg = lobby_state()
    msg.leave_room = true
    self:send(msg)
    op:send(msg)--]]
    local op = self.opponent
    self:opponent_disconnected()
    op:opponent_disconnected()
    if self.room and self.room.spectators then
      for k, v in pairs(self.room.spectators) do
        v:opponent_disconnected()
      end
    end
  elseif (self.state == "spectating") and message.leave_room then
    self.room:remove_spectator(self)
  end
end

-- TODO: this should not be O(n^2) lol
function Connection.data_received(self, data)
  self.last_read = time()
  if data:len() ~= 2 and data[1] ~= "F" then
    logger.trace("got raw data " .. data)
  end
  data = self.leftovers .. data
  local idx = 1
  while data:len() > 0 do
    --assert(type(data) == "string")
    local msg_type = data[1]
    --assert(type(msg_type) == "string")
    if msg_type == "J" then
      if data:len() < 4 then
        break
      end
      local msg_len = byte(data[2]) * 65536 + byte(data[3]) * 256 + byte(data[4])
      if data:len() < 4 + msg_len then
        break
      end
      local jmsg = data:sub(5, msg_len + 4)
      logger.debug("got JSON message " .. jmsg)
      logger.debug(
        "Pcall results for json: ",
        pcall(
          function()
            self:J(jmsg)
          end
        )
      )
      data = data:sub(msg_len + 5)
    else
      if msg_type ~= "I" and msg_type ~= "F" then
        logger.trace("using non-J type " .. msg_type)
      end
      total_len = type_to_length[msg_type]
      if not total_len then
        logger.warn("closing because len did not exist")
        self:close()
        return
      end
      if data:len() < total_len then
        logger.warn("breaking because len was too small")
        break
      end
      res = {
        pcall(
          function()
            self[msg_type](self, data:sub(2, total_len))
          end
        )
      }
      if (msg_type ~= "I" and msg_type ~= "F") or not res[1] then
        logger.trace("got message " .. msg_type .. " " .. data:sub(2, total_len))
        logger.trace("Pcall results for " .. msg_type .. ": ", unpack(res))
      end
      data = data:sub(total_len + 1)
    end
  end
  self.leftovers = data
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

function broadcast_lobby()
  if lobby_changed then
    for _, v in pairs(connections) do
      if v.state == "lobby" then
        v:send(lobby_state())
      end
    end
    lobby_changed = false
  end
end

--[[function process_game_over_message(sender, message)
  sender.room.game_outcome_reports[sender.player_number] = {i_won=message.i_won, tie=message.tie}
  print("processing game_over message. Sender: "..sender.name)
  local reports = sender.room.game_outcome_reports
  if not reports[sender.opponent.player_number] then
    sender.room.game_outcome_reports["official outcome"] = "pending other player's report"
  elseif reports[1].tie and reports[2].tie then
    sender.room.game_outcome_reports["official outcome"] = "tie"
  elseif reports[1].i_won ~= not reports[2].i_won or reports[1].tie ~= reports[2].tie then
    sender.room.game_outcome_reports["official outcome"] = "clients disagree"
  elseif reports[1].i_won then
    sender.room.game_outcome_reports["official outcome"] = 1
  elseif reports[2].i_won then
    sender.room.game_outcome_reports["official outcome"] = 2
  else
    print("Error: nobody won or tied?")
  end
  print("process_game_over_message outcome for "..sender.room.name..": "..sender.room.game_outcome_reports["official outcome"])
end
--]]
local server_socket = socket.bind("*", SERVER_PORT or 49569) --for official server
--local server_socket = socket.bind("*", 59569) --for beta server
server_socket:settimeout(0)
if TCP_NODELAY_ENABLED then
  server_socket:setoption("tcp-nodelay", true)
end
local sep = package.config:sub(1, 1)
logger.info("sep: " .. sep)
playerbase = Playerbase("playerbase")
read_players_file()
read_deleted_players_file()
leaderboard = Leaderboard("leaderboard")
read_leaderboard_file()
for k, v in pairs(playerbase.players) do
  if leaderboard.players[k] then
    leaderboard.players[k].user_name = v
  end
end
logger.info("leaderboard json:")
logger.info(json.encode(leaderboard.players))
write_leaderboard_file()
logger.info("Leagues")
for k, v in ipairs(leagues) do
  logger.info(v.league .. ":  " .. v.min_rating)
end
logger.info(os.time())
--TODO: remove test print for leaderboard
logger.info("playerbase: " .. json.encode(playerbase.players))
logger.info("leaderboard report: " .. json.encode(leaderboard:get_report()))
read_csprng_seed_file()
if csprng_seed == 2000 then
  logger.warn("ALERT! YOU SHOULD CHANGE YOUR CSPRNG_SEED.TXT FILE TO MAKE YOUR USER_IDS MORE SECURE!")
end
initialize_mt_generator(csprng_seed)
seed_from_mt(extract_mt())
ban_list = {}
--timezone testing
-- print("server_UTC_offset (in seconds) is "..tzoffset)
-- print("that's "..(tzoffset/3600).." hours")
-- local server_start_time = os.time()
-- print("current local time: "..server_start_time)
-- print("current UTC time: "..to_UTC(server_start_time))
-- local now = os.date("*t")
-- local formatted_local_time = string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
-- print("formatted local time: "..formatted_local_time)
-- now = os.date("*t",to_UTC(server_start_time))
-- local formatted_UTC_time = string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)
-- print("formatted UTC time: "..formatted_UTC_time)
logger.debug("RATING_SPREAD_MODIFIER: " .. (RATING_SPREAD_MODIFIER or "nil"))
logger.debug("COMPRESS_REPLAYS_ENABLED: " .. (COMPRESS_REPLAYS_ENABLED and "true" or "false"))
logger.info("initialized!")
-- print("get_timezone() output: "..get_timezone())
-- print("get_timezone_offset(os.time()) output: "..get_timezone_offset(os.time()))
-- print("get_tzoffset(get_timezone()) output:"..get_tzoffset(get_timezone()))

local prev_now = time()
while true do
  server_socket:settimeout(0)
  if TCP_NODELAY_ENABLED then
    server_socket:setoption("tcp-nodelay", true)
  end
  local new_conn = server_socket:accept()
  if new_conn then
    new_conn:settimeout(0)
    if TCP_NODELAY_ENABLED then
      new_conn:setoption("tcp-nodelay", true)
    end
    Connection(new_conn)
  end
  local recvt = {server_socket}
  for _, v in pairs(connections) do
    recvt[#recvt + 1] = v.socket
  end
  local ready = socket.select(recvt, nil, 1)
  assert(type(ready) == "table")
  for _, v in ipairs(ready) do
    if socket_to_idx[v] then
      connections[socket_to_idx[v]]:read()
    end
  end
  local now = time()
  if now ~= prev_now then
    for _, v in pairs(connections) do
      if now - v.last_read > 10 then
        logger.warn("about to close connection for " .. (v.name or "nil") .. ". Connection timed out (>10 sec)")
        v:close()
      elseif now - v.last_read > 1 then
        v:send("ELOL")
      end
    end
    prev_now = now
  end
  broadcast_lobby()
end

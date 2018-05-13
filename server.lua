require("socket")
require("class")
json = require("dkjson")
require("stridx")
require("gen_panels")
require("csprng")
require("server_file_io")

local byte = string.byte
local char = string.char
local pairs = pairs
local ipairs = ipairs
local random = math.random
local lobby_changed = false
local time = os.time
local floor = math.floor
local TIMEOUT = 10
local CHARACTERSELECT = "joinable" -- room states
local PLAYING = "playing, not joinable" -- room states


local VERSION = "019"
local type_to_length = {H=4, E=4, F=4, P=8, I=2, L=2, Q=8, U=2}
local INDEX = 1
local connections = {}
local ROOMNUMBER = 1
local rooms = {}
local name_to_idx = {}
local socket_to_idx = {}
local proposals = {}
local playerbases = {}

function lobby_state()
  local names = {}
  for _,v in pairs(connections) do
    if v.state == "lobby" then
      names[#names+1] = v.name
    end
  end
  local spectatableRooms = {}
  for _,v in pairs(rooms) do
	  spectatableRooms[#spectatableRooms+1] = {roomNumber = v.roomNumber, name = v.name , a = v.a.name, b = v.b.name, state = v:state()}
  end
  return {unpaired = names, spectatable = spectatableRooms}
end

function propose_game(sender, receiver, message)
  local s_c, r_c = name_to_idx[sender], name_to_idx[receiver]
  if s_c then s_c = connections[s_c] end
  if r_c then r_c = connections[r_c] end
  if s_c and s_c.state == "lobby" and r_c and r_c.state == "lobby" then
    proposals[sender] = proposals[sender] or {}
    proposals[receiver] = proposals[receiver] or {}
    if proposals[sender][receiver] then
      if proposals[sender][receiver][receiver] then
        create_room(s_c, r_c)
      end
    else
      r_c:send(message)
      local prop = {[sender]=true}
      proposals[sender][receiver] = prop
      proposals[receiver][sender] = prop
    end
  end
end

function clear_proposals(name)
  if proposals[name] then
    for othername,_ in pairs(proposals[name]) do
      proposals[name][othername] = nil
      proposals[othername][name] = nil
    end
    proposals[name] = nil
  end
end

function create_room(a, b)
  lobby_changed = true
  clear_proposals(a.name)
  clear_proposals(b.name)
  a.state = "room"
  b.state = "room"
  if a.player_number and a.player_number ~= 0 and a.player_number ~= 1 then
    print("creating room. player a does not have player_number 1. Swapping players a and b")
	a, b = b, a
	if a.player_number == 1 then
	  print("Success. player a has player_number 1 now.")
	else
	  print("ERROR. Player a still doesn't have player_number 1")
	end
  else
    a.player_number = 1
    b.player_number = 2
  end
  a.cursor = "level"
  b.cursor = "level"
  a.ready = false
  b.ready = false
  if not a.room then
    Room(a,b)
  end
  local a_msg, b_msg = {create_room = true}, {create_room = true}
  a_msg.opponent = b.name
  a_msg.menu_state = b:menu_state()
  b_msg.opponent = a.name
  b_msg.menu_state = a:menu_state()
  a.opponent = b
  b.opponent = a
  a:send(a_msg)
  b:send(b_msg)
  a.room:reinvite_spectators()
end


function start_match(a, b)
  if (a.player_number ~= 1) then
    print("Match starting, players a and b need to be swapped.")
    a, b = b, a
	if(a.player_number == 1) then
	  print("Success, player a now has player_number 1.")
	else
	  print("ERROR: player a still doesn't have player_number 1.")
	end
  end
  
  local msg = {match_start = true,
                player_settings = {character = a.character, level = a.level, player_number = a.player_number},
                opponent_settings = {character = b.character, level = b.level, player_number = b.player_number}}
  a:send(msg)
  a.room:send_to_spectators(msg)
  msg.player_settings, msg.opponent_settings = msg.opponent_settings, msg.player_settings
  b:send(msg)
  lobby_changed = true
  a:setup_game()
  b:setup_game()
  for k,v in ipairs(a.room.spectators) do
	v:setup_game()
  end
end

Room = class(function(self, a, b)
  self.a = a --player a
  self.b = b --player b
  self.name = a.name.." vs "..b.name
  if not self.a.room then
	self.roomNumber = ROOMNUMBER
	ROOMNUMBER = ROOMNUMBER + 1
	self.a.room = self
	self.b.room = self
	self.spectators = {}
	self.win_counts = {}
	self.win_counts[1] = 0
	self.win_counts[2] = 0
  else
    self.win_counts = self.a.room.win_counts
	self.spectators = self.a.room.spectators
	self.roomNumber = self.a.room.roomNumber
  end
  self.game_outcome_reports = {}
  rooms[self.roomNumber] = self
end)

function Room.state(self)
  if self.a.state == "room" then
    return CHARACTERSELECT
  elseif self.a.state == "playing" then
    return PLAYING
  else
    return self.a.state
  end
end

function Room.is_spectatable(self)
  return self.a.state == "room"
end

function Room.add_spectator(self, new_spectator_connection)
  new_spectator_connection.state = "spectating"
  new_spectator_connection.room = self
  self.spectators[#self.spectators+1] = new_spectator_connection
  print(new_spectator_connection.name .. " joined " .. self.name .. " as a spectator")
  
  msg = {spectate_request_granted = true, spectate_request_rejected = false, a_menu_state=self.a:menu_state(), b_menu_state=self.b:menu_state(), win_counts=self.win_counts}
  new_spectator_connection:send(msg)

  
end

function Room.reinvite_spectators(self)
  msg = {spectate_request_granted = true, spectate_request_rejected = false, a_menu_state=self.a:menu_state(), b_menu_state=self.b:menu_state()}
  for k,v in ipairs(self.spectators) do
	self.spectators[k]:send(msg)
  end
end

function Room.remove_spectator(self, connection)
  for k,v in ipairs(self.spectators) do
	if v.name == connection.name then
	  self.spectators[k].state = "lobby"
	  print(connection.name .. " left " .. self.name .. " as a spectator")
	  self.spectators[k] = nil
	  lobby_changed = true
	  connection:send(lobby_state())
	end
  end
end

function Room.close(self)
	--TODO: notify spectators that the room has closed.
	if self.a then
	  self.a.player_number = 0
	end
	if self.b then
	  self.b.player_number = 0
	end
	if rooms[self.roomNumber] then
		rooms[self.roomNumber] = nil
	end
	local msg = lobby_state()
	msg.leave_room = true
	self:send_to_spectators(msg)
end

function roomNumberToRoom(roomNr)
  for k,v in pairs(rooms) do
    if rooms[k].roomNumber and rooms[k].roomNumber == roomNr then
      return v
    end
  end
end

--TODO: maybe support multiple playerbases 
Playerbase = class(function (s, name)
  s.name = name
  s.players = {}--{["e2016ef09a0c7c2fa70a0fb5b99e9674"]="Bob",
			   --["d28ac48ba5e1a82e09b9579b0a5a7def"]="Alice"}
  s.deleted_players = {}
  playerbases[#playerbases+1] = s
end)

function Playerbase.add_player(self, user_id, user_name)
  self.players[user_id] = user_name
  write_players_file()
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
  print("new_user_id: "..new_user_id)
  return tostring(new_user_id)
end

--TODO: support multiple leaderboards
Leaderboard = class(function (s, name)
  s.name = name
  s.players = {}
end)

function Leaderboard.update(self, user_id, new_ranking)
  if self.players[user_id] then
    self.players[user_id].ranking = new_ranking
  else
    self.players[user_id] = {ranking=new_ranking}
  end
  write_leaderboard_file()
end

function Leaderboard.get_report(self)
--returns the leaderboard as an array sorted from highest ranking to lowest, 
--with usernames from playerbase.players instead of user_ids
--ie report[1] will give the highest ranking player's user_name and how many points they have. Like this:
--report[1] might return {user_name="Alice",ranking=2250}
--report[2] might return {user_name="Bob",ranking=2100}
  local report = {}
  local leaderboard_player_count = 0
  --count how many entries there are in self.players since #self.players will not give us an accurate answer for sparse tables
  for k,v in pairs(self.players) do
    leaderboard_player_count = leaderboard_player_count + 1
  end
  for k,v in pairs(self.players) do
	for insert_index=1, leaderboard_player_count do
      if playerbase.players[k] then --only include in the report players who are still listed in the playerbase
		if v.ranking then -- don't include entries who's ranking is nil (which shouldn't happen anyway)
		  if report[insert_index] and report[insert_index].ranking and v.ranking >= report[insert_index].ranking then
			table.insert(report, insert_index, {user_name=playerbase.players[k],ranking=v.ranking})
			break
		  elseif insert_index == leaderboard_player_count or #report == 0 then
			table.insert(report, {user_name=playerbase.players[k],ranking=v.ranking}) -- at the end of the table.
		    break
		  end
		end
	  end
	end
  end
  return report
end

Connection = class(function(s, socket)
  s.index = INDEX
  INDEX = INDEX + 1
  connections[s.index] = s
  socket_to_idx[socket] = s.index
  s.socket = socket
  socket:settimeout(0)
  s.leftovers = ""
  s.state = "needs_name"
  s.room = nil
  s.last_read = time()
  s.player_number = 0  -- 0 if not a player in a room, 1 if player "a" in a room, 2 if player "b" in a room
  s.logged_in = false --whether connection has successfully logged into the ranking system.
  s.user_id = nil
end)

function Connection.menu_state(self)
  return {cursor=self.cursor, ready=self.ready, character=self.character, level=self.level, player_number=self.player_number}
  --note: player_number here is the player_number of the connection as according to the server, not the "which" of any Stack
end

function Connection.send(self, stuff)
  if type(stuff) == "table" then
    local json = json.encode(stuff)
    local len = json:len()
    local prefix = "J"..char(floor(len/65536))..char(floor((len/256)%256))..char(len%256)
    print(byte(prefix[1]), byte(prefix[2]), byte(prefix[3]), byte(prefix[4]))
    print("sending json "..json)
    stuff = prefix..json
  else
    if stuff[1] ~= "I" and stuff[1] ~= "U" then
      print("sending non-json "..stuff)
    end
  end
  local foo = {self.socket:send(stuff)}
  if stuff[1] ~= "I" and stuff[1] ~= "U" then
    print(unpack(foo))
  end
  if not foo[1] then
    self:close()
  end
end

function Connection.login(self, user_id)
  --returns whether the login was successful
  --print("Connection.login was called!")
  self.user_id = user_id
  if not self.user_id then
    local the_reason = "Client did not send a user_id in the login request"
    self:send({login_denied=true, login_successful=false, reason=the_reason})
	print("Login denied.  Reason:  "..the_reason)
	success = false
  end
  if self.user_id == "need a new user id" and self.name then
    print(self.name.." needs a new user id!")
    local their_new_user_id
	while not their_new_user_id or playerbase.players[their_new_user_id] do
	  their_new_user_id = generate_new_user_id()
	end
	playerbase:add_player(their_new_user_id, self.name)
	self:send({login_successful=true, new_user_id=their_new_user_id})
	self.user_id = their_new_user_id
	print("Connection with name "..self.name.." was assigned a new user_id")
  end
  if not self.name then
    self:send({login_successful=false, login_denied=true, reason="Player has no name"})
	print("Login failure: Player has no name")
	return false
  elseif not playerbase.players[self.user_id] then
    self:send({login_successful=false, login_denied=true, reason="The user_id provided was not found on this server"})
	print("Login failure: "..self.name.." specified an invalid user_id")
	return false
  elseif playerbase.players[self.user_id] ~= self.name then
    local the_old_name = playerbase.players[self.user_id]
    playerbase.players[self.user_id] = self.name
	self.logged_in = true
	self:send({login_successful=true, name_changed=true , old_name=the_old_name, new_name=self.name})
	print("Login successful and changed name "..the_old_name.." to "..self.name)
  elseif playerbase.players[self.user_id] then
    self.logged_in = true
	self:send({login_successful=true})
  else
    local the_reason = "unknown"
    self:send({login_denied=true, login_successful=false, reason=the_reason})
	print("login denied.  Reason:  "..the_reason)
  end
  return self.logged_in
end

function Connection.opponent_disconnected(self)
  self.opponent = nil
  self.state = "lobby"
  lobby_changed = true
  local msg = lobby_state()
  msg.leave_room = true
  if self.room then
	self.room:close()
  end
  self:send(msg)
end

function Connection.setup_game(self)
  if self.state ~= "spectating" then
    self.state = "playing"
  end
  lobby_changed = true --TODO: remove this line when we implement joining games in progress
  self.vs_mode = true
  self.metal = false
  self.rows_left = 14+random(1,8)
  self.prev_metal_col = nil
  self.metal_col = nil
  self.first_seven = nil
end

function Connection.close(self)
  if self.state == "lobby" then
    lobby_changed = true
  end
  if self.room and (self.room.a.name == self.name or self.room.b.name == self.name) then
    self.room:close()
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
  if version ~= VERSION then
    self:send("N")
  else
    self:send("H")
  end
end

function Connection.I(self, message)
  if self.opponent then
    self.opponent:send("I"..message)
	if self.player_number == 1 then
	  self.room:send_to_spectators("U"..message)
	elseif self.player_number == 2 then
	  self.room:send_to_spectators("I"..message)
	end
  end
end

function Room.send_to_spectators(self, message)
  --TODO: maybe try to do this in a different thread?
  for k,v in ipairs(self.spectators) do
	v:send(message)
  end
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
		  print("clients "..self.a.name.." and "..self.b.name.." disagree on their game outcome. So the server will decide.")
		  outcome = 0
	  else
		outcome = self.game_outcome_reports[1]
	  end
	  print("resolve_game_outcome says: "..outcome)
	  --outcome is the player number of the winner, or 0 for a tie
	  if outcome == 0 then
	    print("tie.  Nobody scored")
	    --do nothing. no points or ranking adjustments for ties.
		return true
	  else
		local someone_scored = false
	    for i=1,2,1--[[or Number of players if we implement more than 2 players]] do
		  print("checking if player "..i.." scored...")
		  if outcome == i then
		    print("Player "..i.." scored")
			self.win_counts[i] = self.win_counts[i] + 1
			adjust_ranking(self, i)
			someone_scored = true
		  end
		end
		if someone_scored then
		  local msg = {win_counts=self.win_counts}
		  self.a:send(msg)
		  self.b:send(msg)
		  self:send_to_spectators(msg)
		end
	    return true
	  end
  end
end

function adjust_ranking(room, winning_player_number)
	--for now, do nothing
	--compare player's difficulty levels, don't adjust rank if they are different
	--check that both players have indicated they wanted a ranked match?
	print("We'd be adjusting the ranking of "..room.a.name.." and "..room.b.name..". Player "..winning_player_number.." wins!")
end

-- got pong
function Connection.F(self, message)
end


local ok_ncolors = {}
for i=2,7 do
  ok_ncolors[i..""] = true
end
function Connection.P(self, message)
  if not ok_ncolors[message[1]] then return end
  local ncolors = 0 + message[1]
  local ret = make_panels(ncolors, string.sub(message, 2, 7), self)
  if self.first_seven and self.opponent and 
      ((self.level < 9 and self.opponent.level < 9) or
       (self.level >= 9 and self.opponent.level >= 9)) then
    self.opponent.first_seven = self.first_seven
  end
  self:send("P"..ret)
  if self.player_number == 1 then
    self.room:send_to_spectators("P"..ret)
  elseif self.player_number == 2 then
    self.room:send_to_spectators("O"..ret)
  end
  if self.opponent then
    self.opponent:send("O"..ret)
  end
end

function Connection.Q(self, message)
  if not ok_ncolors[message[1]] then return end
  local ncolors = 0 + message[1]
  local ret = make_gpanels(ncolors, string.sub(message, 2, 7))
  self:send("Q"..ret)
  if self.player_number == 1 then
    self.room:send_to_spectators("Q"..ret)
  elseif self.player_number == 2 then
    self.room:send_to_spectators("R"..ret)
  end
  if self.opponent then
    self.opponent:send("R"..ret)
  end
end

function Connection.J(self, message)
  message = json.decode(message)
  local response
  if self.state == "needs_name" and message.name then
    if name_to_idx[message.name] then
      local names = {}
      for _,v in pairs(connections) do
        names[#names+1] = v.name -- fine if name is nil :o
      end
      response = {choose_another_name = {used_names = names}}
      self:send(response)
    else
      self.name = message.name
      self.character = message.character
      self.level = message.level
      lobby_changed = true
      self.state = "lobby"
      name_to_idx[self.name] = self.index
    end
  elseif message.login_request then
	self:login(message.user_id)
  elseif self.state == "lobby" and message.game_request then
    if message.game_request.sender == self.name then
      propose_game(message.game_request.sender, message.game_request.receiver, message)
    end
  elseif self.state == "lobby" and message.spectate_request then
	local requestedRoom = roomNumberToRoom(message.spectate_request.roomNumber)
    if requestedRoom and requestedRoom:state() == CHARACTERSELECT then
	-- TODO: allow them to join
	  print("join allowed")
	 requestedRoom:add_spectator(connections[name_to_idx[message.spectate_request.sender]])
	  
	elseif requestedRoom and requestedRoom:state() == "playing, not joinable" then
	-- TODO: deny the join request, maybe queue them to join as soon as the status changes from "playing" to "room"
	  print("join denied")
	else
	-- TODO: tell the client the join request failed, couldn't find the room.
	  print("couldn't find room")
	end
  elseif self.state == "room" and message.menu_state then
    message.menu_state.player_number = self.player_number
	self.level = message.menu_state.level
    self.character = message.menu_state.character
    self.ready = message.menu_state.ready
    self.cursor = message.menu_state.cursor
    if self.ready and self.opponent.ready then
		if self.player_number == 1 then
		  start_match(self, self.opponent)
		else
		  start_match(self.opponent, self)
		end
    else
      self.opponent:send(message)
	  self.room:send_to_spectators(message) -- TODO: may need to include in the message who is sending the message
    end
  elseif self.state == "playing" and message.game_over then
	self.room.game_outcome_reports[self.player_number] = message.outcome
	  if self.room:resolve_game_outcome() then
	    
		print("\n*******************************")
		print("***"..self.room.a.name.." ".. self.room.win_counts[1].." - "..self.room.win_counts[2].." "..self.room.b.name.."***")
		print("*******************************\n")
		self.room.game_outcome_reports = {}
	    create_room(self, self.opponent)
	  end
  elseif (self.state == "playing" or self.state == "room") and message.leave_room then
    local op = self.opponent
    self:opponent_disconnected()
    op:opponent_disconnected()
  elseif (self.state == "spectating") and message.leave_room then
	self.room:remove_spectator(self)
  end
end

-- TODO: this should not be O(n^2) lol
function Connection.data_received(self, data)
  self.last_read = time()
  if data:len() ~= 2 then
    print("got raw data "..data)
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
      local msg_len = byte(data[2])*65536 + byte(data[3])*256 + byte(data[4])
      if data:len() < 4 + msg_len then
        break
      end
      local jmsg = data:sub(5, msg_len+4)
      print("got JSON message "..jmsg)
      print("Pcall results for json: ", pcall(function()
        self:J(jmsg)
      end))
      data = data:sub(msg_len+5)
    else
      if msg_type ~= "I" then
        print("using non-J type "..msg_type)
      end
      total_len = type_to_length[msg_type]
      if not total_len then
        print("closing because len did not exist")
        self:close()
        return
      end
      if data:len() < total_len then
        print("breaking because len was too small")
        break
      end
      res = {pcall(function()
        self[msg_type](self, data:sub(2,total_len))
      end)}
      if msg_type ~= "I" or not res[1] then
        print("got message "..msg_type.." "..data:sub(2,total_len))
        print("Pcall results for "..msg_type..": ", unpack(res))
      end
      data = data:sub(total_len+1)
    end
  end
  self.leftovers = data
end

function Connection.read(self)
  local junk, err, data = self.socket:receive("*a")
  if not err then
    error("shitfuck")
  end
  if data and data:len() > 0 then
    self:data_received(data)
  end
end

function broadcast_lobby()
  if lobby_changed then
    for _,v in pairs(connections) do
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

local server_socket = socket.bind("localhost", 49569)
playerbase = Playerbase("playerbase")
read_players_file()
read_deleted_players_file()
leaderboard = Leaderboard("leaderboard")
read_leaderboard_file()
--TODO: remove test print for leaderboard
print("playerbase: "..json.encode(playerbase.players))
print("leaderboard report: "..json.encode(leaderboard:get_report()))
initialize_mt_generator(2000) --TODO: load a different number from a csprng_seed.txt file.
seed_from_mt(extract_mt())
print("initialized!")

local prev_now = time()
while true do
  server_socket:settimeout(0)
  local new_conn = server_socket:accept()
  if new_conn then
    Connection(new_conn)
  end
  local recvt = {server_socket}
  for _,v in pairs(connections) do
    recvt[#recvt+1] = v.socket
  end
  local ready = socket.select(recvt, nil, 1)
  assert(type(ready) == "table")
  for _,v in ipairs(ready) do
    if socket_to_idx[v] then
      connections[socket_to_idx[v]]:read()
    end
  end
  local now = time()
  if now ~= prev_now then
    for _,v in pairs(connections) do
      if now - v.last_read > 10 then
        v:close()
      elseif now - v.last_read > 1 then
        v:send("ELOL")
      end
    end
    prev_now = now
  end
  broadcast_lobby()
end

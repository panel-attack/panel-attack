local socket = require("socket")
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
local DEFAULT_RATING = 1500
local NAME_LENGTH_LIMIT = 16
local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")


local VERSION = "024"
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
  local new_room = Room(a,b)
  local a_msg, b_msg = {create_room = true}, {create_room = true}
  a_msg.your_player_number = 1
  a_msg.op_player_number = 2
  a_msg.opponent = new_room.b.name
  a_msg.menu_state = new_room.b:menu_state()
  b_msg.your_player_number = 2
  b_msg.op_player_number = 1
  b_msg.opponent = new_room.a.name
  b_msg.menu_state = new_room.a:menu_state()
  a_msg.ratings = new_room.ratings
  b_msg.ratings = new_room.ratings
  new_room.a.opponent = new_room.b
  new_room.b.opponent = new_room.a
  new_room.a:send(a_msg)
  new_room.b:send(b_msg)
  new_room:character_select()
  
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
  
  local msg = {match_start = true, ranked = false,
                player_settings = {character = a.character, level = a.level, player_number = a.player_number},
                opponent_settings = {character = b.character, level = b.level, player_number = b.player_number}}
  local room_is_ranked, reasons = a.room:rating_adjustment_approved()
  if room_is_ranked then
    a.room.replay.vs.ranked=true
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
  a.room.replay.vs.P1_name=a.name
  a.room.replay.vs.P2_name=b.name
  a.room.replay.vs.P1_char=a.character
  a.room.replay.vs.P2_char=b.character
  a:send(msg)
  a.room:send_to_spectators(msg)
  msg.player_settings, msg.opponent_settings = msg.opponent_settings, msg.player_settings
  b:send(msg)
  lobby_changed = true
  a:setup_game()
  b:setup_game()
  for k,v in pairs(a.room.spectators) do
    v:setup_game()
  end
end

Room = class(function(self, a, b)
  --TODO: it would be nice to call players a and b something more like self.players[1] and self.players[2]
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
    local a_rating, b_rating
    if a.user_id and leaderboard.players[a.user_id] and leaderboard.players[a.user_id].rating then
      a_rating = round(leaderboard.players[a.user_id].rating)
    end
    if b.user_id and leaderboard.players[b.user_id] and leaderboard.players[b.user_id].rating then
      b_rating = round(leaderboard.players[b.user_id].rating)
    end
    self.ratings = {{old=a_rating or DEFAULT_RATING, new=a_rating or DEFAULT_RATING, difference=0},
                    {old=b_rating or DEFAULT_RATING, new=b_rating or DEFAULT_RATING, difference=0}}
  else
    self.win_counts = self.a.room.win_counts
    self.spectators = self.a.room.spectators
    self.roomNumber = self.a.room.roomNumber
  end
  self.game_outcome_reports = {}
  rooms[self.roomNumber] = self
end)

function Room.character_select(self)
  print("Called Server.lua Room.character_select")
  self.a.state = "character select"
  self.b.state = "character select"
  if self.a.player_number and self.a.player_number ~= 0 and self.a.player_number ~= 1 then
    print("initializing room. player a does not have player_number 1. Swapping players a and b")
    self.a, self.b = self.b, self.a
    if self.a.player_number == 1 then
      print("Success. player a has player_number 1 now.")
    else
      print("ERROR. Player a still doesn't have player_number 1")
    end
  else
    self.a.player_number = 1
    self.b.player_number = 2
  end
  self.a.cursor = "level"
  self.b.cursor = "level"
  self.a.ready = false
  self.b.ready = false
  self:send({character_select=true, create_room=true, rating_updates=true, ratings=self.ratings, a_menu_state=self.a:menu_state(), b_menu_state=self.b:menu_state()})
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
  self.spectators[#self.spectators+1] = new_spectator_connection
  print(new_spectator_connection.name .. " joined " .. self.name .. " as a spectator")
  
  msg = {spectate_request_granted = true, spectate_request_rejected = false, rating_updates=true, ratings=self.ratings, a_menu_state=self.a:menu_state(), b_menu_state=self.b:menu_state(), win_counts=self.win_counts, match_start=replay_of_match_so_far~=nil, replay_of_match_so_far = self.replay, ranked = self:rating_adjustment_approved(),
                player_settings = {character = self.a.character, level = self.a.level, player_number = self.a.player_number},
                opponent_settings = {character = self.b.character, level = self.b.level, player_number = self.b.player_number}}
  new_spectator_connection:send(msg)
  msg = {spectators=self:spectator_names()}
  print("sending spectator list: "..json.encode(msg))
  self:send(msg)
  lobby_changed = true
end

function Room.spectator_names(self)
  local list = {}
  for k,v in pairs(self.spectators) do
    list[#list+1] = v.name
  end
  return list
end

function Room.remove_spectator(self, connection)
  for k,v in pairs(self.spectators) do
    if v.name == connection.name then
      self.spectators[k].state = "lobby"
      print(connection.name .. " left " .. self.name .. " as a spectator")
      self.spectators[k] = nil
      lobby_changed = true
      connection:send(lobby_state())
    end
  end
  msg = {spectators=self:spectator_names()}
  print("sending spectator list: "..json.encode(msg))
  self:send(msg)
end

function Room.close(self)
    --TODO: notify spectators that the room has closed.
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
    for k,v in pairs(self.spectators) do
      if v.room then
        v.room = nil
        v.state = "lobby"
      end
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

function Playerbase.update(self, user_id, user_name)
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

function Leaderboard.update(self, user_id, new_rating)
  print("in Leaderboard.update")
  if self.players[user_id] then
    self.players[user_id].rating = new_rating
  else
    self.players[user_id] = {rating=new_rating}
  end
  print("new_rating = "..new_rating)
  print("about to write_leaderboard_file")
  write_leaderboard_file()
  print("done with Leaderboard.update")
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
  for k,v in pairs(self.players) do
    leaderboard_player_count = leaderboard_player_count + 1
  end
  for k,v in pairs(self.players) do
    for insert_index=1, leaderboard_player_count do
      local player_is_leaderboard_requester = nil
      if playerbase.players[k] then --only include in the report players who are still listed in the playerbase
        if v.rating then -- don't include entries who's rating is nil (which shouldn't happen anyway)
          if k == user_id_of_requester then
            player_is_leaderboard_requester = true
          end
          if report[insert_index] and report[insert_index].rating and v.rating >= report[insert_index].rating then
            table.insert(report, insert_index, {user_name=playerbase.players[k],rating=v.rating,is_you=player_is_leaderboard_requester})
            break
          elseif insert_index == leaderboard_player_count or #report == 0 then
            table.insert(report, {user_name=playerbase.players[k],rating=v.rating,is_you=player_is_leaderboard_requester}) -- at the end of the table.
            break
          end
        end
      end
    end
  end
  for k,v in pairs(report) do 
    v.rating = round(v.rating)
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
  s.logged_in = false --whether connection has successfully logged into the rating system.
  s.user_id = nil
  s.wants_ranked_match = false --TODO: let the user change wants_ranked_match
end)

function Connection.menu_state(self)
  state = {cursor=self.cursor, ready=self.ready, character=self.character, level=self.level, ranked=self.wants_ranked_match}
  
  return state
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
  self.logged_in = false
  local IP_logging_in, port = self.socket:getsockname()
  print("New login attempt:  "..IP_logging_in..":"..port)
  if is_banned(IP_logging_in) then
    deny_login(self, "Awaiting ban timeout")
  elseif not self.name then
    deny_login(self, "Player has no name")
    print("Login failure: Player has no name")
  elseif not self.user_id then
    deny_login(self, "Client did not send a user_id in the login request")
    success = false
  elseif self.user_id == "need a new user id" and self.name then
    print(self.name.." needs a new user id!")
    local their_new_user_id
    while not their_new_user_id or playerbase.players[their_new_user_id] do
      their_new_user_id = generate_new_user_id()
    end
    playerbase:update(their_new_user_id, self.name)
    self:send({login_successful=true, new_user_id=their_new_user_id})
    self.user_id = their_new_user_id
    self.logged_in = true
    print("Connection with name "..self.name.." was assigned a new user_id")
  elseif not playerbase.players[self.user_id] then
    deny_login(self, "The user_id provided was not found on this server")
    print("Login failure: "..self.name.." specified an invalid user_id")
  elseif playerbase.players[self.user_id] ~= self.name then
    local the_old_name = playerbase.players[self.user_id]
    playerbase:update(self.user_id, self.name)
    self.logged_in = true
    self:send({login_successful=true, name_changed=true , old_name=the_old_name, new_name=self.name})
    print("Login successful and changed name "..the_old_name.." to "..self.name)
  elseif playerbase.players[self.user_id] then
    self.logged_in = true
    self:send({login_successful=true})
  else
    deny_login(self, "Unknown")
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
      ban_list[IP].unban_time = os.time()+60*ban_list[IP].violation_count
    elseif reason == "The user_id provided was not found on this server" then
      ban_list[IP] = {violation_count=1, unban_time = os.time()+60}
    else
      ban_list[IP] = {violation_count=0, unban_time = os.time()}
    end
    ban_list[IP].user_name = connection.name or ""
    ban_list[IP].reason = reason
    connection:send({login_denied=true, reason=reason, 
                    ban_duration=math.floor((ban_list[IP].unban_time-os.time())/60).."min"..((ban_list[IP].unban_time-os.time())%60).."sec",
                    violation_count = ban_list[IP].violation_count})
    print("login denied.  Reason:  "..reason)
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
      self.room.replay.vs.in_buf = self.room.replay.vs.in_buf..message
    elseif self.player_number == 2 then
      self.room:send_to_spectators("I"..message)
      self.room.replay.vs.I = self.room.replay.vs.I..message
    end
  end
end

function Room.send_to_spectators(self, message)
  --TODO: maybe try to do this in a different thread?
  for k,v in pairs(self.spectators) do
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
        print("clients "..self.a.name.." and "..self.b.name.." disagree on their game outcome. So the server will decide.")
        outcome = 0
    else
      outcome = self.game_outcome_reports[1]
    end
    print("resolve_game_outcome says: "..outcome)
    --outcome is the player number of the winner, or 0 for a tie
    if self.a.save_replays_publicly ~= "not at all" and self.b.save_replays_publicly ~= "not at all" then
      --use UTC time for dates on replays
      local now = os.date("*t",to_UTC(os.time()))
      local path = "ftp"..sep.."replays"..sep.."v"..VERSION..sep..string.format("%04d"..sep.."%02d"..sep.."%02d", now.year, now.month, now.day)
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
      if rep_b_name <  rep_a_name and rep_b_name ~= "anonymous" then
        path = path..sep..rep_b_name.."-vs-"..rep_a_name
      else
        path = path..sep..rep_a_name.."-vs-"..rep_b_name
      end
      local filename = "v"..VERSION.."-"..string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec).."-"..rep_a_name.."-L"..self.replay.vs.P1_level.."-vs-"..rep_b_name.."-L"..self.replay.vs.P2_level
      if self.replay.vs.ranked then
        filename = filename.."-Ranked"
      else
        filename = filename.."-Casual"
      end
      if outcome == 1 or outcome == 2 then
        filename = filename.."-P"..outcome.."wins"
      elseif outcome == 0 then
        filename = filename.."-draw"
      end
      filename = filename..".txt"
      print("saving replay as "..path..sep..filename)
      
      write_replay_file(self.replay, path, filename)
      --write_replay_file(self.replay, "replay.txt")
    else
      print("replay not saved because a player didn't want it saved")
    end
    self.replay = nil
    if outcome == 0 then
      print("tie.  Nobody scored")
      --do nothing. no points or rating adjustments for ties.
      return true
    else
      local someone_scored = false
      for i=1,2,1--[[or Number of players if we implement more than 2 players]] do
        print("checking if player "..i.." scored...")
        if outcome == i then
          print("Player "..i.." scored")
          self.win_counts[i] = self.win_counts[i] + 1
          adjust_ratings(self, i)
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

function Room.rating_adjustment_approved(self)
  --returns whether both players in the room have game states such that rating adjustment should be approved
  local players = {self.a, self.b}
  local reasons = {}
  local prev_player_level = players[1].level
  for player_number = 1,2 do
    if not playerbase.players[players[player_number].user_id] or not players[player_number].logged_in or playerbase.deleted_players[players[player_number].user_id]then
      reasons[#reasons+1] = players[player_number].name.." didn't log in"
    end
    if not players[player_number].wants_ranked_match then
      reasons[#reasons+1] = players[player_number].name.." doesn't want ranked"
    end
    if players[player_number].level ~= prev_player_level then
      reasons[#reasons+1] = "levels don't match"
    end
    prev_player_level = players[player_number].level
  end
  if reasons[1] then
    return false, reasons
  else 
    return true, reasons  
  end
end

function adjust_ratings(room, winning_player_number)
    print("We'd be adjusting the rating of "..room.a.name.." and "..room.b.name..". Player "..winning_player_number.." wins!")
    local players = {room.a, room.b}
    local continue = true
    --check that it's ok to adjust rating
    continue, reasons = room:rating_adjustment_approved()
    if continue then
          for player_number = 1,2 do
            --if they aren't on the leaderboard yet, give them the default rating
            if not leaderboard.players[players[player_number].user_id] or not leaderboard.players[players[player_number].user_id].rating then  
              leaderboard:update(players[player_number].user_id, DEFAULT_RATING)
              print("Gave "..playerbase.players[players[player_number].user_id].." a new rating of "..DEFAULT_RATING)
            end
          end
        --[[ --Algorithm we are implementing, per community member Bbforky:
            Formula for Calculating expected outcome:

            Oe=1/(1+10^((Ro-Rc)/400)))

            Oe= Expected Outcome
            Ro= Current rating of opponent
            Rc= Current rating

            Formula for Calculating new rating:

            Rn=Rc+k(Oa-Oe)

            Rn=New Rating
            Oa=Actual Outcome (0 for loss, 1 for win)
            k= Constant (Probably will use 10)
        ]]--
        room.ratings = {}
        local Ro, Rc, Oe, Oa
        local k = 10
        for player_number = 1,2 do
          room.ratings[player_number] = {}
          -- print("calculating expected outcome for")
          -- print(players[player_number].name.." Ranking: "..leaderboard.players[players[player_number].user_id].rating)
          -- print("vs")
          -- print(players[player_number].opponent.name.." Ranking: "..leaderboard.players[players[player_number].opponent.user_id].rating)
          Ro = leaderboard.players[players[player_number].opponent.user_id].rating
          Rc = leaderboard.players[players[player_number].user_id].rating
          Oe = 1/(1+10^((Ro-Rc)/400))
          -- print("Ro="..Ro)
          -- print("Rc="..Rc)
          -- print("Ro-Rc="..Ro-Rc)
          -- print("1/(1+10^((Ro-Rc)/400))="..1/(1+10^((Ro-Rc)/400)))
          -- print("expected outcome: "..Oe)
          
          if players[player_number].player_number == winning_player_number then
            Oa = 1
          else
            Oa = 0
          end
          room.ratings[player_number].new = Rc + k*(Oa-Oe)
          print("room.ratings["..player_number.."].new = "..room.ratings[player_number].new)
        end
        --check that both player's new room.ratings are numeric (and not nil)
        for player_number = 1,2 do
          if tonumber(room.ratings[player_number].new) then
            print()
            continue = true
          else
            print(players[player_number].name.."'s new rating wasn't calculated properly.  Not adjusting the rating for this match")
            continue = false
          end
        end
        if continue then
            --now that both new room.ratings have been calculated properly, actually update the leaderboard
            for player_number = 1,2 do
              print(playerbase.players[players[player_number].user_id])
              print("Old rating:"..leaderboard.players[players[player_number].user_id].rating)
              room.ratings[player_number].old = leaderboard.players[players[player_number].user_id].rating
              leaderboard:update(players[player_number].user_id, room.ratings[player_number].new)
              print("New rating:"..leaderboard.players[players[player_number].user_id].rating)
            end
            for player_number = 1,2 do
              --round and calculate rating gain or loss (difference) to send to the clients
              room.ratings[player_number].old = round(room.ratings[player_number].old)
              room.ratings[player_number].new = round(room.ratings[player_number].new)
              room.ratings[player_number].difference = room.ratings[player_number].new - room.ratings[player_number].old
            end
            msg = {rating_updates=true, ratings=room.ratings}
            room:send(msg)
        end
    else
      print("Not adjusting ratings.  "..reasons[1])
    end
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
    self.room.replay.vs.P = self.room.replay.vs.P..ret
  elseif self.player_number == 2 then
    self.room:send_to_spectators("O"..ret)
    self.room.replay.vs.O = self.room.replay.vs.O..ret
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
    self.room.replay.vs.Q = self.room.replay.vs.Q..ret
  elseif self.player_number == 2 then
    self.room:send_to_spectators("R"..ret)
    self.room.replay.vs.R = self.room.replay.vs.R..ret
  end
  if self.opponent then
    self.opponent:send("R"..ret)
  end
end

function Connection.J(self, message)
  message = json.decode(message)
  local response
  if self.state == "needs_name" then
    if not message.name or message.name == "" then
      print("connection didn't send a name")
      response = {choose_another_name = {reason = "Name cannot be blank"}}
      self:send(response)
      return
    elseif string.lower(message.name) == "anonymous" then
      print("connection tried to use name\"anonymous\"")
      response = {choose_another_name = {reason = "Username cannot be \"anonymous\""}}
      self:send(response)
      return
    elseif name_to_idx[message.name] then
      print("connection sent name: "..message.name)
      local names = {}
      for _,v in pairs(connections) do
        names[#names+1] = v.name -- fine if name is nil :o
      end
      response = {choose_another_name = {used_names = names} }
      self:send(response)
    elseif message.name:find("[^_%w]") then
      response = {choose_another_name = {reason = "Usernames are limited to alphanumeric and underscores"}}
      self:send(response)
    elseif string.len(message.name) > NAME_LENGTH_LIMIT then
      response = {choose_another_name = {reason = "The name length limit is "..NAME_LENGTH_LIMIT.. " characters"}}
      self:send(response)
    else
      self.name = message.name
      self.character = message.character
      self.level = message.level
      self.save_replays_publicly = message.save_replays_publicly
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
  elseif message.leaderboard_request then
    self:send({leaderboard_report=leaderboard:get_report(self)})
  elseif message.spectate_request then
    local requestedRoom = roomNumberToRoom(message.spectate_request.roomNumber)
    if self.state ~= "lobby" then
      if requestedRoom then
        print("removing "..self.name.." from room nr "..message.spectate_request.roomNumber)
        requestedRoom:remove_spectator()
      else
        print("could not find room to remove "..self.name)
      self.state = "lobby"
      end
    end
    if requestedRoom and requestedRoom:state() == CHARACTERSELECT then
    -- TODO: allow them to join
      print("join allowed")
      print("adding "..self.name.." to room nr "..message.spectate_request.roomNumber)
      requestedRoom:add_spectator(self)
      
    elseif requestedRoom and requestedRoom:state() == PLAYING then
      print("join-in-progress allowed")
      print("adding "..self.name.." to room nr "..message.spectate_request.roomNumber)
      requestedRoom:add_spectator(self)
    else
    -- TODO: tell the client the join request failed, couldn't find the room.
      print("couldn't find room")
    end
  elseif self.state == "character select" and message.menu_state then
    self.level = message.menu_state.level
    self.character = message.menu_state.character
    self.ready = message.menu_state.ready
    self.cursor = message.menu_state.cursor
    self.wants_ranked_match = message.menu_state.ranked
    
    if self.wants_ranked_match or self.opponent.wants_ranked_match then
      local ranked_match_approved, reasons = self.room:rating_adjustment_approved()
      if ranked_match_approved then
        self.room:send({ranked_match_approved=true})
      else
        self.room:send({ranked_match_denied=true, reasons=reasons})
      end 
    end
    
    if self.ready and self.opponent.ready then
        self.room.replay = {}
        self.room.replay.vs = {P="",O="",I="",Q="",R="",in_buf="",
                    P1_level=self.room.a.level,P2_level=self.room.b.level,
                    P1_char=self.room.a.character,P2_char=self.room.b.character, ranked = self.room:rating_adjustment_approved(),
                    do_countdown = true}
        if self.player_number == 1 then
          start_match(self, self.opponent)
        else
          start_match(self.opponent, self)
        end
    else
      self.opponent:send(message)
      message.player_number = self.player_number
      self.room:send_to_spectators(message) -- TODO: may need to include in the message who is sending the message
    end
  elseif self.state == "playing" and message.game_over then
    self.room.game_outcome_reports[self.player_number] = message.outcome
      if self.room:resolve_game_outcome() then
        print("\n*******************************")
        print("***"..self.room.a.name.." ".. self.room.win_counts[1].." - "..self.room.win_counts[2].." "..self.room.b.name.."***")
        print("*******************************\n")
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

local server_socket = socket.bind("*", 49569)
playerbase = Playerbase("playerbase")
read_players_file()
read_deleted_players_file()
leaderboard = Leaderboard("leaderboard")
read_leaderboard_file()
print(os.time())
--TODO: remove test print for leaderboard
print("playerbase: "..json.encode(playerbase.players))
print("leaderboard report: "..json.encode(leaderboard:get_report()))
read_csprng_seed_file()
if csprng_seed == 2000 then
print("ALERT! YOU SHOULD CHANGE YOUR CSPRNG_SEED.TXT FILE TO MAKE YOUR USER_IDS MORE SECURE!")
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

print("initialized!")
-- print("get_timezone() output: "..get_timezone())
-- print("get_timezone_offset(os.time()) output: "..get_timezone_offset(os.time()))
-- print("get_tzoffset(get_timezone()) output:"..get_tzoffset(get_timezone()))

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

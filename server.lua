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
local randomNumber = math.random
local lobbyChanged = false
local time = os.time
local floor = math.floor
local TIMEOUT = 10
local CHARACTER_SELECT = "character select" -- room states
local PLAYING = "playing" -- room states
local DEFAULT_RATING = 1500
local NAME_LENGTH_LIMIT = 16
local directorySeparator = package.config:sub(1, 1) --determines os directory directorySeparatorarator (i.e. "/" or "\")


local VERSION = "023"
local type_to_length = {H=4, E=4, F=4, P=8, I=2, L=2, Q=8, U=2}
local INDEX = 1
local connections = {}
local ROOM_NUMBER = 1
local rooms = {}
local nameToIndex = {}
local socketToIndex = {}
local proposals = {}
local playerbases = {}

function lobby_state()
  local lobbyNames = {}
  for _,v in pairs(connections) do
    if v.state == "lobby" then
      lobbyNames[#lobbyNames+1] = v.name
    end
  end
  local spectatableRooms = {}
  for _,v in pairs(rooms) do
      spectatableRooms[#spectatableRooms+1] = {roomNumber = v.roomNumber, name = v.name , a = v.a.name, b = v.b.name, state = v:state()}
  end
  return {unpaired = lobbyNames, spectatable = spectatableRooms}
end

function propose_game(sender, receiver, message)
  local s_c, r_c = nameToIndex[sender], nameToIndex[receiver]
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
  lobbyChanged = true
  clear_proposals(a.name)
  clear_proposals(b.name)
  local newRoom = Room(a,b)
  local playerMessage, opponentMessage = {create_room = true}, {create_room = true}
  playerMessage.your_player_number = 1
  playerMessage.op_player_number = 2
  playerMessage.opponent = newRoom.b.name
  playerMessage.menu_state = newRoom.b:menu_state()
  opponentMessage.your_player_number = 2
  opponentMessage.op_player_number = 1
  opponentMessage.opponent = newRoom.a.name
  opponentMessage.menu_state = newRoom.a:menu_state()
  playerMessage.ratings = newRoom.ratings
  opponentMessage.ratings = newRoom.ratings
  newRoom.a.opponent = newRoom.b
  newRoom.b.opponent = newRoom.a
  newRoom.a:send(playerMessage)
  newRoom.b:send(opponentMessage)
  newRoom:character_select()
  
end

-- a and b represent player and opponent
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
  
  local message = {match_start = true, ranked = false,
                  player_settings = {character = a.character, level = a.level, player_number = a.player_number},
                  opponent_settings = {character = b.character, level = b.level, player_number = b.player_number}}
  local room_is_ranked, reasons = a.room:rating_adjustment_approved()
  if room_is_ranked then
    a.room.replay.vs.ranked=true
    message.ranked = true
    if leaderboard.players[a.user_id] then
      message.player_settings.rating = round(leaderboard.players[a.user_id].rating)
    else
      message.player_settings.rating = DEFAULT_RATING
    end
    if leaderboard.players[b.user_id] then
      message.opponent_settings.rating = round(leaderboard.players[b.user_id].rating)
    else
      message.opponent_settings.rating = DEFAULT_RATING
    end
  end
  a.room.replay.vs.P1_name=a.name
  a.room.replay.vs.P2_name=b.name
  a.room.replay.vs.P1_char=a.character
  a.room.replay.vs.P2_char=b.character
  a:send(message)
  a.room:send_to_spectators(message)
  message.player_settings, message.opponent_settings = message.opponent_settings, message.player_settings
  b:send(message)
  lobbyChanged = true
  a:setup_game()
  b:setup_game()
  for k,v in pairs(a.room.spectators) do
    v:setup_game()
  end
end

-- object Room
Room = class(function(self, a, b)
  --TODO: it would be nice to call players a and b something more like self.players[1] and self.players[2]
  self.a = a --player a
  self.b = b --player b
  self.name = a.name.." vs "..b.name
  if not self.a.room then
    self.roomNumber = ROOM_NUMBER
    ROOM_NUMBER = ROOM_NUMBER + 1
    self.a.room = self
    self.b.room = self
    self.spectators = {}
    self.win_counts = {}
    self.win_counts[1] = 0
    self.win_counts[2] = 0
    local playerRating, opponentRating
    if a.user_id and leaderboard.players[a.user_id] and leaderboard.players[a.user_id].rating then
      playerRating = round(leaderboard.players[a.user_id].rating)
    end
    if b.user_id and leaderboard.players[b.user_id] and leaderboard.players[b.user_id].rating then
      opponentRating = round(leaderboard.players[b.user_id].rating)
    end
    self.ratings = {{old=playerRating or DEFAULT_RATING, new=playerRating or DEFAULT_RATING, difference=0},
                    {old=opponentRating or DEFAULT_RATING, new=opponentRating or DEFAULT_RATING, difference=0}}
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
    return CHARACTER_SELECT
  elseif self.a.state == "playing" then
    return PLAYING
  else
    return self.a.state
  end
end

function Room.is_spectatable(self)
  return self.a.state == "character select"
end

function Room.add_spectator(self, newSpectatorConnection)
  newSpectatorConnection.state = "spectating"
  newSpectatorConnection.room = self
  self.spectators[#self.spectators+1] = newSpectatorConnection
  print(newSpectatorConnection.name .. " joined " .. self.name .. " as a spectator")
  
  msg = {spectate_request_granted = true, spectate_request_rejected = false, rating_updates=true, ratings=self.ratings, a_menu_state=self.a:menu_state(), b_menu_state=self.b:menu_state(), win_counts=self.win_counts, match_start=replay_of_match_so_far~=nil, replay_of_match_so_far = self.replay, ranked = self:rating_adjustment_approved(),
                player_settings = {character = self.a.character, level = self.a.level, player_number = self.a.player_number},
                opponent_settings = {character = self.b.character, level = self.b.level, player_number = self.b.player_number}}
  newSpectatorConnection:send(msg)
  msg = {spectators=self:spectator_names()}
  print("sending spectator list: "..json.encode(msg))
  self:send(msg)
  lobbyChanged = true
end

function Room.spectator_names(self)
  local spectatorList = {}
  for k,v in pairs(self.spectators) do
    spectatorList[#spectatorList+1] = v.name
  end
  return spectatorList
end

function Room.remove_spectator(self, connection)
  for k,v in pairs(self.spectators) do
    if v.name == connection.name then
      self.spectators[k].state = "lobby"
      print(connection.name .. " left " .. self.name .. " as a spectator")
      self.spectators[k] = nil
      lobbyChanged = true
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
  newUserId = cs_random()
  print("new_user_id: "..newUserId)
  return tostring(newUserId)
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
  local leaderboardPlayerCount = 0
  --count how many entries there are in self.players since #self.players will not give us an accurate answer for sparse tables
  for k,v in pairs(self.players) do
    leaderboardPlayerCount = leaderboardPlayerCount + 1
  end
  for k,v in pairs(self.players) do
    for insert_index=1, leaderboardPlayerCount do
      local playerIsLeaderboardRequester = nil
      if playerbase.players[k] then --only include in the report players who are still listed in the playerbase
        if v.rating then -- don't include entries who's rating is nil (which shouldn't happen anyway)
          if k == user_id_of_requester then
            playerIsLeaderboardRequester = true
          end
          if report[insert_index] and report[insert_index].rating and v.rating >= report[insert_index].rating then
            table.insert(report, insert_index, {user_name=playerbase.players[k],rating=v.rating,is_you=playerIsLeaderboardRequester})
            break
          elseif insert_index == leaderboardPlayerCount or #report == 0 then
            table.insert(report, {user_name=playerbase.players[k],rating=v.rating,is_you=playerIsLeaderboardRequester}) -- at the end of the table.
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

-- object Connection
Connection = class(function(s, socket)
  s.index = INDEX
  INDEX = INDEX + 1
  connections[s.index] = s
  socketToIndex[socket] = s.index
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

-- stuff need to change
function Connection.send(self, stuff)
  if type(stuff) == "table" then
    local json = json.encode(stuff)
    local length = json:len()
    local prefix = "J"..char(floor(length/65536))..char(floor((length/256)%256))..char(length%256)
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
  local IPLoggingIn, port = self.socket:getsockname()
  print("New login attempt:  "..IPLoggingIn..":"..port)
  if is_banned(IPLoggingIn) then
    deny_login(self, "Awaiting ban timeout")
  elseif not self.name then
    deny_login(self, "Player has no name")
    print("Login failure: Player has no name")
  elseif not self.user_id then
    deny_login(self, "Client did not send a user_id in the login request")
    success = false
  elseif self.user_id == "need a new user id" and self.name then
    print(self.name.." needs a new user id!")
    local theirNewUserId
    while not theirNewUserId or playerbase.players[theirNewUserId] do
      theirNewUserId = generate_new_user_id()
    end
    playerbase:update(theirNewUserId, self.name)
    self:send({login_successful=true, newUserId=theirNewUserId})
    self.user_id = theirNewUserId
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
    local violationCount = 0
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
  local isBanned = false
    if ban_list[IP] and ban_list[IP].unban_time - os.time() > 0 then
      isBanned = true
    end
  return isBanned
end

function Connection.opponent_disconnected(self)
  self.opponent = nil
  self.state = "lobby"
  lobbyChanged = true
  local message = lobby_state()
  message.leave_room = true
  if self.room then
    self.room:close()
  end
  self:send(message)
end

function Connection.setup_game(self)
  if self.state ~= "spectating" then
    self.state = "playing"
  end
  lobbyChanged = true --TODO: remove this line when we implement joining games in progress
  self.vs_mode = true
  self.metal = false
  self.rows_left = 14+randomNumber(1,8)
  self.prev_metal_col = nil
  self.metal_col = nil
  self.first_seven = nil
end

function Connection.close(self)
  if self.state == "lobby" then
    lobbyChanged = true
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
    nameToIndex[self.name] = nil
  end
  socketToIndex[self.socket] = nil
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
      local timeNow = os.date("*t",to_UTC(os.time()))
      local path = "ftp"..directorySeparator.."replays"..directorySeparator.."v"..VERSION..directorySeparator..string.format("%04d"..directorySeparator.."%02d"..directorySeparator.."%02d", timeNow.year, timeNow.month, timeNow.day)
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
        path = path..directorySeparator..rep_b_name.."-vs-"..rep_a_name
      else
        path = path..directorySeparator..rep_a_name.."-vs-"..rep_b_name
      end
      local filename = "v"..VERSION.."-"..string.format("%04d-%02d-%02d-%02d-%02d-%02d", timeNow.year, timeNow.month, timeNow.day, timeNow.hour, timeNow.min, timeNow.sec).."-"..rep_a_name.."-L"..self.replay.vs.P1_level.."-vs-"..rep_b_name.."-L"..self.replay.vs.P2_level
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
      print("saving replay as "..path..directorySeparator..filename)
      
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
      local haveSomeoneScored = false
      for i=1,2,1--[[or Number of players if we implement more than 2 players]] do
        print("checking if player "..i.." scored...")
        if outcome == i then
          print("Player "..i.." scored")
          self.win_counts[i] = self.win_counts[i] + 1
          adjust_ratings(self, i)
          haveSomeoneScored = true
        end
      end
      if haveSomeoneScored then
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
  local previouslyPlayerLevel = players[1].level
  for player_number = 1,2 do
    if not playerbase.players[players[player_number].user_id] or not players[player_number].logged_in or playerbase.deleted_players[players[player_number].user_id]then
      reasons[#reasons+1] = players[player_number].name.." didn't log in"
    end
    if not players[player_number].wants_ranked_match then
      reasons[#reasons+1] = players[player_number].name.." doesn't want ranked"
    end
    if players[player_number].level ~= previouslyPlayerLevel then
      reasons[#reasons+1] = "levels don't match"
    end
    previouslyPlayerLevel = players[player_number].level
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
        local currentOpponentRating, currentPlayerRating, expectedOutcome, actualOutcome
        local EXPECTED_OUTCOME_CONSTANT_VALUE = 10
        for player_number = 1,2 do
          room.ratings[player_number] = {}
          -- print("calculating expected outcome for")
          -- print(players[player_number].name.." Ranking: "..leaderboard.players[players[player_number].user_id].rating)
          -- print("vs")
          -- print(players[player_number].opponent.name.." Ranking: "..leaderboard.players[players[player_number].opponent.user_id].rating)
          currentOpponentRating = leaderboard.players[players[player_number].opponent.user_id].rating
          currentPlayerRating = leaderboard.players[players[player_number].user_id].rating
          expectedOutcome = 1/(1+10^((currentOpponentRating-currentPlayerRating)/400))
          -- print("Ro="..Ro)
          -- print("Rc="..Rc)
          -- print("Ro-Rc="..Ro-Rc)
          -- print("1/(1+10^((Ro-Rc)/400))="..1/(1+10^((Ro-Rc)/400)))
          -- print("expected outcome: "..Oe)
          
          if players[player_number].player_number == winning_player_number then
            actualOutcome = 1
          else
            actualOutcome = 0
          end
          room.ratings[player_number].new = currentPlayerRating + EXPECTED_OUTCOME_CONSTANT_VALUE*(actualOutcome-expectedOutcome)
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
    elseif nameToIndex[message.name] then
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
      lobbyChanged = true
      self.state = "lobby"
      nameToIndex[self.name] = self.index
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
    if requestedRoom and requestedRoom:state() == CHARACTER_SELECT then
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
                    P1_char=self.room.a.character,P2_char=self.room.b.character, ranked = self.room:rating_adjustment_approved()}
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
    local opponent = self.opponent
    self:opponent_disconnected()
    opponent:opponent_disconnected()
    if self.room and self.room.spectators then
      for k, player in pairs(self.room.spectators) do
        player:opponent_disconnected()
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
  local index = 1
  while data:len() > 0 do
    --assert(type(data) == "string")
    local messageType = data[1]
    --assert(type(messageType) == "string")
    if messageType == "J" then
      if data:len() < 4 then
        break
      end
      local msg_len = byte(data[2])*65536 + byte(data[3])*256 + byte(data[4])
      if data:len() < 4 + msg_len then
        break
      end
      local JSONMessage = data:sub(5, msg_len+4)
      print("got JSON message "..JSONMessage)
      print("Pcall results for json: ", pcall(function()
        self:J(JSONMessage)
      end))
      data = data:sub(msg_len+5)
    else
      if messageType ~= "I" then
        print("using non-J type "..messageType)
      end
      total_len = type_to_length[messageType]
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
        self[messageType](self, data:sub(2,total_len))
      end)}
      if messageType ~= "I" or not res[1] then
        print("got message "..messageType.." "..data:sub(2,total_len))
        print("Pcall results for "..messageType..": ", unpack(res))
      end
      data = data:sub(total_len+1)
    end
  end
  self.leftovers = data
end

function Connection.read(self)
  local junk, errorInConnection, data = self.socket:receive("*a")
  if not errorInConnection then
    error("shitfuck")
  end
  if data and data:len() > 0 then
    self:data_received(data)
  end
end

function broadcast_lobby()
  if lobbyChanged then
    for _,v in pairs(connections) do
      if v.state == "lobby" then
        v:send(lobby_state())
      end
    end
    lobbyChanged = false
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

local serverSocket = socket.bind("*", 49569)
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
  serverSocket:settimeout(0)
  local new_conn = serverSocket:accept()
  if new_conn then
    Connection(new_conn)
  end
  local recvt = {serverSocket}
  for _,v in pairs(connections) do
    recvt[#recvt+1] = v.socket
  end
  local ready = socket.select(recvt, nil, 1)
  assert(type(ready) == "table")
  for _,v in ipairs(ready) do
    if socketToIndex[v] then
      connections[socketToIndex[v]]:read()
    end
  end
  local timeNow = time()
  if timeNow ~= prev_now then
    for _,connected in pairs(connections) do
      if timeNow - connected.last_read > 10 then
        connected:close()
      elseif timeNow - connected.last_read > 1 then
        connected:send("ELOL")
      end
    end
    prev_now = timeNow
  end
  broadcast_lobby()
end

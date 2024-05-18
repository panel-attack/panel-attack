local socket = require("common.lib.socket")
local logger = require("common.lib.logger")
local class = require("common.lib.class")
local NetworkProtocol = require("common.network.NetworkProtocol")
json = require("common.lib.dkjson")
require("common.lib.util")
require("common.lib.timezones")
require("common.lib.csprng")
require("server.stridx")
require("server.server_globals")
require("server.server_file_io")
require("server.Connection")
require("server.Leaderboard")
require("server.PlayerBase")
require("server.Room")

local pairs = pairs
local ipairs = ipairs
local time = os.time

-- Represents the full server object.
-- Currently we are transitioning variables into this, but to start we will use this to define API
Server =
  class(
  function(self, databaseParam)
    self.connectionNumberIndex = 1 -- GLOBAL counter of the next available connection index
    self.roomNumberIndex = 1 -- the next available room number
    self.rooms = {} -- mapping of room number to room
    self.proposals = {} -- mapping of player name to a mapping of the players they have challenged
    self.connections = {} -- mapping of connection number to connection
    self.nameToConnectionIndex = {} -- mapping of player names to their unique connectionNumberIndex
    self.socketToConnectionIndex = {} -- mapping of sockets to their unique connectionNumberIndex
    assert(databaseParam ~= nil)
    self.database = databaseParam -- the database object
    self.loaded_placement_matches = {
      incomplete = {},
      complete = {}
    }
    self.lastProcessTime = time()
    self.lastFlushTime = self.lastProcessTime
    self.lobbyChanged = false

    logger.info("Starting up server with port: " .. (SERVER_PORT or 49569))
    self.socket = socket.bind("*", SERVER_PORT or 49569)
    self.socket:settimeout(0)
    if TCP_NODELAY_ENABLED then
      self.socket:setoption("tcp-nodelay", true)
    end

    self.playerbase = Playerbase("playerbase", "players.txt")
    read_players_file(self.playerbase)
    leaderboard = Leaderboard("leaderboard", self)
    read_leaderboard_file()
      
    local isPlayerTableEmpty = self.database:getPlayerRecordCount() == 0
    if isPlayerTableEmpty then
      self:importDatabase()
    end
    
    logger.debug("leaderboard json:")
    logger.debug(json.encode(leaderboard.players))
    write_leaderboard_file()
    logger.debug("Leagues")
    for k, v in ipairs(leagues) do
      logger.debug(v.league .. ":  " .. v.min_rating)
    end
    logger.debug(os.time())
    logger.debug("playerbase: " .. json.encode(self.playerbase.players))
    logger.debug("leaderboard report: " .. json.encode(leaderboard:get_report()))
    read_csprng_seed_file()
    initialize_mt_generator(csprng_seed)
    seed_from_mt(extract_mt())
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
    logger.debug("initialized!")
    -- print("get_timezone() output: "..get_timezone())
    -- print("get_timezone_offset(os.time()) output: "..get_timezone_offset(os.time()))
    -- print("get_tzoffset(get_timezone()) output:"..get_tzoffset(get_timezone()))    
  end
)

function Server:importDatabase()
  local usedNames = {}
  local cleanedPlayerData = {}
  for key, value in pairs(self.playerbase.players) do
    local name = value
    while usedNames[name] ~= nil do
      name = name .. math.random(1, 9999)
    end
    cleanedPlayerData[key] = value
    usedNames[name] = true
  end

  self.database:beginTransaction() -- this stops the database from attempting to commit every statement individually 
  logger.info("Importing leaderboard.csv to database")
  for k, v in pairs(cleanedPlayerData) do
    local rating = 0
    if leaderboard.players[k] then
      rating = leaderboard.players[k].rating
    end
    self.database:insertNewPlayer(k, v)
    self.database:insertPlayerELOChange(k, rating, 0)
  end

  local gameMatches = readGameResults()
  if gameMatches then -- only do it if there was a gameResults file to begin with
    logger.info("Importing GameResults.csv to database")
    for _, result in ipairs(gameMatches) do
      local player1ID = result[1]
      local player2ID = result[2]
      local player1Won = result[3] == 1
      local ranked = result[4] == 1
      local gameID = self.database:insertGame(ranked)
      if player1Won then
        self.database:insertPlayerGameResult(player1ID, gameID, nil,  1)
        self.database:insertPlayerGameResult(player2ID, gameID, nil,  2)
      else
        self.database:insertPlayerGameResult(player2ID, gameID, nil,  1)
        self.database:insertPlayerGameResult(player1ID, gameID, nil,  2)
      end
    end
  end
  self.database:commitTransaction() -- bulk commit every statement from the start of beginTransaction
end

local function addPublicPlayerData(players, playerName, player) 
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

function Server:setLobbyChanged()
  self.lobbyChanged = true
end

function Server:lobby_state()
  local names = {}
  local players = {}
  for _, v in pairs(self.connections) do
    if v.state == "lobby" then
      names[#names + 1] = v.name
      addPublicPlayerData(players, v.name, leaderboard.players[v.user_id])
    end
  end
  local spectatableRooms = {}
  for _, v in pairs(self.rooms) do
    spectatableRooms[#spectatableRooms + 1] = {roomNumber = v.roomNumber, name = v.name, a = v.a.name, b = v.b.name, state = v:state()}
    addPublicPlayerData(players, v.a.name, leaderboard.players[v.a.user_id])
    addPublicPlayerData(players, v.b.name, leaderboard.players[v.b.user_id])
  end
  return {unpaired = names, spectatable = spectatableRooms, players = players}
end

function Server:propose_game(senderName, receiverName, message)
  logger.debug("propose game: " .. senderName .. " " .. receiverName)
  local senderConnection, receiverConnection = self.nameToConnectionIndex[senderName], self.nameToConnectionIndex[receiverName]
  if senderConnection then
    senderConnection = self.connections[senderConnection]
  end
  if receiverConnection then
    receiverConnection = self.connections[receiverConnection]
  end
  local proposals = self.proposals
  if senderConnection and senderConnection.state == "lobby" and receiverConnection and receiverConnection.state == "lobby" then
    proposals[senderName] = proposals[senderName] or {}
    proposals[receiverName] = proposals[receiverName] or {}
    if proposals[senderName][receiverName] then
      if proposals[senderName][receiverName][receiverName] then
        self:create_room(senderConnection, receiverConnection)
      end
    else
      receiverConnection:send(message)
      local prop = {[senderName] = true}
      proposals[senderName][receiverName] = prop
      proposals[receiverName][senderName] = prop
    end
  end
end

function Server:clear_proposals(name)
  local proposals = self.proposals
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

function Server:playerSettingFromTable(data)
  local playerSettings = {
    character = data.character,
    character_display_name = data.character_display_name,
    level = data.level,
    panels_dir = data.panels_dir,
    player_number = data.player_number,
    inputMethod = data.inputMethod
  }
  return playerSettings
end

-- a and be are connection objects
function Server:create_room(a, b)
  self:setLobbyChanged()
  self:clear_proposals(a.name)
  self:clear_proposals(b.name)
  local new_room = Room(a, b, self.roomNumberIndex, leaderboard, self)
  self.roomNumberIndex = self.roomNumberIndex + 1
  self.rooms[new_room.roomNumber] = new_room
  local a_msg, b_msg = {create_room = true}, {create_room = true}
  a_msg.room_number = new_room.roomNumber
  b_msg.room_number = new_room.roomNumber
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

function Server:start_match(a, b)
  if (a.player_number ~= 1) then
    logger.debug("players a and b need to be swapped.")
    a, b = b, a
    if (a.player_number == 1) then
      logger.debug("Success, player a now has player_number 1.")
    else
      logger.error("ERROR: player a still doesn't have player_number 1.")
    end
  end

  a.room.stage = math.random(1, 2) == 1 and a.stage or b.stage
  local playerSettings = self:playerSettingFromTable(a)
  local opponentSettings = self:playerSettingFromTable(b)
  local msg = {
    match_start = true,
    ranked = false,
    stage = a.room.stage,
    player_settings = playerSettings,
    opponent_settings = opponentSettings
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
  self:setLobbyChanged()
  a:setup_game()
  b:setup_game()
  if not a.room then
    logger.error("ERROR: In start_match, Player A " .. (a.name or "nil") .. " doesn't have a room\nCannot run setup_game() for spectators!")
  end
  for k, v in pairs(a.room.spectators) do
    v:setup_game()
  end
end

function Server:roomNumberToRoom(roomNr)
  for k, v in pairs(self.rooms) do
    if self.rooms[k].roomNumber and self.rooms[k].roomNumber == roomNr then
      return v
    end
  end
end

function Server:createNewUser(name)
  local user_id = nil
  while not user_id or self.playerbase.players[user_id] do
    user_id = self:generate_new_user_id()
  end
  self.playerbase:updatePlayer(user_id, name)
  self.database:insertNewPlayer(user_id, name)
  self.database:insertPlayerELOChange(user_id, 0, 0)
  return user_id
end

function Server:changeUsername(privateUserID, username)
  self.playerbase:updatePlayer(privateUserID, username)
  if leaderboard.players[privateUserID] then
    leaderboard.players[privateUserID].user_name = username
  end
  self.database:updatePlayerUsername(privateUserID, username)
end

function Server:generate_new_user_id()
  local new_user_id = cs_random()
  return tostring(new_user_id)
end

-- Checks if a logging in player is banned based off their IP.
function Server:isPlayerBanned(ip)
  return self.database:isPlayerBanned(ip)
end

function Server:insertBan(ip, reason, completionTime)
  return self.database:insertBan(ip, reason, completionTime)
end

function Server:denyLogin(connection, reason, ban)
  assert(ban == nil or reason == nil)
  local message = {login_denied = true, reason = reason }
  if ban then
    local banRemainingString = "Ban Remaining: "
    local secondsRemaining = (ban.completionTime - os.time())
    local secondsPerDay = 60 * 60 * 24
    local secondsPerHour = 60 * 60
    local secondsPerMin = 60
    local detailCount = 0
    if secondsRemaining > secondsPerDay then
      banRemainingString = banRemainingString .. math.floor(secondsRemaining / secondsPerDay) .. " days "
      secondsRemaining = (secondsRemaining % secondsPerDay)
      detailCount = detailCount + 1
    end
    if secondsRemaining > secondsPerHour then
      banRemainingString = banRemainingString .. math.floor(secondsRemaining / secondsPerHour) .. " hours "
      secondsRemaining = (secondsRemaining % secondsPerHour)
      detailCount = detailCount + 1
    end
    if detailCount < 2 and secondsRemaining > secondsPerMin then
      banRemainingString = banRemainingString .. math.floor(secondsRemaining / secondsPerMin) .. " minutes "
      secondsRemaining = (secondsRemaining % secondsPerMin)
      detailCount = detailCount + 1
    end
    if detailCount < 2 then
      banRemainingString = banRemainingString .. math.floor(secondsRemaining) .. " seconds "
    end
    message.reason = ban.reason
    message.ban_duration = banRemainingString

    self.database:playerBanSeen(ban.banID)
    logger.warn("Login denied because of ban: " .. ban.reason)
  end

  connection:send(message)
end

function Server:closeRoom(room)
  room:close()
  if self.rooms[room.roomNumber] then
    self.rooms[room.roomNumber] = nil
  end
end

function Server:addSpectator(room, connection)
  room:add_spectator(connection)
  self:setLobbyChanged()
end

function Server:removeSpectator(room, connection)
  if room:remove_spectator(connection) then
    self:setLobbyChanged()
  end
end


function Server:calculate_rating_adjustment(Rc, Ro, Oa, k) -- -- print("calculating expected outcome for") -- print(players[player_number].name.." Ranking: "..leaderboard.players[players[player_number].user_id].rating)
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

function Server:adjust_ratings(room, winning_player_number, gameID)
  logger.debug("Adjusting the rating of " .. room.a.name .. " and " .. room.b.name .. ". Player " .. winning_player_number .. " wins!")
  local players = {room.a, room.b}
  local continue = true
  local placement_match_progress
  room.ratings = {}
  for player_number = 1, 2 do
    --if they aren't on the leaderboard yet, give them the default rating
    if not leaderboard.players[players[player_number].user_id] or not leaderboard.players[players[player_number].user_id].rating then
      leaderboard.players[players[player_number].user_id] = {user_name = self.playerbase.players[players[player_number].user_id], rating = DEFAULT_RATING}
      logger.debug("Gave " .. self.playerbase.players[players[player_number].user_id] .. " a new rating of " .. DEFAULT_RATING)
      if not PLACEMENT_MATCHES_ENABLED then
        leaderboard.players[players[player_number].user_id].placement_done = true
        self.database:insertPlayerELOChange(players[player_number].user_id, DEFAULT_RATING, gameID)
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
        logger.debug("Player " .. player_number .. " played a non-placement ranked match.  Updating his rating now.")
        room.ratings[player_number].new = self:calculate_rating_adjustment(leaderboard.players[players[player_number].user_id].rating, leaderboard.players[players[player_number].opponent.user_id].rating, Oa, k)
        self.database:insertPlayerELOChange(players[player_number].user_id, room.ratings[player_number].new, gameID)
      else
        logger.debug("Player " .. player_number .. " played ranked against an unranked opponent.  We'll process this match when his opponent has finished placement")
        room.ratings[player_number].placement_matches_played = leaderboard.players[players[player_number].user_id].ranked_games_played
        room.ratings[player_number].new = round(leaderboard.players[players[player_number].user_id].rating)
        room.ratings[player_number].old = round(leaderboard.players[players[player_number].user_id].rating)
        room.ratings[player_number].difference = 0
      end
    else -- this player has not finished placement
      if placement_done[players[player_number].opponent.user_id] then
        logger.debug("Player " .. player_number .. " (unranked) just played a placement match against a ranked player.")
        logger.debug("Adding this match to the list of matches to be processed when player finishes placement")
        self:load_placement_matches(players[player_number].user_id)
        local pm_count = #self.loaded_placement_matches.incomplete[players[player_number].user_id]

        self.loaded_placement_matches.incomplete[players[player_number].user_id][pm_count + 1] = {
          op_user_id = players[player_number].opponent.user_id,
          op_name = self.playerbase.players[players[player_number].opponent.user_id],
          op_rating = leaderboard.players[players[player_number].opponent.user_id].rating,
          outcome = Oa
        }
        logger.debug("PRINTING PLACEMENT MATCHES FOR USER")
        logger.debug(json.encode(self.loaded_placement_matches.incomplete[players[player_number].user_id]))
        write_user_placement_match_file(players[player_number].user_id, self.loaded_placement_matches.incomplete[players[player_number].user_id])

        --adjust newcomer's placement_rating
        if not leaderboard.players[players[player_number].user_id] then
          leaderboard.players[players[player_number].user_id] = {}
        end
        leaderboard.players[players[player_number].user_id].placement_rating = self:calculate_rating_adjustment(leaderboard.players[players[player_number].user_id].placement_rating or DEFAULT_RATING, leaderboard.players[players[player_number].opponent.user_id].rating, Oa, PLACEMENT_MATCH_K)
        logger.debug("New newcomer rating: " .. leaderboard.players[players[player_number].user_id].placement_rating)
        leaderboard.players[players[player_number].user_id].ranked_games_played = (leaderboard.players[players[player_number].user_id].ranked_games_played or 0) + 1
        if Oa == 1 then
          leaderboard.players[players[player_number].user_id].ranked_games_won = (leaderboard.players[players[player_number].user_id].ranked_games_won or 0) + 1
        end

        local process_them, reason = self:qualifies_for_placement(players[player_number].user_id)
        if process_them then
          local op_player_number = players[player_number].opponent.player_number
          logger.debug("op_player_number: " .. op_player_number)
          room.ratings[player_number].old = 0
          if not room.ratings[op_player_number] then
            room.ratings[op_player_number] = {}
          end
          room.ratings[op_player_number].old = round(leaderboard.players[players[op_player_number].user_id].rating)
          self:process_placement_matches(players[player_number].user_id)

          room.ratings[player_number].new = round(leaderboard.players[players[player_number].user_id].rating)

          room.ratings[player_number].difference = round(room.ratings[player_number].new - room.ratings[player_number].old)
          room.ratings[player_number].league = self:get_league(room.ratings[player_number].new)

          room.ratings[op_player_number].new = round(leaderboard.players[players[op_player_number].user_id].rating)

          room.ratings[op_player_number].difference = round(room.ratings[op_player_number].new - room.ratings[op_player_number].old)
          room.ratings[op_player_number].league = self:get_league(room.ratings[player_number].new)
          return
        else
          placement_match_progress = reason
        end
      else
        logger.error("Neither player is done with placement.  We should not have gotten to this line of code")
      end
      room.ratings[player_number].new = 0
      room.ratings[player_number].old = 0
      room.ratings[player_number].difference = 0
    end
    logger.debug("room.ratings[" .. player_number .. "].new = " .. (room.ratings[player_number].new or ""))
  end
  --check that both player's new room.ratings are numeric (and not nil)
  for player_number = 1, 2 do
    if tonumber(room.ratings[player_number].new) then
      continue = true
    else
      logger.warn(players[player_number].name .. "'s new rating wasn't calculated properly.  Not adjusting the rating for this match")
      continue = false
    end
  end
  if continue then
    --now that both new room.ratings have been calculated properly, actually update the leaderboard
    for player_number = 1, 2 do
      logger.debug(self.playerbase.players[players[player_number].user_id])
      logger.debug("Old rating:" .. leaderboard.players[players[player_number].user_id].rating)
      room.ratings[player_number].old = leaderboard.players[players[player_number].user_id].rating
      leaderboard.players[players[player_number].user_id].ranked_games_played = (leaderboard.players[players[player_number].user_id].ranked_games_played or 0) + 1
      leaderboard:update(players[player_number].user_id, room.ratings[player_number].new)
      logger.debug("New rating:" .. leaderboard.players[players[player_number].user_id].rating)
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
      room.ratings[player_number].league = self:get_league(room.ratings[player_number].new)
    end
  -- msg = {rating_updates=true, ratings=room.ratings, placement_match_progress=placement_match_progress}
  -- room:send(msg)
  end
end

function Server:load_placement_matches(user_id)
  logger.debug("Requested loading placement matches for user_id:  " .. (user_id or "nil"))
  if not self.loaded_placement_matches.incomplete[user_id] then
    local read_success, matches = read_user_placement_match_file(user_id)
    if read_success then
      self.loaded_placement_matches.incomplete[user_id] = matches or {}
      logger.debug("loaded placement matches from file:")
    else
      self.loaded_placement_matches.incomplete[user_id] = {}
      logger.debug("no pre-existing placement matches file, starting fresh")
    end
    logger.debug(tostring(self.loaded_placement_matches.incomplete[user_id]))
    logger.debug(json.encode(self.loaded_placement_matches.incomplete[user_id]))
  else
    logger.debug("Didn't load placement matches from file. It is already loaded")
  end
end

function Server:qualifies_for_placement(user_id)
  --local placement_match_win_ratio_requirement = .2
  self:load_placement_matches(user_id)
  local placement_matches_played = #self.loaded_placement_matches.incomplete[user_id]
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
  -- win_count = win_count + self.loaded_placement_matches.incomplete[user_id][i].outcome
  -- end
  -- win_ratio = win_count / placement_matches_played
  -- if win_ratio < placement_match_win_ratio_requirement then
  -- return false, "placement win ratio is currently "..round(win_ratio*100).."%.  "..round(placement_match_win_ratio_requirement*100).."% is required for placement."
  -- end
  end
  return true
end

function Server:process_placement_matches(user_id)
  self:load_placement_matches(user_id)
  local placement_matches = self.loaded_placement_matches.incomplete[user_id]
  if #placement_matches < 1 then
    logger.error("Failed to process placement matches because we couldn't find any")
    return
  end

  --assign the current placement_rating as the newcomer's official rating.
  leaderboard.players[user_id].rating = leaderboard.players[user_id].placement_rating
  leaderboard.players[user_id].placement_done = true
  logger.debug("FINAL PLACEMENT RATING for " .. (self.playerbase.players[user_id] or "nil") .. ": " .. (leaderboard.players[user_id].rating or "nil"))

  --Calculate changes to opponents ratings for placement matches won/lost
  logger.debug("adjusting opponent rating(s) for these placement matches")
  for i = 1, #placement_matches do
    if placement_matches[i].outcome == 0 then
      op_outcome = 1
    else
      op_outcome = 0
    end
    local op_rating_change = self:calculate_rating_adjustment(placement_matches[i].op_rating, leaderboard.players[user_id].placement_rating, op_outcome, 10) - placement_matches[i].op_rating
    leaderboard.players[placement_matches[i].op_user_id].rating = leaderboard.players[placement_matches[i].op_user_id].rating + op_rating_change
    leaderboard.players[placement_matches[i].op_user_id].ranked_games_played = (leaderboard.players[placement_matches[i].op_user_id].ranked_games_played or 0) + 1
    leaderboard.players[placement_matches[i].op_user_id].ranked_games_won = (leaderboard.players[placement_matches[i].op_user_id].ranked_games_won or 0) + op_outcome
  end
  leaderboard.players[user_id].placement_done = true
  write_leaderboard_file()
  move_user_placement_file_to_complete(user_id)
end

function Server:get_league(rating)
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

function Server:update()

  self:acceptNewConnections()

  self:readSockets()

  -- Only check once a second to avoid over checking
  -- (we are relying on time() returning a number rounded to the second)
  local currentTime = time()
  if currentTime ~= self.lastProcessTime then
    self:pingConnections(currentTime)
    
    self:flushLogs(currentTime)

    self.lastProcessTime = currentTime
  end

  -- If the lobby changed tell everyone
  self:broadCastLobbyIfChanged()
end

-- Accept any new connections to the server
function Server:acceptNewConnections()
  local newConnectionSocket = self.socket:accept()
  if newConnectionSocket then
    newConnectionSocket:settimeout(0)
    if TCP_NODELAY_ENABLED then
      newConnectionSocket:setoption("tcp-nodelay", true)
    end
    local connection = Connection(newConnectionSocket, self.connectionNumberIndex, self)
    logger.debug("Accepted connection " .. self.connectionNumberIndex)
    self.connections[self.connectionNumberIndex] = connection
    self.socketToConnectionIndex[newConnectionSocket] = self.connectionNumberIndex
    self.connectionNumberIndex = self.connectionNumberIndex + 1
  end
end

-- Process any data on all active connections
function Server:readSockets()
  -- Make a list of all the sockets to listen to
  local socketsToCheck = {self.socket}
  for _, v in pairs(self.connections) do
    socketsToCheck[#socketsToCheck + 1] = v.socket
  end

  -- Wait for up to 1 second to see if there is any data to read on all the given sockets
  local socketsWithData = socket.select(socketsToCheck, nil, 1)
  assert(type(socketsWithData) == "table")
  for _, currentSocket in ipairs(socketsWithData) do
    if self.socketToConnectionIndex[currentSocket] then
      local connectionIndex = self.socketToConnectionIndex[currentSocket]
      self.connections[connectionIndex]:read()
    end
  end
end

-- Check all active connections to make sure they have responded timely
function Server:pingConnections(currentTime)
  for _, connection in pairs(self.connections) do
    if currentTime - connection.lastCommunicationTime > 10 then
      logger.debug("Closing connection for " .. (connection.name or "nil") .. ". Connection timed out (>10 sec)")
      connection:close()
    elseif currentTime - connection.lastCommunicationTime > 1 then
      connection:send(NetworkProtocol.serverMessageTypes.ping.prefix) -- Request a ping to make sure the connection is still active
    end
  end
end
  
-- Flush the log so we can see new info periodically. The default caches for huge amounts of time.
function Server:flushLogs(currentTime)
  if currentTime - self.lastFlushTime > 60 then
    pcall(
      function()
        io.stdout:flush()
      end
    )
    self.lastFlushTime = currentTime
  end
end

function Server:broadCastLobbyIfChanged()
  if self.lobbyChanged then
    for _, connection in pairs(self.connections) do
      if connection.state == "lobby" then
        connection:send(self:lobby_state())
      end
    end
    self.lobbyChanged = false
  end
end

return Server

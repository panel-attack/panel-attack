local socket = require("socket")
local logger = require("logger")
require("class")
json = require("dkjson")
require("stridx")
require("gen_panels")
require("csprng")
require("server.server_file_io")
require("server.Connection")
require("server.Leaderboard")
require("server.PlayerBase")
require("server.Room")
require("util")
require("timezones")
local lfs = require("lfs")
local database = require("server.PADatabase")

local pairs = pairs
local ipairs = ipairs
local lobby_changed = false
local time = os.time
local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

SERVER_MODE = true -- global to know the server is running the process
local connectionNumberIndex = 1 -- GLOBAL counter of the next available connection index
local roomNumberIndex = 1 -- the next available room number
local rooms = {}  
local proposals = {}
local loaded_placement_matches = {
  incomplete = {},
  complete = {}
}


-- Represents the full server object.
-- Currently we are transitioning variables into this, but to start we will use this to define API
Server =
  class(
  function(s)
    s.connections = {} -- all connection objects
    s.name_to_idx = {} -- mapping of player names to their unique connectionNumberIndex
    s.socket_to_idx = {} -- mapping of sockets to their unique connectionNumberIndex
    s.database = database
  end
)

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
  lobby_changed = true
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
  for _, v in pairs(rooms) do
    spectatableRooms[#spectatableRooms + 1] = {roomNumber = v.roomNumber, name = v.name, a = v.a.name, b = v.b.name, state = v:state()}
    addPublicPlayerData(players, v.a.name, leaderboard.players[v.a.user_id])
    addPublicPlayerData(players, v.b.name, leaderboard.players[v.b.user_id])
  end
  return {unpaired = names, spectatable = spectatableRooms, players = players}
end

function Server:propose_game(sender, receiver, message)
  local s_c, r_c = self.name_to_idx[sender], self.name_to_idx[receiver]
  if s_c then
    s_c = self.connections[s_c]
  end
  if r_c then
    r_c = self.connections[r_c]
  end
  if s_c and s_c.state == "lobby" and r_c and r_c.state == "lobby" then
    proposals[sender] = proposals[sender] or {}
    proposals[receiver] = proposals[receiver] or {}
    if proposals[sender][receiver] then
      if proposals[sender][receiver][receiver] then
        self:create_room(s_c, r_c)
      end
    else
      r_c:send(message)
      local prop = {[sender] = true}
      proposals[sender][receiver] = prop
      proposals[receiver][sender] = prop
    end
  end
end

function Server:clear_proposals(name)
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

-- a and be are connection objects
function Server:create_room(a, b)
  lobby_changed = true
  self:clear_proposals(a.name)
  self:clear_proposals(b.name)
  local new_room = Room(a, b, roomNumberIndex, leaderboard)
  roomNumberIndex = roomNumberIndex + 1
  rooms[new_room.roomNumber] = new_room
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

function Server:start_match(a, b)
  if (a.player_number ~= 1) then
    logger.debug("Match starting, players a and b need to be swapped.")
    a, b = b, a
    if (a.player_number == 1) then
      logger.debug("Success, player a now has player_number 1.")
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

function Server:roomNumberToRoom(roomNr)
  for k, v in pairs(rooms) do
    if rooms[k].roomNumber and rooms[k].roomNumber == roomNr then
      return v
    end
  end
end

function generate_new_user_id()
  local new_user_id = cs_random()
  logger.debug("new_user_id: " .. new_user_id)
  return tostring(new_user_id)
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

function Server:closeRoom(room)
  room:close()
  if rooms[room.roomNumber] then
    rooms[room.roomNumber] = nil
  end
end

function Server:addSpectator(room, connection)
  room:add_spectator(connection)
  lobby_changed = true
end

function Server:removeSpectator(room, connection)
  lobby_changed = room:remove_spectator(connection)
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

function adjust_ratings(room, winning_player_number, gameID)
  logger.debug("Adjusting the rating of " .. room.a.name .. " and " .. room.b.name .. ". Player " .. winning_player_number .. " wins!")
  local players = {room.a, room.b}
  local continue = true
  local placement_match_progress
  room.ratings = {}
  for player_number = 1, 2 do
    --if they aren't on the leaderboard yet, give them the default rating
    if not leaderboard.players[players[player_number].user_id] or not leaderboard.players[players[player_number].user_id].rating then
      leaderboard.players[players[player_number].user_id] = {user_name = playerbase.players[players[player_number].user_id], rating = DEFAULT_RATING}
      logger.debug("Gave " .. playerbase.players[players[player_number].user_id] .. " a new rating of " .. DEFAULT_RATING)
      if not PLACEMENT_MATCHES_ENABLED then
        leaderboard.players[players[player_number].user_id].placement_done = true
        database:insertPlayerELOChange(players[player_number].user_id, DEFAULT_RATING, gameID)
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
        room.ratings[player_number].new = calculate_rating_adjustment(leaderboard.players[players[player_number].user_id].rating, leaderboard.players[players[player_number].opponent.user_id].rating, Oa, k)
        database:insertPlayerELOChange(players[player_number].user_id, room.ratings[player_number].new, gameID)
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
        logger.debug("New newcomer rating: " .. leaderboard.players[players[player_number].user_id].placement_rating)
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
      logger.debug(playerbase.players[players[player_number].user_id])
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
      room.ratings[player_number].league = get_league(room.ratings[player_number].new)
    end
  -- msg = {rating_updates=true, ratings=room.ratings, placement_match_progress=placement_match_progress}
  -- room:send(msg)
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
      logger.debug("no pre-existing placement matches file, starting fresh")
    end
    logger.debug(tostring(loaded_placement_matches.incomplete[user_id]))
    logger.debug(json.encode(loaded_placement_matches.incomplete[user_id]))
  else
    logger.debug("Didn't load placement matches from file. It is already loaded")
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
  logger.debug("FINAL PLACEMENT RATING for " .. (playerbase.players[user_id] or "nil") .. ": " .. (leaderboard.players[user_id].rating or "nil"))

  --Calculate changes to opponents ratings for placement matches won/lost
  logger.debug("adjusting opponent rating(s) for these placement matches")
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


function Server:broadcast_lobby()
  if lobby_changed then
    for _, v in pairs(self.connections) do
      if v.state == "lobby" then
        v:send(self:lobby_state())
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

local server_socket = nil

logger.info("Starting up server  with port: " .. (SERVER_PORT or 49569))
server_socket = socket.bind("*", SERVER_PORT or 49569) --for official server
--local server_socket = socket.bind("*", 59569) --for beta server
server_socket:settimeout(0)
if TCP_NODELAY_ENABLED then
  server_socket:setoption("tcp-nodelay", true)
end
local sep = package.config:sub(1, 1)
logger.debug("sep: " .. sep)
playerbase = Playerbase("playerbase")
read_players_file()
read_deleted_players_file()
leaderboard = Leaderboard("leaderboard")
read_leaderboard_file()


local function importDatabase()
  local usedNames = {}
  local cleanedPlayerData = {}
  for key, value in pairs(playerbase.players) do
    local name = value
    while usedNames[name] ~= nil do
      name = name .. math.random(1, 9999)
    end
    cleanedPlayerData[key] = value
    usedNames[name] = true
  end

  database:beginTransaction() -- this stops the database from attempting to commit every statement individually 
  logger.info("Importing leaderboard.csv to database")
  for k, v in pairs(cleanedPlayerData) do
    local rating = 0
    if leaderboard.players[k] then
      rating = leaderboard.players[k].rating
    end
    database:insertNewPlayer(k, v)
    database:insertPlayerELOChange(k, rating, 0)
  end

  local gameMatches = readGameResults()
  if gameMatches then -- only do it if there was a gameResults file to begin with
    logger.info("Importing GameResults.csv to database")
    for _, result in ipairs(gameMatches) do
      local player1ID = result[1]
      local player2ID = result[2]
      local player1Won = result[3] == 1
      local ranked = result[4] == 1
      local gameID = database:insertGame(ranked)
      if player1Won then
        database:insertPlayerGameResult(player1ID, gameID, nil,  1)
        database:insertPlayerGameResult(player2ID, gameID, nil,  2)
      else
        database:insertPlayerGameResult(player2ID, gameID, nil,  1)
        database:insertPlayerGameResult(player1ID, gameID, nil,  2)
      end
    end
  end
  database:commitTransaction() -- bulk commit every statement from the start of beginTransaction
end
  
local isPlayerTableEmpty = database:getPlayerRecordCount() == 0
if isPlayerTableEmpty then
  importDatabase()
end

logger.debug("leaderboard json:")
logger.debug(json.encode(leaderboard.players))
write_leaderboard_file()
logger.debug("Leagues")
for k, v in ipairs(leagues) do
  logger.debug(v.league .. ":  " .. v.min_rating)
end
logger.debug(os.time())
--TODO: remove test print for leaderboard
logger.debug("playerbase: " .. json.encode(playerbase.players))
logger.debug("leaderboard report: " .. json.encode(leaderboard:get_report()))
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
logger.debug("initialized!")
-- print("get_timezone() output: "..get_timezone())
-- print("get_timezone_offset(os.time()) output: "..get_timezone_offset(os.time()))
-- print("get_tzoffset(get_timezone()) output:"..get_tzoffset(get_timezone()))

local server = Server()

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
local prev_now = time()
local lastFlushTime = prev_now

function Server:update()
  server_socket:settimeout(0)
  if TCP_NODELAY_ENABLED then
    server_socket:setoption("tcp-nodelay", true)
  end

  -- Accept any new connections to the server
  local new_conn = server_socket:accept()
  if new_conn then
    new_conn:settimeout(0)
    if TCP_NODELAY_ENABLED then
      new_conn:setoption("tcp-nodelay", true)
    end
    local connection = Connection(new_conn, connectionNumberIndex, server)
    logger.debug("Accepted connection " .. connectionNumberIndex)
    server.connections[connectionNumberIndex] = connection
    server.socket_to_idx[new_conn] = connectionNumberIndex
    connectionNumberIndex = connectionNumberIndex + 1
  end

  -- Read from all the active connections
  local recvt = {server_socket}
  for _, v in pairs(server.connections) do
    recvt[#recvt + 1] = v.socket
  end
  local ready = socket.select(recvt, nil, 1)
  assert(type(ready) == "table")
  for _, v in ipairs(ready) do
    if server.socket_to_idx[v] then
      server.connections[server.socket_to_idx[v]]:read()
    end
  end

  -- Only check once a second to avoid over checking
  -- (we are relying on time() returning a number rounded to the second)
  local now = time()
  if now ~= prev_now then
    -- Check all active connections to make sure they have responded timely
    for _, v in pairs(server.connections) do
      if now - v.last_read > 10 then
        logger.debug("Closing connection for " .. (v.name or "nil") .. ". Connection timed out (>10 sec)")
        v:close()
      elseif now - v.last_read > 1 then
        v:send("ELOL") -- Request a ping to make sure the connection is still active
      end
    end
    
    -- Flush the log so we can see new info periodically. The default caches for huge amounts of time.
    if now - lastFlushTime > 60 then
      pcall(
        function()
          io.stdout:flush()
        end
      )
      lastFlushTime = now
    end

    prev_now = now
  end

  -- If the lobby changed tell everyone
  server:broadcast_lobby()
end

return server

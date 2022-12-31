require("class")
local logger = require("logger")

Room =
class(
function(self, a, b, roomNumber, leaderboard)
  --TODO: it would be nice to call players a and b something more like self.players[1] and self.players[2]
  self.a = a --player a
  self.b = b --player b
  self.stage = nil
  self.name = a.name .. " vs " .. b.name
  self.roomNumber = roomNumber
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
    logger.debug("initializing room. player a does not have player_number 1. Swapping players a and b")
    self.a, self.b = self.b, self.a
    if self.a.player_number == 1 then
      logger.debug("Success. player a has player_number 1 now.")
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
  return "character select"
elseif self.a.state == "playing" then
  return "playing"
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
  logger.debug(new_spectator_connection.name .. " joined " .. self.name .. " as a spectator")
  local msg = {
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
end

function Room.spectator_names(self)
  local list = {}
  for k, v in pairs(self.spectators) do
    list[#list + 1] = v.name
  end
  return list
end

function Room.remove_spectator(self, connection)
  local lobbyChanged = false
  for k, v in pairs(self.spectators) do
    if v.name == connection.name then
      self.spectators[k].state = "lobby"
      logger.debug(connection.name .. " left " .. self.name .. " as a spectator")
      self.spectators[k] = nil
      connection.room = nil
      lobbyChanged = true
    end
  end
  local msg = {spectators = self:spectator_names()}
  logger.debug("sending spectator list: " .. json.encode(msg))
  self:send(msg)
  return lobbyChanged
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
  self:send_to_spectators({leave_room = true})
end

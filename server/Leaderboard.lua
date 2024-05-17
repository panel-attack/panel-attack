local class = require("common.lib.class")
local logger = require("common.lib.logger")

-- Object that represents players rankings and placement matches, along with login times
Leaderboard =
  class(
  function(s, name, server)
    s.name = name
    s.server = server
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
      if self.server.playerbase.players[k] then --only include in the report players who are still listed in the playerbase
        if v.placement_done then --don't include players who haven't finished placement
          if v.rating then -- don't include entries who's rating is nil (which shouldn't happen anyway)
            if k == user_id_of_requester then
              player_is_leaderboard_requester = true
            end
            if report[insert_index] and report[insert_index].rating and v.rating >= report[insert_index].rating then
              table.insert(report, insert_index, {user_name = self.server.playerbase.players[k], rating = v.rating, is_you = player_is_leaderboard_requester})
              break
            elseif insert_index == leaderboard_player_count or #report == 0 then
              table.insert(report, {user_name = self.server.playerbase.players[k], rating = v.rating, is_you = player_is_leaderboard_requester}) -- at the end of the table.
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
    logger.debug(user_id .. "'s login timestamp has been updated to " .. timestamp)
  else
    logger.debug(user_id .. " is not on the leaderboard, so no timestamp will be assigned at this time.")
  end
end
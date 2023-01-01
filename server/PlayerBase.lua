require("class")
local logger = require("logger")

-- Represents all player accounts on the server.
Playerbase =
  class(
  function(s, name)
    s.name = name
    s.players = {}
    --{["e2016ef09a0c7c2fa70a0fb5b99e9674"]="Bob",
    --["d28ac48ba5e1a82e09b9579b0a5a7def"]="Alice"}
    s.deleted_players = {}
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

return Playerbase
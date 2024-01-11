require("class")
require("server.server_file_io")
local logger = require("logger")

-- Represents all player accounts on the server.
Playerbase =
  class(
  function(s, name, filename)
    s.name = name
    s.filename = filename
    s.players = {}
    --{["e2016ef09a0c7c2fa70a0fb5b99e9674"]="Bob",
    --["d28ac48ba5e1a82e09b9579b0a5a7def"]="Alice"}
  end
)

function Playerbase:addPlayer(userID, username)
  self:updatePlayer(userID, username)
end

function Playerbase:updatePlayer(user_id, user_name)
  self.players[user_id] = user_name
  write_players_file(self)
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

return Playerbase
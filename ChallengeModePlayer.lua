local MatchParticipant = require("MatchParticipant")
local class = require("class")

local ChallengeModePlayer = class(function(self)
  self.attackEngine = nil
  self.health = nil
end,
MatchParticipant)

function ChallengeModePlayer:createStackFromSettings(match, which)

end
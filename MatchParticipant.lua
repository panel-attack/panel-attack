local class = require("class")

-- a match participant represents the minimum spec for a what constitutes a "player" in a battleRoom / match
local MatchParticipant = class(function(self)
  self.name = "participant"
  self.wins = 0
  self.modifiedWins = 0
  self.settings = {
    characterId = random_character_special_value,
    stageId = random_stage_special_value
  }
end)

-- returns the count of wins modified by the `modifiedWins` property
function MatchParticipant:getWinCountForDisplay()
  return self.wins + self.modifiedWins
end

function MatchParticipant:setWinCount(count)
  self.wins = count
end

function MatchParticipant:incrementWinCount()
  self.wins = self.wins + 1
end

-- returns a table with some key properties on functions to be run as part of a match
function MatchParticipant:createStackFromSettings(match, which)
  error("MatchParticipant needs to implement function createStackFromSettings")
end

return MatchParticipant
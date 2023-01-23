local class = require("class")
local util = require("util")
local tableUtil = require("tableUtil")
local logger = require("logger")
local characterLoader = require("character_loader")

local players = {}
-- stage
-- character
-- level
-- panels
-- ranked
-- ready
-- playerNumber
-- rating

local MatchSetup = class(
  function(match, playerCount, mode, online)
    match.playerCount = playerCount
    match.mode = mode
    match.online = online
    for i = 1, playerCount do
      players[i] = {}
    end
  end
)

function MatchSetup.setStage(player, stageId)
  players[player].stageId = stageId

end

function MatchSetup.setCharacter(player, characterId)
  players[player].characterId = characterId
  characterLoader.load(characterId)
end

return MatchSetup
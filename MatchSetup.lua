local class = require("class")
local util = require("util")
local tableUtil = require("tableUtil")
local logger = require("logger")

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
  end
)

function MatchSetup.func()

end

return MatchSetup
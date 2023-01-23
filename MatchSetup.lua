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

local GameSetup = class(
  function(game, playerCount, mode)
    game.playerCount = playerCount
    game.mode = mode
  end
)

function GameSetup.func()

end

return GameSetup
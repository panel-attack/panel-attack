local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")
local Signal = require("helpers.signal")

--@module endlessGame
-- Scene for an endless mode instance of the game
local Game1pTraining = class(
  function (self, sceneParams)
    self.nextScene = "CharacterSelectVsSelf"

    self:load(sceneParams)
    self.match:connectSignal("matchEnded", self, self.onMatchEnded)
  end,
  GameBase
)

Game1pTraining.name = "VsSelfGame"
sceneManager:addScene(Game1pTraining)

function Game1pTraining:onMatchEnded(match)
  local P1 = match.players[1].stack
  Replay.finalizeAndWriteReplay("Training", "training-L" .. P1.level, match.replay)
end

return Game1pTraining
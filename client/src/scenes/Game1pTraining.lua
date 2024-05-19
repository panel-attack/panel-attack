local GameBase = require("client.src.scenes.GameBase")
local sceneManager = require("client.src.scenes.sceneManager")
local Replay = require("common.engine.Replay")
local class = require("common.lib.class")

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
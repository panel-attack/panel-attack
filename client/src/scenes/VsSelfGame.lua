local GameBase = require("client.src.scenes.GameBase")
local sceneManager = require("client.src.scenes.sceneManager")
local Replay = require("common.engine.Replay")
local class = require("common.lib.class")

--@module endlessGame
-- Scene for an endless mode instance of the game
local VsSelfGame = class(
  function (self, sceneParams)
    self.nextScene = "CharacterSelectVsSelf"

    self:load(sceneParams)
    self.match:connectSignal("matchEnded", self, self.onMatchEnded)
  end,
  GameBase
)

VsSelfGame.name = "VsSelfGame"
sceneManager:addScene(VsSelfGame)

function VsSelfGame:onMatchEnded(match)
  local P1 = match.players[1].stack
  GAME.scores:saveVsSelfScoreForLevel(P1.analytic.data.sent_garbage_lines, P1.level)
  Replay.finalizeAndWriteReplay("Vs Self", "vsSelf-L" .. P1.level, match.replay)
end

return VsSelfGame
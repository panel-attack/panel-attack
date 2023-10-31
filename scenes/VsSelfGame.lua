local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("Replay")
local class = require("class")

--@module endlessGame
-- Scene for an endless mode instance of the game
local VsSelfGame = class(
  function (self, sceneParams)
    self.nextScene = "VsSelfMenu"
    self.winnerSFX = GAME.match.P1:pick_win_sfx()
    
    self:load(sceneParams)
  end,
  GameBase
)

VsSelfGame.name = "VsSelfGame"
sceneManager:addScene(VsSelfGame)

function VsSelfGame:processGameResults(gameResult)
  local P1 = GAME.match.players[1]
  GAME.scores:saveVsSelfScoreForLevel(P1.analytic.data.sent_garbage_lines, P1.level)
  Replay.finalizeAndWriteVsReplay(nil, nil, false, GAME.match, replay)
end

function VsSelfGame:abortGame()
  sceneManager:switchToScene(self.nextScene)
end

return VsSelfGame
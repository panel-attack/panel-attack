local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")

--@module endlessGame
-- Scene for an endless mode instance of the game
local Game2pVs = class(
  function (self, sceneParams)
    self.nextScene = sceneParams.nextScene

    self:load(sceneParams)
    self.winnerSFX = self.S1:pick_win_sfx()
  end,
  GameBase
)

Game2pVs.name = "Game2pVs"
sceneManager:addScene(Game2pVs)

function Game2pVs:processGameResults(gameResult)
  Replay.finalizeAndWriteVsReplay(GAME.battleRoom, nil, false, self.match, replay)
end

function Game2pVs:abortGame()
  sceneManager:switchToScene(self.nextScene)
end

return Game2pVs
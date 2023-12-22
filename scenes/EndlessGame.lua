local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")

--@module endlessGame
-- Scene for an endless mode instance of the game
local EndlessGame = class(
  function (self, sceneParams)
    self.nextScene = "EndlessMenu"

    self:load(sceneParams)
    self.winnerSFX = self.S1:pick_win_sfx()
  end,
  GameBase
)

EndlessGame.name = "EndlessGame"
sceneManager:addScene(EndlessGame)

function EndlessGame:processGameResults(gameResult)
  local extraPath, extraFilename
  if self.S1.level == nil then
    GAME.scores:saveEndlessScoreForLevel(self.S1.score, self.S1.difficulty)
    extraPath = "Endless"
    extraFilename = "Spd" .. self.S1.speed .. "-Dif" .. self.S1.difficulty .. "-endless"
    Replay.finalizeAndWriteReplay(extraPath, extraFilename, self.match.replay)
  end
end

return EndlessGame
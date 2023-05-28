local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")

--@module endlessGame
-- Scene for an endless mode instance of the game
local EndlessGame = class(
  function (self, sceneParams)
    self.nextScene = "EndlessMenu"
    self.winnerSFX = GAME.match.P1:pick_win_sfx()
    
    self:load(sceneParams)
  end,
  GameBase
)

EndlessGame.name = "EndlessGame"
sceneManager:addScene(EndlessGame)

function EndlessGame:processGameResults(gameResult) 
  local extraPath, extraFilename
  if GAME.match.P1.level == nil then
    GAME.scores:saveEndlessScoreForLevel(GAME.match.P1.score, GAME.match.P1.difficulty)
    extraPath = "Endless"
    extraFilename = "Spd" .. GAME.match.P1.speed .. "-Dif" .. GAME.match.P1.difficulty .. "-endless"
    Replay.finalizeAndWriteReplay(extraPath, extraFilename, GAME.match, replay)
  end
end

function EndlessGame:abortGame()
  sceneManager:switchToScene("EndlessMenu")
end

return EndlessGame
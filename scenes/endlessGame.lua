local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")

--@module endlessGame
-- Scene for an endless mode instance of the game
local endlessGame = GameBase("endlessGame", {})

function endlessGame:processGameResults(gameResult)
  local extraPath, extraFilename
  if GAME.match.P1.level == nil then
    GAME.scores:saveEndlessScoreForLevel(GAME.match.P1.score, GAME.match.P1.difficulty)
    extraPath = "Endless"
    extraFilename = "Spd" .. GAME.match.P1.speed .. "-Dif" .. GAME.match.P1.difficulty .. "-endless"
    Replay.finalizeAndWriteReplay(extraPath, extraFilename, GAME.match, replay)
  end
end

function endlessGame:abortGame()
  sceneManager:switchToScene("endlessMenu")
end

function endlessGame:customGameOverSetup()
  self.winnerSFX = GAME.match.P1:pick_win_sfx()
  self.nextScene = "endlessMenu"
end

return endlessGame
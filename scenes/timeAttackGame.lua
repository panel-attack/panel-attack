local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local replay = require("replay")

--@module timeAttackGame
-- Scene for an time attack mode instance of the game
local timeAttackGame = GameBase("timeAttackGame", {})

function timeAttackGame:processGameResults(gameResult) 
  local extraPath, extraFilename
  if GAME.match.P1.level == nil then
    GAME.scores:saveTimeAttack1PScoreForLevel(GAME.match.P1.score, GAME.match.P1.difficulty)
    extraPath = "Time Attack"
    extraFilename = "Spd" .. GAME.match.P1.speed .. "-Dif" .. GAME.match.P1.difficulty .. "-timeattack"
    replay.finalizeAndWriteReplay(extraPath, extraFilename)
  end
end

function timeAttackGame:abortGame()
  sceneManager:switchToScene("timeAttackMenu")
end

function timeAttackGame:customGameOverSetup()
  self.winnerSFX = GAME.match.P1:pick_win_sfx()
  self.nextScene = "timeAttackMenu"
end

return timeAttackGame
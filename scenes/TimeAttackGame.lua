local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("Replay")
local class = require("class")

--@module timeAttackGame
-- Scene for an time attack mode instance of the game
local TimeAttackGame = class(
  function (self, sceneParams)
    self.winnerSFX = GAME.match.P1:pick_win_sfx()
    self.nextScene = "TimeAttackMenu"
  
    self:load(sceneParams)
  end,
  GameBase
)

TimeAttackGame.name = "TimeAttackGame"
sceneManager:addScene(TimeAttackGame)

function TimeAttackGame:processGameResults(gameResult) 
  local extraPath, extraFilename
  if GAME.match.P1.level == nil then
    GAME.scores:saveTimeAttack1PScoreForLevel(GAME.match.P1.score, GAME.match.P1.difficulty)
    extraPath = "Time Attack"
    extraFilename = "Spd" .. GAME.match.P1.speed .. "-Dif" .. GAME.match.P1.difficulty .. "-timeattack"
    Replay.finalizeAndWriteReplay(extraPath, extraFilename, GAME.match, replay)
  end
end

function TimeAttackGame:abortGame()
  sceneManager:switchToScene("TimeAttackMenu")
end

return TimeAttackGame
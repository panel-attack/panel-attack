local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local Replay = require("replay")
local class = require("class")

--@module timeAttackGame
-- Scene for an time attack mode instance of the game
local TimeAttackGame = class(
  function (self, sceneParams)
    self.nextScene = "TimeAttackMenu"
    
    self:load(sceneParams)
    self.winnerSFX = self.S1:pick_win_sfx()
  end,
  GameBase
)

TimeAttackGame.name = "TimeAttackGame"
sceneManager:addScene(TimeAttackGame)

function TimeAttackGame:processGameResults(gameResult) 
  local extraPath, extraFilename
  if self.S1.level == nil then
    GAME.scores:saveTimeAttack1PScoreForLevel(self.S1.score, self.S1.difficulty)
    extraPath = "Time Attack"
    extraFilename = "Spd" .. self.S1.speed .. "-Dif" .. self.S1.difficulty .. "-timeattack"
    Replay.finalizeAndWriteReplay(extraPath, extraFilename, self.match, replay)
  end
end

return TimeAttackGame
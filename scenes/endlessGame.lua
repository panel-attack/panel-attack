local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")

--@module endless_game
local endlessGame = GameBase("endlessGame", {})

function endlessGame:processGameResults(gameResult) 
  local extraPath, extraFilename
  if GAME.match.P1.level == nil then
    GAME.scores:saveEndlessScoreForLevel(GAME.match.P1.score, GAME.match.P1.difficulty)
    extraPath = "Endless"
    extraFilename = "Spd" .. GAME.match.P1.speed .. "-Dif" .. GAME.match.P1.difficulty .. "-endless"
    self:finalizeAndWriteReplay(extraPath, extraFilename)
  end
end

function endlessGame:abortGame()
  sceneManager:switchToScene("endlessMenu")
end

function endlessGame:customGameOverSetup()
  self.winner_SFX = GAME.match.P1:pick_win_sfx()
  self.next_scene = "endlessMenu"
end

return endlessGame
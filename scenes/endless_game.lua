local GameBase = require("scenes.GameBase")

--@module endless_game
local endless_game = GameBase("endless_game", {})

function endless_game:processGameResults(gameResult) 
  local extraPath, extraFilename
  if GAME.match.P1.level == nil then
    GAME.scores:saveEndlessScoreForLevel(GAME.match.P1.score, GAME.match.P1.difficulty)
    extraPath = "Endless"
    extraFilename = "Spd" .. GAME.match.P1.speed .. "-Dif" .. GAME.match.P1.difficulty .. "-endless"
    self:finalizeAndWriteReplay(extraPath, extraFilename)
  end
end

return endless_game
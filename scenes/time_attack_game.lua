local GameBase = require("scenes.GameBase")

--@module time_attack_game
local time_attack_game = GameBase("time_attack_game", {})

function time_attack_game:processGameResults(gameResult) 
  local extraPath, extraFilename
  if GAME.match.P1.level == nil then
    GAME.scores:saveTimeAttack1PScoreForLevel(GAME.match.P1.score, GAME.match.P1.difficulty)
    extraPath = "Time Attack"
    extraFilename = "Spd" .. GAME.match.P1.speed .. "-Dif" .. GAME.match.P1.difficulty .. "-timeattack"
    self:finalizeAndWriteReplay(extraPath, extraFilename)
  end
end

return time_attack_game
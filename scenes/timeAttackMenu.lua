local SimpleGameSetupMenu = require("scenes.SimpleGameSetupMenu")

--@module timeAttackMenu
-- Scene for the time attack game setup menu
local timeAttackMenu = SimpleGameSetupMenu("timeAttackMenu", {gameMode = "time", gameScene = "timeAttackGame"})

function timeAttackMenu:getScores(difficulty)
  return {tostring(GAME.scores:lastTimeAttack1PForLevel(difficulty)), tostring(GAME.scores:recordTimeAttack1PForLevel(difficulty))}
end

return timeAttackMenu
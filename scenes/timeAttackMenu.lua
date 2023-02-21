local BasicMenu = require("scenes.BasicMenu")

--@module timeAttackMenu
local timeAttackMenu = BasicMenu("timeAttackMenu", {gameMode = "time", gameScene = "timeAttackGame"})

function timeAttackMenu:getScores(difficulty)
  return {tostring(GAME.scores:lastTimeAttack1PForLevel(difficulty)), tostring(GAME.scores:recordTimeAttack1PForLevel(difficulty))}
end

return timeAttackMenu
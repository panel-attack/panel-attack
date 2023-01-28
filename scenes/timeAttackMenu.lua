local BasicMenu = require("scenes.BasicMenu")

--@module timeAttackMenu
local timeAttackMenu = BasicMenu("timeAttackMenu", {game_mode = "time", game_scene = "timeAttackGame"})

function timeAttackMenu:getScores(difficulty)
  return {tostring(GAME.scores:lastTimeAttack1PForLevel(difficulty)), tostring(GAME.scores:recordTimeAttack1PForLevel(difficulty))}
end

return timeAttackMenu
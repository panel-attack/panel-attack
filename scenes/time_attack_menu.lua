local BasicMenu = require("scenes.BasicMenu")

--@module time_attack_menu
local time_attack_menu = BasicMenu("time_attack_menu", {game_mode = "time", game_scene = "time_attack_game"})

function time_attack_menu:getScores(difficulty)
  return {tostring(GAME.scores:lastTimeAttack1PForLevel(difficulty)), tostring(GAME.scores:recordTimeAttack1PForLevel(difficulty))}
end

return time_attack_menu
local BasicMenu = require("scenes.BasicMenu")

--@module endless_menu
local endless_menu = BasicMenu("endless_menu", {game_mode = "endless"})

function endless_menu:getScores(difficulty)
  return {tostring(GAME.scores:lastEndlessForLevel(difficulty)), tostring(GAME.scores:recordEndlessForLevel(difficulty))}
end

return endless_menu
local BasicMenu = require("scenes.BasicMenu")

--@module endlessMenu
local endlessMenu = BasicMenu("endlessMenu", {game_mode = "endless", game_scene = "endlessGame"})

function endlessMenu:getScores(difficulty)
  return {tostring(GAME.scores:lastEndlessForLevel(difficulty)), tostring(GAME.scores:recordEndlessForLevel(difficulty))}
end

return endlessMenu
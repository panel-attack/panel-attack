local BasicMenu = require("scenes.BasicMenu")

--@module endlessMenu
local endlessMenu = BasicMenu("endlessMenu", {gameMode = "endless", gameScene = "endlessGame"})

function endlessMenu:getScores(difficulty)
  return {tostring(GAME.scores:lastEndlessForLevel(difficulty)), tostring(GAME.scores:recordEndlessForLevel(difficulty))}
end

return endlessMenu
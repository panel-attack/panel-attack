local SimpleGameSetupMenu = require("scenes.SimpleGameSetupMenu")

--@module endlessMenu
-- Scene for the endless game setup menu
local endlessMenu = SimpleGameSetupMenu("endlessMenu", {gameMode = "endless", gameScene = "endlessGame"})

function endlessMenu:getScores(difficulty)
  return {tostring(GAME.scores:lastEndlessForLevel(difficulty)), tostring(GAME.scores:recordEndlessForLevel(difficulty))}
end

return endlessMenu
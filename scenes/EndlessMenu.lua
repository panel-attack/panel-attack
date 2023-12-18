local SimpleGameSetupMenu = require("scenes.SimpleGameSetupMenu")
local sceneManager = require("scenes.sceneManager")
local class = require("class")
local GameModes = require("GameModes")

--@module endlessMenu
-- Scene for the endless game setup menu
local EndlessMenu = class(
  function(self, sceneParams)
    self.gameMode = GameModes.getPreset("ONE_PLAYER_ENDLESS")
    self.gameScene = "EndlessGame"

    self:load(sceneParams)
  end,
  SimpleGameSetupMenu
)

EndlessMenu.name = "EndlessMenu"
sceneManager:addScene(EndlessMenu)

function EndlessMenu:getScores(difficulty)
  return {tostring(GAME.scores:lastEndlessForLevel(difficulty)), tostring(GAME.scores:recordEndlessForLevel(difficulty))}
end



return EndlessMenu
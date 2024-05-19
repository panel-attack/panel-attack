local SimpleGameSetupMenu = require("client.src.scenes.SimpleGameSetupMenu")
local sceneManager = require("client.src.scenes.sceneManager")
local class = require("common.lib.class")
local GameModes = require("common.engine.GameModes")

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
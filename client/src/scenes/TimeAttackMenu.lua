local SimpleGameSetupMenu = require("client.src.scenes.SimpleGameSetupMenu")
local class = require("common.lib.class")
local GameModes = require("common.engine.GameModes")
local TimeAttackGame = require("client.src.scenes.TimeAttackGame")

--@module timeAttackMenu
-- Scene for the time attack game setup menu
local TimeAttackMenu = class(
  function(self, sceneParams)
    self.gameMode = GameModes.getPreset("ONE_PLAYER_TIME_ATTACK")
    self.gameScene = "TimeAttackGame"

    self:load(sceneParams)
  end,
  SimpleGameSetupMenu
)

TimeAttackMenu.name = "TimeAttackMenu"

function TimeAttackMenu:getScores(difficulty)
  return {tostring(GAME.scores:lastTimeAttack1PForLevel(difficulty)), tostring(GAME.scores:recordTimeAttack1PForLevel(difficulty))}
end

return TimeAttackMenu
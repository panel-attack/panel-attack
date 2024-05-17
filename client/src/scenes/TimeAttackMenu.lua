local SimpleGameSetupMenu = require("scenes.SimpleGameSetupMenu")
local sceneManager = require("scenes.sceneManager")
local class = require("class")
local GameModes = require("GameModes")

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
sceneManager:addScene(TimeAttackMenu)

function TimeAttackMenu:getScores(difficulty)
  return {tostring(GAME.scores:lastTimeAttack1PForLevel(difficulty)), tostring(GAME.scores:recordTimeAttack1PForLevel(difficulty))}
end

return TimeAttackMenu
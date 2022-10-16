local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")

--@module training_mode_game
local training_mode_game = GameBase("training_mode_game", {})

function training_mode_game:customLoad(scene_params)
  GAME.match.P1:starting_state()
  local trainingModeSettings = GAME.battleRoom.trainingModeSettings
  local delayBeforeStart = trainingModeSettings.delayBeforeStart or 0
  local delayBeforeRepeat = trainingModeSettings.delayBeforeRepeat or 0
  local disableQueueLimit = trainingModeSettings.disableQueueLimit or false
  GAME.match.attackEngine = AttackEngine(GAME.match.P1, delayBeforeStart, delayBeforeRepeat, disableQueueLimit)
  for _, values in ipairs(trainingModeSettings.attackPatterns) do
    if values.chain then
      if type(values.chain) == "number" then
        for i = 1, values.height do
          GAME.match.attackEngine:addAttackPattern(6, i, values.startTime + ((i-1) * values.chain), false, true)
        end
        GAME.match.attackEngine:addEndChainPattern(values.startTime + ((values.height - 1) * values.chain) + values.chainEndDelta)
      elseif type(values.chain) == "table" then
        for i, chainTime in ipairs(values.chain) do
          GAME.match.attackEngine:addAttackPattern(6, i, chainTime, false, true)
        end
        GAME.match.attackEngine:addEndChainPattern(values.chainEndTime)
      else
        error("The 'chain' field in your attack file is invalid. It should either be a number or a list of numbers.")
      end
    else
      GAME.match.attackEngine:addAttackPattern(values.width, values.height or 1, values.startTime, values.metal or false, false)
    end
  end

  GAME.match.P2 = nil
end

function training_mode_game:abortGame()
  sceneManager:switchToScene("training_mode_menu")
end

function training_mode_game:customGameOverSetup()
  self.winner_SFX = GAME.match.P1:pick_win_sfx()
  self.next_scene = "training_mode_character_select"
  self.next_scene_params = nil
end

function training_mode_game:processGameResults(gameResult)
end

return training_mode_game
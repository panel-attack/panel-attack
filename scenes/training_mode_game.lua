local GameBase = require("scenes.GameBase")
local scene_manager = require("scenes.scene_manager")
local input = require("input2")

--@module training_mode_game
local training_mode_game = GameBase("training_mode_game", {})

function training_mode_game:customLoad(scene_params)
  GAME.match.P1:starting_state()
  GAME.match.attackEngine = AttackEngine(GAME.match.P1)
  local startTime = 150
  local delayPerAttack = 6
  local attackCountPerDelay = 15
  local delay = GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME + (attackCountPerDelay * delayPerAttack) + 1
  for i = 1, attackCountPerDelay, 1 do
    GAME.match.attackEngine:addAttackPattern(GAME.battleRoom.trainingModeSettings.width, GAME.battleRoom.trainingModeSettings.height, startTime + (i * delayPerAttack) --[[start time]], delay--[[repeat]], nil--[[attack count]], false--[[metal]],  false--[[chain]])  
  end

  GAME.match.P2 = nil
end

function training_mode_game:abortGame()
  scene_manager:switchScene("training_mode_menu")
end

function training_mode_game:customGameOverSetup()
  self.winner_SFX = GAME.match.P1:pick_win_sfx()
  self.next_scene = "training_mode_character_select"
  self.next_scene_params = nil
end

function training_mode_game:processGameResults(gameResult)
end

return training_mode_game
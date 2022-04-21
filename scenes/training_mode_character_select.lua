local CharacterSelect = require("scenes.CharacterSelect")

--@module training_mode_character_select
local training_mode_character_select = CharacterSelect(
  "training_mode_character_select", 
  {previous_scene = "training_mode_menu"})

function training_mode_character_select:matchSetup(match)
  GAME.match.attackEngine = AttackEngine(GAME.match.P1)
  local startTime = 150
  local delayPerAttack = 6
  local attackCountPerDelay = 15
  local delay = GARBAGE_TRANSIT_TIME + GARBAGE_TELEGRAPH_TIME + (attackCountPerDelay * delayPerAttack) + 1
  for i = 1, attackCountPerDelay, 1 do
    GAME.match.attackEngine:addAttackPattern(GAME.battleRoom.trainingModeSettings.width, GAME.battleRoom.trainingModeSettings.height, startTime + (i * delayPerAttack) --[[start time]], delay--[[repeat]], nil--[[attack count]], false--[[metal]],  false--[[chain]])  
  end
end

return training_mode_character_select
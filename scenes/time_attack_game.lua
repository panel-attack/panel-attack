local GameBase = require("scenes.GameBase")
local scene_manager = require("scenes.scene_manager")

--@module time_attack_game
local time_attack_game = GameBase("time_attack_game", {})

function time_attack_game:processGameResults(gameResult) 
  local extraPath, extraFilename
  if GAME.match.P1.level == nil then
    GAME.scores:saveTimeAttack1PScoreForLevel(GAME.match.P1.score, GAME.match.P1.difficulty)
    extraPath = "Time Attack"
    extraFilename = "Spd" .. GAME.match.P1.speed .. "-Dif" .. GAME.match.P1.difficulty .. "-timeattack"
    self:finalizeAndWriteReplay(extraPath, extraFilename)
  end
end

function time_attack_game:abortGame()
  scene_manager:switchScene("time_attack_menu")
end

function time_attack_game:customGameOverSetup()
  self.winner_SFX = GAME.match.P1:pick_win_sfx()
  self.next_scene = "time_attack_menu"
end

return time_attack_game
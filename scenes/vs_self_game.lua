local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local Replay = require("replay")

--@module vs_self_game
local vs_self_game = GameBase("vs_self_game", {})

function vs_self_game:customLoad(scene_params)
  GAME.match.P1:starting_state()
  GAME.match.P1:set_garbage_target(GAME.match.P1)

  GAME.match.P2 = nil
end

function vs_self_game:abortGame()
  sceneManager:switchToScene("vs_self_menu")
end

function vs_self_game:customGameOverSetup()
  self.winner_SFX = GAME.match.P1:pick_win_sfx()
  self.nextScene = "vs_self_menu"
  self.nextSceneParams = nil
end

function vs_self_game:processGameResults(gameResult)
  GAME.scores:saveVsSelfScoreForLevel(GAME.match.P1.analytic.data.sent_garbage_lines, GAME.match.P1.level)
  Replay.finalizeAndWriteVsReplay(nil, nil, false, GAME.match, replay)
end

return vs_self_game
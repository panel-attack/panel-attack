local GameBase = require("scenes.GameBase")
local scene_manager = require("scenes.scene_manager")
local input = require("input2")

--@module replay_game
local replay_game = GameBase("replay_game", {})

function replay_game:customLoad(scene_params)
  self.frameAdvance = false
  self.playbackSpeed = 1
  self.maximumSpeed = 20

  loadFromReplay(replay)
end

function replay_game:customRun()
  -- If we just finished a frame advance, pause again
  if self.frameAdvance then
    self.frameAdvance = false
    GAME.gameIsPaused = true
  end

  -- Advance one frame
  if input.isDown["Swap1"] and not self.frameAdvance then
    self.frameAdvance = true
    GAME.gameIsPaused = false
    if GAME.match.P1 then
      GAME.match.P1.max_runs_per_frame = 1
    end
    if GAME.match.P2 then
      GAME.match.P2.max_runs_per_frame = 1
    end
  elseif input:isPressedWithRepeat("Right", .25, .05) then
    self.playbackSpeed = bound(1, self.playbackSpeed + 1, self.maximumSpeed)
    if GAME.match.P1 then
      GAME.match.P1.max_runs_per_frame = self.playbackSpeed
    end
    if GAME.match.P2 then
      GAME.match.P2.max_runs_per_frame = self.playbackSpeed
    end
  elseif input:isPressedWithRepeat("Left", .25, .05) then
    self.playbackSpeed = bound(1, self.playbackSpeed - 1, self.maximumSpeed)
    if GAME.match.P1 then
      GAME.match.P1.max_runs_per_frame = self.playbackSpeed
    end
    if GAME.match.P2 then
      GAME.match.P2.max_runs_per_frame = self.playbackSpeed
    end
  end
end

function replay_game:abortGame()
  scene_manager:switchScene("replay_menu")
end

function replay_game:customGameOverSetup()
  self.next_scene = "replay_menu"
  self.next_scene_params = nil

  if GAME.match.P2 and GAME.match.battleRoom:matchOutcome() then
    self.text = matchOutcome["end_text"]
    self.winner_SFX = matchOutcome["winSFX"]
  else
    self.winner_SFX = GAME.match.P1:pick_win_sfx()
  end
end

return replay_game
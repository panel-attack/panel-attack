local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local consts = require("consts")
local util = require("util")
local Replay = require("replay")
local class = require("class")

--@module replayGame
local ReplayGame = class(
  function (self, sceneParams)
    self:init()
    self:load(sceneParams)
  end,
  GameBase
)

ReplayGame.name = "ReplayGame"
sceneManager:addScene(ReplayGame)

function ReplayGame:customLoad(scene_params)
  self.frameAdvance = false
  self.playbackSpeed = 1
  self.maximumSpeed = 20

  Replay.loadFromFile(replay)
end

function ReplayGame:customRun()
  -- If we just finished a frame advance, pause again
  if self.frameAdvance then
    self.frameAdvance = false
    GAME.gameIsPaused = true
  end

  -- Advance one frame
  if input:isPressedWithRepeat("FrameAdvance", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) and not self.frameAdvance then
    self.frameAdvance = true
    GAME.gameIsPaused = false
    if GAME.match.P1 then
      GAME.match.P1.max_runs_per_frame = 1
    end
    if GAME.match.P2 then
      GAME.match.P2.max_runs_per_frame = 1
    end
  elseif input:isPressedWithRepeat("Right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.playbackSpeed = util.bound(-1, self.playbackSpeed + 1, self.maximumSpeed)
    if GAME.match.P1 then
      GAME.match.P1.max_runs_per_frame = math.max(self.playbackSpeed, 0)
    end
    if GAME.match.P2 then
      GAME.match.P2.max_runs_per_frame = math.max(self.playbackSpeed, 0)
    end
  elseif input:isPressedWithRepeat("Left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.playbackSpeed = util.bound(-1, self.playbackSpeed - 1, self.maximumSpeed)
    if GAME.match.P1 then
      GAME.match.P1.max_runs_per_frame = math.max(self.playbackSpeed, 0)
    end
    if GAME.match.P2 then
      GAME.match.P2.max_runs_per_frame = math.max(self.playbackSpeed, 0)
    end
  end
  
  if self.playbackSpeed == -1 then
    if GAME.match.P1 and GAME.match.P1.CLOCK > 0 and GAME.match.P1.prev_states[GAME.match.P1.CLOCK-1] then
      GAME.match.P1:rollbackToFrame(GAME.match.P1.CLOCK-1)
      GAME.match.P1.lastRollbackFrame = -1 -- We don't want to count this as a "rollback" because we don't want to catchup
    end
    if GAME.match.P2 and GAME.match.P2.CLOCK > 0 and GAME.match.P2.prev_states[P2.CLOCK-1] then
      GAME.match.P2:rollbackToFrame(GAME.match.P2.CLOCK-1)
      GAME.match.P2.lastRollbackFrame = -1 -- We don't want to count this as a "rollback" because we don't want to catchup
    end
  end
end

function ReplayGame:abortGame()
  sceneManager:switchToScene("ReplayBrowser")
end

function ReplayGame:customGameOverSetup()
  self.nextScene = "ReplayBrowser"
  self.nextSceneParams = nil

  if GAME.match.P2 and GAME.match.battleRoom:matchOutcome() then
    local matchOutcome = GAME.match.battleRoom:matchOutcome()
    self.text = matchOutcome["end_text"]
    self.winner_SFX = matchOutcome["winSFX"]
  else
    self.winner_SFX = GAME.match.P1:pick_win_sfx()
  end
end

return ReplayGame
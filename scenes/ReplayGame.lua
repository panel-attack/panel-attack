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
    self.frameAdvance = false
    self.playbackSpeeds = {-1, 0, 1, 2, 3, 4, 8, 16}
    self.playbackSpeedIndex = 3
  
    self:load(sceneParams)
  end,
  GameBase
)

ReplayGame.name = "ReplayGame"
sceneManager:addScene(ReplayGame)

function ReplayGame:customLoad()
  -- replays don't have a battleRoom so the match is just loaded from replay but not started yet
  self.match:start()
end

function ReplayGame:customRun()
  -- If we just finished a frame advance, pause again
  if self.frameAdvance then
    self.frameAdvance = false
    self.match.isPaused = true
  end

  local playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]

  -- Advance one frame
  if input:isPressedWithRepeat("Swap1", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) and not self.frameAdvance then
    self.frameAdvance = true
    self.match.isPaused = false
    if self.match.P1 then
      self.match.P1.max_runs_per_frame = 1
    end
    if self.match.P2 then
      self.match.P2.max_runs_per_frame = 1
    end
  elseif input:isPressedWithRepeat("MenuRight", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.playbackSpeedIndex = util.bound(1, self.playbackSpeedIndex + 1, #self.playbackSpeeds)
    playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]
    if self.match.P1 then
      self.match.P1.max_runs_per_frame = math.max(playbackSpeed, 0)
    end
    if self.match.P2 then
      self.match.P2.max_runs_per_frame = math.max(playbackSpeed, 0)
    end
  elseif input:isPressedWithRepeat("MenuLeft", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.playbackSpeedIndex = util.bound(1, self.playbackSpeedIndex - 1, #self.playbackSpeeds)
    playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]
    if self.match.P1 then
      self.match.P1.max_runs_per_frame = math.max(playbackSpeed, 0)
    end
    if self.match.P2 then
      self.match.P2.max_runs_per_frame = math.max(playbackSpeed, 0)
    end
  end

  if playbackSpeed < 0 and not self.match.isPaused then
    if self.match.P1 and self.match.P1.clock > 0 and self.match.P1.prev_states[match.P1.clock-1] then
      self.match.P1:rollbackToFrame(match.P1.clock + playbackSpeed)
      self.match.P1.lastRollbackFrame = -1 -- We don't want to count this as a "rollback" because we don't want to catchup
    end
    if self.match.P2 and self.match.P2.clock > 0 and self.match.P2.prev_states[match.P2.clock-1] then
      self.match.P2:rollbackToFrame(match.P2.clock + playbackSpeed)
      self.match.P2.lastRollbackFrame = -1 -- We don't want to count this as a "rollback" because we don't want to catchup
    end
  end
end

function ReplayGame:customDraw()
  local textPos = themes[config.theme].gameover_text_Pos
  local playbackText = self.playbackSpeeds[self.playbackSpeedIndex] .. "x"
  gprintf(playbackText, textPos[0], textPos[1], canvas_width, "center", nil, 1, large_font)
end

function ReplayGame:customGameOverSetup()
  self.nextScene = "ReplayBrowser"
  self.nextSceneParams = nil
end

return ReplayGame
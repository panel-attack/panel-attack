local GameBase = require("client.src.scenes.GameBase")
local input = require("common.lib.inputManager")
local consts = require("common.engine.consts")
local util = require("common.lib.util")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

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

function ReplayGame:runGame()
  local playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]

  if self.match:hasEnded() and playbackSpeed < 0 then
    -- maybe we can rewind from death this way
    self.match.ended = false
  end

  if not self.match.isPaused then
    if playbackSpeed > 0 then
      for i = 1, playbackSpeed do
        self.match:run()
      end
    elseif playbackSpeed < 0 then
      self.match:rewindToFrame(self.match.clock + playbackSpeed)
    end
  else
    if self.frameAdvance then
      self.match:togglePause()
      if playbackSpeed > 0 then
        self.match:run()
      elseif playbackSpeed < 0 then
        self.match:rewindToFrame(self.match.clock - 1)
      end
      self.frameAdvance = false
      self.match.isPaused = true
    end
  end

  -- Advance one frame
  if input:isPressedWithRepeat("Swap1", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.frameAdvance = true
  elseif input.isDown["Swap1"] then
    if self.match.isPaused then
      self.frameAdvance = true
    else
      self.match:togglePause()
      if self.match.isPaused then
        SoundController:pauseMusic()
      else
        SoundController:playMusic(self.musicSource.stageTrack)
      end
    end
  elseif input:isPressedWithRepeat("MenuRight") then
    self.playbackSpeedIndex = util.bound(1, self.playbackSpeedIndex + 1, #self.playbackSpeeds)
    playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]
  elseif input:isPressedWithRepeat("MenuLeft") then
    self.playbackSpeedIndex = util.bound(1, self.playbackSpeedIndex - 1, #self.playbackSpeeds)
    playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]
  elseif input.isDown["Swap2"] then
    if self.match.isPaused then
      GAME.navigationStack:pop()
    end
  elseif input.isDown["MenuPause"] then
    self.match:togglePause()
    if self.musicSource then
      if self.match.isPaused then
        SoundController:pauseMusic()
      else
        SoundController:playMusic(self.musicSource.stageTrack)
      end
    end
  end

  if self.match.isPaused and input.isDown["MenuEsc"] then
    self.match:abort()
    return
  end
end

-- maybe we can rewind from death this way
ReplayGame.runGameOver = ReplayGame.runGame

function ReplayGame:customDraw()
  local textPos = themes[config.theme].gameover_text_Pos
  local playbackText = self.playbackSpeeds[self.playbackSpeedIndex] .. "x"
  GraphicsUtil.printf(playbackText, textPos[0], textPos[1], consts.CANVAS_WIDTH, "center", nil, 1, 10)
end

function ReplayGame:customGameOverSetup()
  self.nextScene = "ReplayBrowser"
  self.nextSceneParams = nil
end

function ReplayGame:drawHUD()
  for i, stack in ipairs(self.match.stacks) do
    if config.show_ingame_infos then
      stack:drawScore()
      stack:drawSpeed()
      stack:drawMultibar()
    end

    -- Draw VS HUD
    if stack.player then
      stack:drawPlayerName()
      stack:drawWinCount()
      stack:drawRating()
    end

    stack:drawLevel()
    if stack.analytic then
      stack:drawAnalyticData()
    end
  end
end

return ReplayGame
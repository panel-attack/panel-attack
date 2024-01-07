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
      setMusicPaused(self.match.isPaused)
    end
  elseif input:isPressedWithRepeat("MenuRight", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.playbackSpeedIndex = util.bound(1, self.playbackSpeedIndex + 1, #self.playbackSpeeds)
    playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]
  elseif input:isPressedWithRepeat("MenuLeft", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
    self.playbackSpeedIndex = util.bound(1, self.playbackSpeedIndex - 1, #self.playbackSpeeds)
    playbackSpeed = self.playbackSpeeds[self.playbackSpeedIndex]
  elseif input.isDown["Swap2"] then
    if self.match.isPaused then
      sceneManager:switchToScene(sceneManager:createScene("ReplayBrowser"))
    end
  elseif input.isDown["MenuPause"] then
    self.match:togglePause()
    setMusicPaused(self.match.isPaused)
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
  gprintf(playbackText, textPos[0], textPos[1], canvas_width, "center", nil, 1, large_font)
end

function ReplayGame:customGameOverSetup()
  self.nextScene = "ReplayBrowser"
  self.nextSceneParams = nil
end

return ReplayGame
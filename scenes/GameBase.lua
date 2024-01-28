local class = require("class")
local Scene = require("scenes.Scene")
local GraphicsUtil = require("graphics_util")
local logger = require("logger")
local analytics = require("analytics")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local save = require("save")
local tableUtils = require("tableUtils")
local Menu = require("ui.Menu")
local consts = require("consts")
local Signal = require("helpers.signal")

--@module GameBase
-- Scene template for running any type of game instance (endless, vs-self, replays, etc.)
local GameBase = class(
  function (self, sceneParams)
    -- must be set in child class
    self.nextScene = nil
    self.nextSceneParams = {}

    -- set in load
    self.text = ""
    self.keepMusic = false
    self.currentStage = config.stage
    self.loadStageAndMusic = true

    self.minDisplayTime = 1 -- the minimum amount of seconds the game over screen will be displayed for
    self.maxDisplayTime = -1 -- the maximum amount of seconds the game over screen will be displayed for, -1 means no max time

    self.frameInfo = {
      frameCount = nil,
      startTime = nil,
      currentTime = nil,
      expectedFrameCount = nil
    }
  end,
  Scene
)

-- begin abstract functions

-- Game mode specific game state setup
-- Called during load()
function GameBase:customLoad(sceneParams) end

-- Game mode specific behavior for leaving the game
-- called during runGame()
function GameBase:abortGame() end

-- Game mode specific behavior for running the game
-- called during runGame()
function GameBase:customRun() end

-- Game mode specific state setup for a game over
-- called during setupGameOver()
function GameBase:customGameOverSetup() end

-- end abstract functions

local function pickUseMusicFrom()
  if config.use_music_from == "stage" or config.use_music_from == "characters" then
    current_use_music_from = config.use_music_from
    return
  end
  local percent = math.random(1, 4)
  if config.use_music_from == "either" then
    current_use_music_from = percent <= 2 and "stage" or "characters"
  elseif config.use_music_from == "often_stage" then
    current_use_music_from = percent == 1 and "characters" or "stage"
  else
    current_use_music_from = percent == 1 and "stage" or "characters"
  end
end

function GameBase:initializeFrameInfo()
  self.frameInfo.startTime = nil
  self.frameInfo.frameCount = 0
end

function GameBase:load(sceneParams)
  self.match = sceneParams.match
  self.match:connectSignal("matchEnded", self, self.genericOnMatchEnded)

  self.stage = stages[self.match.stageId]
  self.backgroundImage = UpdatingImage(self.stage.images.background, false, 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  pickUseMusicFrom()

  self:customLoad(sceneParams)

  leftover_time = 1 / 120

  self:initializeFrameInfo()
end

function GameBase:handlePause()
  if self.match.supportsPause and (input.isDown["MenuPause"] or (not GAME.focused and not self.match.isPaused)) then
    if self.match.isPaused then
      self:initializeFrameInfo()
    end
    self.match:togglePause()

    setMusicPaused(self.match.isPaused)
    Menu.playValidationSfx()
  end
end

local gameOverStartTime = nil -- timestamp for when game over screen was first displayed
local initialMusicVolumes = {}

function GameBase:setupGameOver()
  gameOverStartTime = love.timer.getTime()
  self.minDisplayTime = 1 -- the minimum amount of seconds the game over screen will be displayed for
  self.maxDisplayTime = -1
  initialMusicVolumes = {}
  
  self:customGameOverSetup()

  -- The music may have already been partially faded due to dynamic music or something else,
  -- record what volume it was so we can fade down from that.
  for k, v in pairs(currently_playing_tracks) do
    initialMusicVolumes[v] = v:getVolume()
  end
end

function GameBase:runGameOver()
  local font = GraphicsUtil.getGlobalFont()

  GraphicsUtil.print(self.text, (consts.CANVAS_WIDTH - font:getWidth(self.text)) / 2, 10)
  GraphicsUtil.print(loc("continue_button"), (consts.CANVAS_WIDTH - font:getWidth(loc("continue_button"))) / 2, 10 + 30)
  -- wait()
  local displayTime = love.timer.getTime() - gameOverStartTime
  if not self.keepMusic then
    -- Fade the music out over time
    local fadeMusicLength = 3
    if displayTime <= fadeMusicLength then
      local percentage = (fadeMusicLength - displayTime) / fadeMusicLength
      for k, v in pairs(initialMusicVolumes) do
        local volume = v * percentage
        setFadePercentageForGivenTracks(volume, {k}, true)
      end
    else
      if displayTime > fadeMusicLength then
        setMusicFadePercentage(1) -- reset the music back to normal config volume
        stop_the_music()
      end
    end
  end

  self.match:run()

  -- if conditions are met, leave the game over screen
  local keyPressed = tableUtils.trueForAny(input.isDown, function(key) return key end)

  if ((displayTime >= self.maxDisplayTime and self.maxDisplayTime ~= -1) or (displayTime >= self.minDisplayTime and keyPressed)) then
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    setMusicFadePercentage(1) -- reset the music back to normal config volume
    if not self.keepMusic then
      stop_the_music()
    end
    SFX_GameOver_Play = 0
    sceneManager:switchToScene(sceneManager:createScene(self.nextScene, self.nextSceneParams))
  end
end

function GameBase:runGame(dt)
  if self.frameInfo.startTime == nil then
    self.frameInfo.startTime = love.timer.getTime()
  end

  local framesRun = 0
  self.frameInfo.currentTime = love.timer.getTime()
  self.frameInfo.expectedFrameCount = math.ceil((self.frameInfo.currentTime - self.frameInfo.startTime) * 60)
  repeat
    self.frameInfo.frameCount = self.frameInfo.frameCount + 1
    framesRun = framesRun + 1
    self.match:run()
  until (self.frameInfo.frameCount >= self.frameInfo.expectedFrameCount)

  self:customRun()
  
  self:handlePause()

  if self.match.isPaused and input.isDown["MenuEsc"] then
    Menu.playCancelSfx()
    self.match:abort()
    return
  end

  if self.match:hasEnded() then
    self:setupGameOver()
    return
  end
end

function GameBase:update(dt)
  if self.match:hasEnded() then
    self:runGameOver()
  else
    if not self.match:hasLocalPlayer() then
      if input.isDown["MenuEsc"] then
        Menu.playCancelSfx()
        self.match:abort()
        if GAME.tcpClient:isConnected() then
          GAME.battleRoom:shutdown()
          sceneManager:switchToScene(sceneManager:createScene("Lobby"))
        else
          sceneManager:switchToScene(sceneManager:createScene("ReplayBrowser"))
        end
      end
    end
    self:runGame(dt)
  end
end

function GameBase:draw()
  self:drawBackground()
  self.match:render()
  self:drawHUD()
  if self.customDraw then
    self:customDraw()
  end
  self:drawForegroundOverlay()
end

function GameBase:drawBackground()
  if self.backgroundImage then
    self.backgroundImage:draw()
  end
  local backgroundOverlay = themes[config.theme].images.bg_overlay
  if backgroundOverlay then
    backgroundOverlay:draw()
  end
end

function GameBase:drawForegroundOverlay()
  local foregroundOverlay = themes[config.theme].images.fg_overlay
  if foregroundOverlay then
    foregroundOverlay:draw()
  end
end

function GameBase:drawHUD()
  for i, stack in ipairs(self.match.stacks) do
    if stack.puzzle then
      stack:drawMoveCount()
    end
    if config.show_ingame_infos then
      if not self.puzzle then
        stack:drawScore()
        stack:drawSpeed()
      end
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

function GameBase:genericOnMatchEnded(match)
  -- matches always sort players to have locals in front so if 1 isn't local, none is
  if match.players[1].isLocal then
    analytics.game_ends(match.players[1].stack.analytic)
  end
end

return GameBase
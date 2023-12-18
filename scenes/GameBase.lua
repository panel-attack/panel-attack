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
local Replay = require("replay")

--@module GameBase
-- Scene template for running any type of game instance (endless, vs-self, replays, etc.)
local GameBase = class(
  function (self, sceneParams)
    -- must be set in child class
    self.nextScene = nil
    self.nextSceneParams = {}
    
    -- set in load
    self.shouldAbortGame = false
    self.text = ""
    self.winnerSFX = nil
    self.keepMusic = false
    self.currentStage = config.stage
    self.loadStageAndMusic = true
    
    self.minDisplayTime = 1 -- the minimum amount of seconds the game over screen will be displayed for
    self.maxDisplayTime = -1 -- the maximum amount of seconds the game over screen will be displayed for, -1 means no max time
    self.winnerTime = 1
    
    self.frameInfo = {
      frameCount = nil,
      startTime = nil,
      currentTime = nil,
      expectedFrameCount = nil
    }
    
    self.transition = false
  end,
  Scene
)

-- begin abstract functions

-- Game mode specific post processing on the final game result (saving scores, replays, etc.)
-- Called during unload()
function GameBase:processGameResults(gameResult) end

-- Game mode specific game state setup
-- Called during load()
function GameBase:customLoad(sceneParams) end

-- Game mode specific behavior for leaving the game
-- called during runGame()
function GameBase:abortGame() end

-- Game mode specific behavior for running the game
-- called during runGame()
function GameBase:customRun() end

-- Game mode specific behaviour for drawing on top of what match:render draws
-- called during runGame()
function GameBase:customDraw() end

-- Game mode specific state setup for a game over
-- called during setupGameOver()
function GameBase:customGameOverSetup() end

-- end abstract functions

local backgroundImage = nil

function GameBase:pickRandomStage()
  self.currentStage = tableUtils.getRandomElement(stages_ids_for_current_theme)
  if stages[self.currentStage]:is_bundle() then -- may pick a bundle!
    self.currentStage = tableUtils.getRandomElement(stages[self.currentStage].sub_stages)
  end
end

function GameBase:useCurrentStage()
  if config.stage == consts.RANDOM_STAGE_SPECIAL_VALUE then
    self:pickRandomStage()
  end
  current_stage = self.currentStage
  
  StageLoader.load(self.currentStage)
  StageLoader.wait()
  backgroundImage = UpdatingImage(stages[self.currentStage].images.background, false, 0, 0, canvas_width, canvas_height)
end

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
  self:customLoad(sceneParams)
  self.S1 = self.match.players[1].stack
  self.S2 = self.match.players[2] and self.match.players[2].stack or nil

  leftover_time = 1 / 120
  self.shouldAbortGame = false
  self.loadStageAndMusic = true
  if sceneParams.loadStageAndMusic ~= nil then
    self.loadStageAndMusic = sceneParams.loadStageAndMusic
  end
  if self.loadStageAndMusic then
    self:useCurrentStage()
    pickUseMusicFrom()
  end

  self:initializeFrameInfo()
end

function GameBase:drawForeground()
  
end

function GameBase:handlePause()
  if self.match.supportsPause and (input.isDown["MenuPause"] or (not GAME.focused and not GAME.gameIsPaused)) then
    if GAME.gameIsPaused then
      self:initializeFrameInfo()
    end
    GAME.gameIsPaused = not GAME.gameIsPaused

    setMusicPaused(GAME.gameIsPaused)
    Menu.playValidationSfx()
    if not GAME.renderDuringPause then
      if GAME.gameIsPaused then
        reset_filters()
      end
    end
  end
end

local font = GraphicsUtil.getGlobalFont()
local gameOverStartTime = nil -- timestamp for when game over screen was first displayed
local initialMusicVolumes = {}

function GameBase:setupGameOver()
  gameOverStartTime = love.timer.getTime() 
  self.minDisplayTime = 1 -- the minimum amount of seconds the game over screen will be displayed for
  self.maxDisplayTime = -1
  self.winnerTime = 60
  initialMusicVolumes = {}
  
  self:customGameOverSetup()

  if SFX_GameOver_Play == 1 then
    themes[config.theme].sounds.game_over:play()
    SFX_GameOver_Play = 0
  else
    self.winnerTime = 0
  end

  -- The music may have already been partially faded due to dynamic music or something else,
  -- record what volume it was so we can fade down from that.
  for k, v in pairs(currently_playing_tracks) do
    initialMusicVolumes[v] = v:getVolume()
  end
end

function GameBase:runGameOver()
  gprint(self.text, (canvas_width - font:getWidth(self.text)) / 2, 10)
  gprint(loc("continue_button"), (canvas_width - font:getWidth(loc("continue_button"))) / 2, 10 + 30)
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

  
  -- Play the winner sound effect after a delay
  if not SFX_mute then
    if displayTime >= self.winnerTime then
      if self.winnerSFX ~= nil then -- play winnerSFX then nil it so it doesn't loop
        self.winnerSFX:play()
        self.winnerSFX = nil
      end
    end
  end

  self.match:run()


  if GAME.tcpClient:isConnected() then
    GAME.tcpClient:processIncomingMessages()  -- recieve messages so we know if the next game is in the queue
  end

  -- if conditions are met, leave the game over screen
  local keyPressed = tableUtils.trueForAny(input.isDown, function(key) return key end)
  
  if not self.transitioning and ((displayTime >= self.maxDisplayTime and self.maxDisplayTime ~= -1) or (displayTime >= self.minDisplayTime and keyPressed)) then
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    setMusicFadePercentage(1) -- reset the music back to normal config volume
    if not self.keepMusic then
      stop_the_music()
    end
    SFX_GameOver_Play = 0
    self.transitioning = true
    sceneManager:switchToScene(self.nextScene, self.nextSceneParams)
  end
  
  GAME.gfx_q:push({self.match.render, {self.match}})
end

function GameBase:runGame(dt)
  if self.frameInfo.startTime == nil then
    self.frameInfo.startTime = love.timer.getTime()
  end
  
  local framesRun = 0
  self.frameInfo.currentTime = love.timer.getTime()
  self.frameInfo.expectedFrameCount = math.ceil((self.frameInfo.currentTime - self.frameInfo.startTime) * 60)
  local abort = false
  repeat 
    self.frameInfo.frameCount = self.frameInfo.frameCount + 1
    framesRun = framesRun + 1
    if self:customRun() then
      abort = true
      break
    end
    self.match:run()
  until (self.frameInfo.frameCount >= self.frameInfo.expectedFrameCount)
  if abort then
    return
  end
  
  if framesRun > 1 then
    GAME.droppedFrames = GAME.droppedFrames + framesRun - 1
  end

  if not ((self.S1 and self.S1.play_to_end) or (self.match.players[2] and self.S2.play_to_end)) then
    self:handlePause()

    if GAME.gameIsPaused and input.isDown["MenuEsc"] then
      self:abortGame()
      Menu.playCancelSfx()
      self.shouldAbortGame = true
    end
  end

  if self.shouldAbortGame then
    return
  end

  if self.S1:gameResult() then
    self:setupGameOver()
    return
  end
end

function GameBase:update(dt)
  if self.S1:gameResult() then
    self:runGameOver()
  else
    self:runGame(dt)
  end
end

function GameBase:draw()
  backgroundImage:draw()
  local backgroundOverlay = themes[config.theme].images.bg_overlay
  if backgroundOverlay then
    local scale = consts.CANVAS_WIDTH / math.max(backgroundOverlay:getWidth(), backgroundOverlay:getHeight()) -- keep image ratio
    menu_drawf(backgroundOverlay, consts.CANVAS_WIDTH / 2, consts.CANVAS_HEIGHT / 2, "center", "center", 0, scale, scale)
  end
-- Render only if we are not catching up to a current spectate match
  if not (self.S1 and self.S1.play_to_end) and not (self.S2 and self.S2.play_to_end) then
    self.match:render()
    self:customDraw()
  end

  local foregroundOverlay = themes[config.theme].images.fg_overlay
  if foregroundOverlay then
    local scale = consts.CANVAS_WIDTH / math.max(foregroundOverlay:getWidth(), foregroundOverlay:getHeight()) -- keep image ratio
    menu_drawf(foregroundOverlay, consts.CANVAS_WIDTH / 2, consts.CANVAS_HEIGHT / 2, "center", "center", 0, scale, scale)
  end
end

function GameBase:unload()
  local gameResult = self.S1:gameResult()
  if gameResult then
    self:processGameResults(gameResult)
  end
  analytics.game_ends(self.S1.analytic)
  GAME:clearMatch()
end

return GameBase
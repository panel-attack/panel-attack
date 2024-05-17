local class = require("common.lib.class")
local Scene = require("common.src.scenes.Scene")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local logger = require("common.lib.logger")
local analytics = require("client.src.analytics")
local sceneManager = require("client.src.scenes.sceneManager")
local input = require("common.lib.inputManager")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local StageLoader = require("client.src.mods.StageLoader")
local ModController = require("client.src.mods.ModController")
local SoundController = require("client.src.music.SoundController")

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

-- returns "stage" or "character" depending on which should be used according to the config.use_music_from setting
function GameBase:getPreferredMusicSourceType()
  if config.use_music_from == "stage" or config.use_music_from == "characters" then
    return config.use_music_from
  end

  local percent = math.random(1, 4)
  if config.use_music_from == "either" then
    return (percent <= 2 and "stage" or "characters")
  elseif config.use_music_from == "often_stage" then
    return (percent == 1 and "characters" or "stage")
  else
    return (percent == 1 and "stage" or "characters")
  end
end

-- returns the stage or character that is used as the music source
-- returns nil in case none of them has music
function GameBase:pickMusicSource()
  local character = self.match:getWinningPlayerCharacter()
  local stageHasMusic = self.stage.musics and self.stage.musics["normal_music"]
  local characterHasMusic = character and character.musics and character.musics["normal_music"]
  local preferredMusicSourceType = self:getPreferredMusicSourceType()

  if not stageHasMusic and not characterHasMusic then
    return nil
  elseif (preferredMusicSourceType == "stage" and stageHasMusic) or not characterHasMusic then
    return self.stage
  else --if preferredMusicSourceType == "characters" and characterHasMusic then
    return character
  end
end

-- unlike regular asset load, this function connects the used assets to the match so they cannot be unloaded
function GameBase:loadAssets(match)
  for i, player in ipairs(match.players) do
    local character = characters[player.settings.characterId]
    logger.debug("Force loading character " .. character.id .. " as part of GameBase:load")
    ModController:loadModFor(character, player, true)
    character:register(match)
  end

  if not match.stageId then
    logger.debug("Match has somehow no stageId at GameBase:load()")
    match.stageId = StageLoader.fullyResolveStageSelection(match.stageId)
  end
  local stage = stages[match.stageId]
  if stage.fully_loaded then
    logger.debug("Match stage " .. stage.id .. " already fully loaded in GameBase:load()")
    stage:register(match)
  else
    logger.debug("Force loading stage " .. stage.id .. " as part of GameBase:load")
    ModController:loadModFor(stage, match, true)
  end
end

function GameBase:initializeFrameInfo()
  self.frameInfo.startTime = nil
  self.frameInfo.frameCount = 0
end

function GameBase:load(sceneParams)
  self:loadAssets(sceneParams.match)
  self.match = sceneParams.match
  self.match:connectSignal("matchEnded", self, self.genericOnMatchEnded)
  self.match:connectSignal("dangerMusicChanged", self, self.changeMusic)
  self.match:connectSignal("countdownEnded", self, self.onGameStart)

  self.stage = stages[self.match.stageId]
  self.backgroundImage = UpdatingImage(self.stage.images.background, false, 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  self.musicSource = self:pickMusicSource()
  if self.musicSource.stageTrack and not self.keepMusic then
    -- reset the track to make sure it starts from the default settings
    self.musicSource.stageTrack:stop()
  end

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

    if self.match.isPaused then
      SoundController:pauseMusic()
    elseif self.musicSource then
      SoundController:playMusic(self.musicSource.stageTrack)
    end
    GAME.theme:playValidationSfx()
  end

  if self.match.isPaused and input.isDown["MenuEsc"] then
    GAME.theme:playCancelSfx()
    self.match:abort()
  end
end

local gameOverStartTime = nil -- timestamp for when game over screen was first displayed

function GameBase:setupGameOver()
  gameOverStartTime = love.timer.getTime()
  self.minDisplayTime = 1 -- the minimum amount of seconds the game over screen will be displayed for
  self.maxDisplayTime = -1

  SoundController:fadeOutActiveTrack(3)

  self:customGameOverSetup()
end

function GameBase:runGameOver()
  local font = GraphicsUtil.getGlobalFont()

  GraphicsUtil.print(self.text, (consts.CANVAS_WIDTH - font:getWidth(self.text)) / 2, 10)
  GraphicsUtil.print(loc("continue_button"), (consts.CANVAS_WIDTH - font:getWidth(loc("continue_button"))) / 2, 10 + 30)
  -- wait()
  local displayTime = love.timer.getTime() - gameOverStartTime

  self.match:run()

  -- if conditions are met, leave the game over screen
  local keyPressed = (tableUtils.length(input.isDown) > 0) or (tableUtils.length(input.mouse.isDown) > 0)

  if ((displayTime >= self.maxDisplayTime and self.maxDisplayTime ~= -1) or (displayTime >= self.minDisplayTime and keyPressed)) then
    GAME.theme:playValidationSfx()
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
  GAME.droppedFrames = GAME.droppedFrames + (framesRun - 1)

  self:customRun()

  self:handlePause()
end

function GameBase:musicCanChange()
  -- technically this condition shouldn't keep music from changing, just from actually playing above 0% volume
  -- this may become a use case when users can change volume from any scene in the game
  if GAME.muteSound then
    return false
  end

  if self.match.isPaused then
    return false
  end

  -- someone is still catching up
  if tableUtils.trueForAny(self.match.players, function(p) return p.stack.play_to_end end) then
    return false
  end

  -- music waits until countdown is over
  if self.match.doCountdown and self.match.clock < (consts.COUNTDOWN_START + consts.COUNTDOWN_LENGTH) then
    return false
  end

  if self.match.ended then
    return false
  end

  return true
end

function GameBase:onGameStart(match)
  if self.musicSource then
    SoundController:playMusic(self.musicSource.stageTrack)
  end
end

function GameBase:changeMusic(useDangerMusic)
  if self.musicSource and self.musicSource.stageTrack and self:musicCanChange() then
    self.musicSource.stageTrack:changeMusic(useDangerMusic)
  end
end

function GameBase:update(dt)
  if self.match:hasEnded() then
    self:runGameOver()
  else
    if not self.match:hasLocalPlayer() then
      if input.isDown["MenuEsc"] then
        GAME.theme:playCancelSfx()
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
  if not self.match.isPaused then
    for i, stack in ipairs(self.match.stacks) do
      if stack.puzzle then
        stack:drawMoveCount()
      end
      if config.show_ingame_infos then
        if not stack.puzzle then
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
    self:drawCommunityMessage()
  end
end

function GameBase:genericOnMatchEnded(match)
  self:setupGameOver()
  -- matches always sort players to have locals in front so if 1 isn't local, none is
  if match.players[1].isLocal then
    analytics.game_ends(match.players[1].stack.analytic)
  end
end

return GameBase

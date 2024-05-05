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

function GameBase:waitForAssets(match)
  for i = 1, #match.players do
    CharacterLoader.load(match.players[i].settings.characterId)
    CharacterLoader.wait()
  end

  if not match.stageId then
    match.stageId = StageLoader.fullyResolveStageSelection(match.stageId)
    StageLoader.load(match.stageId)
  end
  StageLoader.wait()
end

function GameBase:initializeFrameInfo()
  self.frameInfo.startTime = nil
  self.frameInfo.frameCount = 0
end

function GameBase:load(sceneParams)
  self:waitForAssets(sceneParams.match)
  self.match = sceneParams.match
  self.match:connectSignal("matchEnded", self, self.genericOnMatchEnded)
  self.match:connectSignal("dangerMusicChanged", self, self.changeMusic)

  self.stage = stages[self.match.stageId]
  self.backgroundImage = UpdatingImage(self.stage.images.background, false, 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
  self.musicSource = self:pickMusicSource()

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
  local keyPressed = (tableUtils.length(input.isDown) > 0) or (tableUtils.length(input.mouse.isDown) > 0)

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
  self:updateMusic()

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

function GameBase:musicCanChange()
  -- technically this condition shouldn't keep music from changing, just from actually playing above 0% volume
  -- this may become a use case when users can change volume from any scene in the game
  if GAME.muteSoundEffects then
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

local musicFadeLength = 60
function GameBase:updateMusic()
  -- Update Music
  if self.musicSource and self:musicCanChange() then
    -- if we don't have danger music, the music can never change
    if self.match.currentMusicIsDanger and not self.musicSource.musics["danger_music"] then
      return
    end

    -- only dynamic music needs persistent updates beyond state changes
    if self.musicSource.music_style == "dynamic" then
      if not self.fade_music_clock then
        self.fade_music_clock = musicFadeLength -- start fully faded in
      end

      local normalMusic = {self.musicSource.musics["normal_music"], self.musicSource.musics["normal_music_start"]}
      local dangerMusic = {self.musicSource.musics["danger_music"], self.musicSource.musics["danger_music_start"]}

      if #currently_playing_tracks == 0 then
        find_and_add_music(self.musicSource.musics, "normal_music")
        find_and_add_music(self.musicSource.musics, "danger_music")
      end

      if self.fade_music_clock < musicFadeLength then
        self.fade_music_clock = self.fade_music_clock + 1
      end

      local fadePercentage = self.fade_music_clock / musicFadeLength
      if self.match.currentMusicIsDanger then
        setFadePercentageForGivenTracks(1 - fadePercentage, normalMusic)
        setFadePercentageForGivenTracks(fadePercentage, dangerMusic)
      else
        setFadePercentageForGivenTracks(fadePercentage, normalMusic)
        setFadePercentageForGivenTracks(1 - fadePercentage, dangerMusic)
      end
    else
      if #currently_playing_tracks == 0 then
        find_and_add_music(self.musicSource.musics, "normal_music")
      end
    end
  end
end

function GameBase:changeMusic(useDangerMusic)
  if self.musicSource and self:musicCanChange() then
    if self.musicSource.music_style == "dynamic" then
      if not self.fade_music_clock or self.fade_music_clock >= musicFadeLength then
        self.fade_music_clock = 0 -- Do a full fade
      else
        -- switched music before we fully faded, so start part way through
        self.fade_music_clock = musicFadeLength - self.fade_music_clock
      end
    else -- classic music style
      if self.musicSource.musics.danger_music then
        if useDangerMusic then
          stop_the_music()
          find_and_add_music(self.musicSource.musics, "danger_music")
        else
          stop_the_music()
          find_and_add_music(self.musicSource.musics, "normal_music")
        end
      end
    end
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
  end
end

function GameBase:genericOnMatchEnded(match)
  -- matches always sort players to have locals in front so if 1 isn't local, none is
  if match.players[1].isLocal then
    analytics.game_ends(match.players[1].stack.analytic)
  end
end

return GameBase
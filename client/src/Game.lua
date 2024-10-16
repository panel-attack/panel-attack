require("client.src.localization")
require("common.lib.Queue")
require("client.src.server_queue")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local StageLoader = require("client.src.mods.StageLoader")
local Panels = require("client.src.mods.Panels")
require("client.src.mods.Theme")

-- The main game object for tracking everything in Panel Attack.
-- Not to be confused with "Match" which is the current battle / instance of the game.
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local analytics = require("client.src.analytics")
local input = require("common.lib.inputManager")
local save = require("client.src.save")
local fileUtils = require("client.src.FileUtils")
local handleShortcuts = require("client.src.Shortcuts")
local Player = require("client.src.Player")
local GameModes = require("common.engine.GameModes")
local NetClient = require("client.src.network.NetClient")
local StartUp = require("client.src.scenes.StartUp")
local SoundController = require("client.src.music.SoundController")
require("client.src.BattleRoom")
local prof = require("common.lib.jprof.jprof")

local RichPresence = require("client.lib.rich_presence.RichPresence")

-- Provides a scale that is on .5 boundary to make sure it renders well.
-- Useful for creating new canvas with a solid DPI
local function newCanvasSnappedScale(self)
  local result = math.max(1, math.floor(self.canvasXScale*2)/2)
  return result
end

local Game = class(
  function(self)
    self.scores = require("client.src.scores")
    self.input = input
    self.match = nil -- Match - the current match going on or nil if inbetween games
    self.battleRoom = nil -- BattleRoom - the current room being used for battles
    self.focused = true -- if the window is focused
    self.backgroundImage = nil -- the background image for the game, should always be set to something with the proper dimensions
    self.droppedFrames = 0
    self.puzzleSets = {} -- all the puzzles loaded into the game
    self.netClient = NetClient()
    self.server_queue = ServerQueue()
    self.main_menu_screen_pos = {consts.CANVAS_WIDTH / 2 - 108 + 50, consts.CANVAS_HEIGHT / 2 - 111}
    self.config = config
    self.localization = Localization
    self.replay = {}
    self.currently_paused_tracks = {} -- list of tracks currently paused
    self.rich_presence = RichPresence()
    self.rich_presence:initialize("902897593049301004")

    self.muteSound = false
    self.canvasX = 0
    self.canvasY = 0
    self.canvasXScale = 1
    self.canvasYScale = 1
    self.backgroundColor = { 0.0, 0.0, 0.0 }

    -- depends on canvasXScale
    self.globalCanvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=newCanvasSnappedScale(self)})

    self.automaticScales = {1, 1.5, 2, 2.5, 3}
    -- specifies a time that is compared against self.timer to determine if GameScale should be shown
    self.showGameScaleUntil = 0
    self.needsAssetReload = false
    self.previousWindowWidth = 0
    self.previousWindowHeight = 0

    self.crashTrace = nil -- set to the trace of your thread before throwing an error if you use a coroutine

    -- private members
    self.pointer_hidden = false
    self.last_x = 0
    self.last_y = 0
    self.input_delta = 0.0

    -- misc
    self.rich_presence = RichPresence()
    -- time in seconds, can be used by other elements to track the passing of time beyond dt
    self.timer = love.timer.getTime()
  end
)

Game.newCanvasSnappedScale = newCanvasSnappedScale

function Game:load()
  -- TODO: include this with save.lua?
  require("client.src.puzzles")
  -- move to constructor
  self.updater = GAME_UPDATER or nil
  if self.updater then
    logger.debug("Launching game with updater")
    local success = pcall(self.updater.init, self.updater)
    if not success then
      logger.debug("updater:init failed")
      self.updater = nil
    end
  else
    logger.debug("Launching game without updater")
  end
  local user_input_conf = save.read_key_file()
  if user_input_conf then
    self.input:importConfigurations(user_input_conf)
  end

  self.navigationStack = require("client.src.NavigationStack")
  self.navigationStack:push(StartUp({setupRoutine = self.setupRoutine}))
  self.globalCanvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=GAME:newCanvasSnappedScale()})
end

local function detectHardwareProblems()
  local OS = love.system.getOS()
  if OS == "Windows" then
    local version, vendor = select(2, love.graphics.getRendererInfo())
    if vendor == "ATI Technologies Inc." and
		(version:find("22.7.1", 1, true) or version:find(".2207", 1, true)) then
      love.window.showMessageBox(
        "AMD driver 22.7.1 detected",
        "AMD driver 22.7.1 is known to have problems with running LÖVE (this includes Panel Attack). If the game fails to render its visuals, it is recommended to upgrade or downgrade your AMD GPU drivers.",
        "warning"
      )
    end
  end
end

function Game:setupRoutine()
  -- loading various assets into the game
  coroutine.yield("Loading localization...")
  Localization:init()
  self.setLanguage(config.language_code)

  detectHardwareProblems()

  fileUtils.copyFile("docs/puzzles.txt", "puzzles/README.txt")
  
  coroutine.yield(loc("ld_theme"))
  theme_init()
  self.theme = themes[config.theme]
  
  -- stages and panels before characters since they are part of their loading!
  coroutine.yield(loc("ld_stages"))
  StageLoader.initStages()
  
  coroutine.yield(loc("ld_panels"))
  panels_init()
  
  coroutine.yield(loc("ld_characters"))
  CharacterLoader.initCharacters()
  
  coroutine.yield(loc("ld_analytics"))
  analytics.init()

  SoundController:applyConfigVolumes()

  self:createDirectoriesIfNeeded()

  self:checkForUpdates()
  -- Run all unit tests now that we have everything loaded
  if TESTS_ENABLED then
    self:runUnitTests()
  end
  if PERFORMANCE_TESTS_ENABLED then
    self:runPerformanceTests()
  end

  self:initializeLocalPlayer()
end

-- GAME.localPlayer is the standard player for battleRooms that don't get started from replays/spectate
-- it basically represents the player that is operating the client (and thus binds to its configuration)
function Game:initializeLocalPlayer()
  self.localPlayer = Player.getLocalPlayer()
  self.localPlayer:connectSignal("selectedCharacterIdChanged", config, function(config, newId) config.character = newId end)
  self.localPlayer:connectSignal("selectedStageIdChanged", config, function(config, newId) config.stage = newId end)
  self.localPlayer:connectSignal("panelIdChanged", config, function(config, newId) config.panels = newId end)
  self.localPlayer:connectSignal("inputMethodChanged", config, function(config, inputMethod) config.inputMethod = inputMethod end)
  --self.localPlayer:connectSignal("startingSpeedChanged", config, function(config, speed) config.endless_speed = speed end)
  self.localPlayer:connectSignal("difficultyChanged", config, function(config, difficulty) config.endless_difficulty = difficulty end)
  self.localPlayer:connectSignal("levelChanged", config, function(config, level) config.level = level end)
  self.localPlayer:connectSignal("wantsRankedChanged", config, function(config, wantsRanked) config.ranked = wantsRanked end)
  self.localPlayer:connectSignal("styleChanged", config, function(config, style)
    if style == GameModes.Styles.CLASSIC then
      config.endless_level = nil
    else
      config.endless_level = config.level
    end
  end)
end

function Game:createDirectoriesIfNeeded()
  coroutine.yield("Creating Folders")

  -- create folders in appdata for those who don't have them already
  love.filesystem.createDirectory("characters")
  love.filesystem.createDirectory("panels")
  love.filesystem.createDirectory("themes")
  love.filesystem.createDirectory("stages")
  love.filesystem.createDirectory("training")

  local oldServerDirectory = consts.SERVER_SAVE_DIRECTORY .. consts.LEGACY_SERVER_LOCATION
  local newServerDirectory = consts.SERVER_SAVE_DIRECTORY .. consts.SERVER_LOCATION
  if not love.filesystem.getInfo(newServerDirectory) then
    love.filesystem.createDirectory(newServerDirectory)

    -- Move the old user ID spot to the new folder (we won't delete the old one for backwards compatibility and safety)
    if love.filesystem.getInfo(oldServerDirectory) then
      local userID = read_user_id_file(consts.LEGACY_SERVER_LOCATION)
      write_user_id_file(userID, consts.SERVER_LOCATION)
    end
  end

  if #fileUtils.getFilteredDirectoryItems("training") == 0 then
    fileUtils.recursiveCopy("client/assets/default_data/training", "training")
  end
  readAttackFiles("training")

  if love.system.getOS() ~= "OS X" then
    fileUtils.recursiveRemoveFiles(".", ".DS_Store")
  end
end

function Game:checkForUpdates()
  -- --check for game updates
  -- if self.updater and self.updater.check_update_ingame then
  --   wait_game_update = self.updater:async_download_latest_version()
  -- end
end

function Game:runUnitTests()
  coroutine.yield("Running Unit Tests")

  -- GAME.localPlayer is the standard player for battleRooms that don't get started from replays/spectate
  -- basically the player that is operating the client
  GAME.localPlayer = Player.getLocalPlayer()
  -- we need to overwrite the local player as all replay related tests need a non-local player
  GAME.localPlayer.isLocal = false

  logger.info("Running Unit Tests...")
  GAME.muteSound = true
  --require("client.tests.Tests")
  SoundController:applyConfigVolumes()
end

function Game:runPerformanceTests()
  coroutine.yield("Running Performance Tests")
  require("tests.StackReplayPerformanceTests")
  -- Disabled since they just prove lua tables are faster for rapid concatenation of strings
  --require("tests.StringPerformanceTests")
end

function Game:updateMouseVisibility(dt)
  if love.mouse.getX() == self.last_x and love.mouse.getY() == self.last_y then
    if not self.pointer_hidden then
      if self.input_delta > consts.MOUSE_POINTER_TIMEOUT then
        self.pointer_hidden = true
        love.mouse.setVisible(false)
      else
        self.input_delta = self.input_delta + dt
      end
    end
  else
    self.last_x = love.mouse.getX()
    self.last_y = love.mouse.getY()
    self.input_delta = 0.0
    if self.pointer_hidden then
      self.pointer_hidden = false
      love.mouse.setVisible(true)
    end
  end
end

function Game:handleResize(newWidth, newHeight)
  if self.previousWindowWidth ~= newWidth or self.previousWindowHeight ~= newHeight then
    self:updateCanvasPositionAndScale(newWidth, newHeight)
    if self.match then
      self.needsAssetReload = true
    else
      self:refreshCanvasAndImagesForNewScale()
    end
    self.showGameScaleUntil = self.timer + 5
  end
end

-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function Game:update(dt)
  self.timer = love.timer.getTime()
  if GAME.navigationStack.transition then
    leftover_time = leftover_time + dt
  else
    leftover_time = 0
  end

  prof.push("battleRoom update")
  if self.battleRoom then
    self.battleRoom:update(dt)
  end
  prof.pop("battleRoom update")
  self.netClient:update(dt)

  handleShortcuts()

  prof.push("navigationStack update")
  self.navigationStack:update(dt)
  prof.pop("navigationStack update")

  if self.backgroundImage then
    self.backgroundImage:update(dt)
  end

  self:updateMouseVisibility(dt)
  SoundController:update()
  self.rich_presence:runCallbacks()
end

function Game:draw()
  -- Setting the canvas means everything we draw is drawn to the canvas instead of the screen
  love.graphics.setCanvas(self.globalCanvas)
  love.graphics.setBackgroundColor(unpack(self.backgroundColor))
  love.graphics.clear()

  -- With this, self.globalCanvas is clear and set as our active canvas everything is being drawn to
  self.navigationStack:draw()

  self:drawFPS()
  self:drawScaleInfo()

  -- resetting the canvas means everything we draw is drawn to the screen
  love.graphics.setCanvas()
  -- clear in preparation for the next render (is this really necessary with the clear further up?)
  love.graphics.clear(love.graphics.getBackgroundColor())

  love.graphics.setBlendMode("alpha", "premultiplied")
  -- now we draw the finished canvas at scale
  -- this way we don't have to worry about scaling singular elements, just draw everything at 1280x720 to the canvas
  love.graphics.draw(self.globalCanvas, self.canvasX, self.canvasY, 0, self.canvasXScale, self.canvasYScale)
  love.graphics.setBlendMode("alpha", "alphamultiply")
end

function Game:drawFPS()
  -- Draw the FPS if enabled
  if self.config.show_fps then
    love.graphics.print("FPS: " .. love.timer.getFPS(), 1, 1)
  end
end

function Game:drawScaleInfo()
  if self.showGameScaleUntil > self.timer then
    local scaleString = "Scale: " .. self.canvasXScale .. " (" .. consts.CANVAS_WIDTH * self.canvasXScale .. " x " .. consts.CANVAS_HEIGHT * self.canvasYScale .. ")"
    local newPixelWidth = love.graphics.getWidth()

    if consts.CANVAS_WIDTH * self.canvasXScale > newPixelWidth then
      scaleString = scaleString .. " Clipped "
    end
    love.graphics.printf(scaleString, GraphicsUtil.getGlobalFontWithSize(30), 5, 5, 2000, "left")
  end
end

function Game.errorData(errorString, traceBack)
  local systemInfo = "OS: " .. (love.system.getOS() or "Unknown")
  local loveVersion = Game.loveVersionString() or "Unknown"
  local username = config.name or "Unknown"
  local buildVersion
  if GAME.updater then
    buildVersion = GAME.updater.activeReleaseStream.name .. " " .. GAME.updater.activeVersion.version
  else
    buildVersion = "Unknown"
  end

  local name, version, vendor, device = love.graphics.getRendererInfo()
  local rendererInfo = name .. ";" .. version .. ";" .. vendor .. ";" .. device

  local errorData = {
      stack = traceBack,
      name = username,
      error = errorString,
      engine_version = consts.ENGINE_VERSION,
      release_version = buildVersion,
      operating_system = systemInfo,
      love_version = loveVersion,
      rendererInfo = rendererInfo,
      theme = config.theme
    }

  if GAME.battleRoom then
    errorData.battleRoomInfo = GAME.battleRoom:getInfo()
  end
  if GAME.navigationStack and GAME.navigationStack.scenes
      and #GAME.navigationStack.scenes > 0
      and GAME.navigationStack.scenes[#GAME.navigationStack.scenes].match then
    errorData.matchInfo = GAME.navigationStack.scenes[#GAME.navigationStack.scenes].match:getInfo()
  end

  return errorData
end

function Game.detailedErrorLogString(errorData)
  local newLine = "\n"
  local now = os.date("*t", to_UTC(os.time()))
  local formattedTime = string.format("%04d-%02d-%02d %02d:%02d:%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)

  local detailedErrorLogString = 
    "Stack Trace: " .. errorData.stack .. newLine ..
    "Username: " .. errorData.name .. newLine ..
    "Theme: " .. errorData.theme .. newLine ..
    "Error Message: " .. errorData.error .. newLine ..
    "Engine Version: " .. errorData.engine_version .. newLine ..
    "Build Version: " .. errorData.release_version .. newLine ..
    "Operating System: " .. errorData.operating_system .. newLine ..
    "Love Version: " .. errorData.love_version .. newLine ..
    "Renderer Info: " .. errorData.rendererInfo .. newLine ..
    "UTC Time: " .. formattedTime .. newLine ..
    "Scene: " .. (GAME.navigationStack.scenes[#GAME.navigationStack.scenes].name or "") .. newLine

    if errorData.matchInfo and not errorData.matchInfo.ended then
      detailedErrorLogString = detailedErrorLogString .. newLine ..
      "Match Info: " .. newLine ..
      "  Stage: " .. errorData.matchInfo.stage .. newLine ..
      "  Stack Interaction: " .. errorData.matchInfo.stackInteraction
      if errorData.matchInfo.timeLimit then
        detailedErrorLogString = detailedErrorLogString .. newLine ..
        "  Time Limit: " .. errorData.matchInfo.timeLimit
      end
      if errorData.matchInfo.doCountdown then
        detailedErrorLogString = detailedErrorLogString .. newLine ..
        "  Do Countdown: " .. tostring(errorData.matchInfo.doCountdown)
      end
      detailedErrorLogString = detailedErrorLogString .. newLine ..
      "  Stacks: "
      for i = 1, #errorData.matchInfo.stacks do
        local stack = errorData.matchInfo.stacks[i]
        detailedErrorLogString = detailedErrorLogString .. newLine ..
        "    P" .. i .. ": " .. newLine ..
        "      Player Number: " .. stack.playerNumber .. newLine ..
        "      Character: " .. stack.character .. newLine ..
        "      InputMethod: " .. stack.inputMethod .. newLine ..
        "      Rollback Count: " .. stack.rollbackCount .. newLine ..
        "      Rollback Frames Saved: " .. stack.rollbackCopyCount
      end
    elseif errorData.battleRoomInfo then
      detailedErrorLogString = detailedErrorLogString .. newLine ..
      "BattleRoom Info: " .. newLine ..
      "  Online: " .. errorData.battleRoomInfo.online .. newLine ..
      "  Spectating: " .. errorData.battleRoomInfo.spectating .. newLine ..
      "  All assets loaded: " .. errorData.battleRoomInfo.allAssetsLoaded .. newLine ..
      "  State: " .. errorData.battleRoomInfo.state .. newLine ..
      "  Players: "
      for i = 1, #errorData.battleRoomInfo.players do
        local player = errorData.battleRoomInfo.players[i]
        detailedErrorLogString = detailedErrorLogString .. newLine ..
        "    P" .. i .. ": " .. newLine ..
        "      Player Number: " .. player.playerNumber .. newLine ..
        "      Panels: " .. player.panelId  .. newLine ..
        "      Selected Character: " .. player.selectedCharacterId .. newLine ..
        "      Character: " .. player.characterId  .. newLine ..
        "      Selected Stage: " .. player.selectedStageId .. newLine ..
        "      Stage: " .. player.stageId .. newLine ..
        "      isLocal: " .. player.isLocal .. newLine ..
        "      wantsReady: " .. player.wantsReady
      end
    end

  return detailedErrorLogString
end

local loveVersionStringValue = nil

function Game.loveVersionString()
  if loveVersionStringValue then
    return loveVersionStringValue
  end
  local major, minor, revision, codename = love.getVersion()
  loveVersionStringValue = string.format("%d.%d.%d", major, minor, revision)
  return loveVersionStringValue
end

-- Calculates the proper dimensions to not stretch the game for various sizes
function scale_letterbox(width, height, w_ratio, h_ratio)
  if height / h_ratio > width / w_ratio then
    local scaled_height = h_ratio * width / w_ratio
    return 0, (height - scaled_height) / 2, width, scaled_height
  end
  local scaled_width = w_ratio * height / h_ratio
  return (width - scaled_width) / 2, 0, scaled_width, height
end

-- Updates the scale and position values to use up the right size of the window based on the user's settings.
function Game:updateCanvasPositionAndScale(newWindowWidth, newWindowHeight)
  local scaleIsUpdated = false
  if config.gameScaleType ~= "fit" then
    local availableScales = shallowcpy(self.automaticScales)
    if config.gameScaleType == "fixed" then
      availableScales = {config.gameScaleFixedValue}
    end

    -- Handle both "auto" and a fixed scale
    -- Go from biggest to smallest and used the highest one that still fits
    for i = #availableScales, 1, -1 do
      local scale = availableScales[i]
      if config.gameScaleType ~= "auto" or 
        (newWindowWidth >= self.globalCanvas:getWidth() * scale and newWindowHeight >= self.globalCanvas:getHeight() * scale) then
        self.canvasXScale = scale
        self.canvasYScale = scale
        self.canvasX = math.floor((newWindowWidth - (scale * self.globalCanvas:getWidth())) / 2)
        self.canvasY = math.floor((newWindowHeight - (scale * self.globalCanvas:getHeight())) / 2)
        scaleIsUpdated = true
        break
      end
    end
  end

  if scaleIsUpdated == false then
    -- The only thing left to do is scale to fit the window
    local w, h
    local canvasWidth, canvasHeight = self.globalCanvas:getDimensions()
    self.canvasX, self.canvasY, w, h = scale_letterbox(newWindowWidth, newWindowHeight, canvasWidth, canvasHeight)
    self.canvasXScale = w / canvasWidth
    self.canvasYScale = h / canvasHeight
  end

  self.previousWindowWidth = newWindowWidth
  self.previousWindowHeight = newWindowHeight
end

-- Reloads the canvas and all images / fonts for the new game scale
function Game:refreshCanvasAndImagesForNewScale()
  if themes == nil or themes[config.theme] == nil then
    return -- EARLY RETURN, assets haven't loaded the first time yet
    -- they will load through the normal process
  end

  self:drawLoadingString(loc("ld_characters"))
  coroutine.yield()

  self.globalCanvas = love.graphics.newCanvas(GAME.globalCanvas:getWidth(), GAME.globalCanvas:getHeight(), {dpiscale=self:newCanvasSnappedScale()})
  -- We need to reload all assets and fonts to get the new scaling info and filters

  -- Reload theme to get the new resolution assets
  themes[config.theme]:graphics_init(true)
  themes[config.theme]:final_init()
  -- Reload stages to get the new resolution assets
  stages_reload_graphics()
  -- Reload panels to get the new resolution assets
  panels_init()
  -- Reload characters to get the new resolution assets
  characters_reload_graphics()
  
  -- Reload loc to get the new font
  self.setLanguage(config.language_code)
end

-- Transform from window coordinates to game coordinates
function Game:transform_coordinates(x, y)
  return (x - self.canvasX) / self.canvasXScale, (y - self.canvasY) / self.canvasYScale
end


function Game:drawLoadingString(loadingString) 
  local textMaxWidth = 300
  local textHeight = 40
  local x = 0
  local y = consts.CANVAS_HEIGHT/2 - textHeight/2
  local backgroundPadding = 10
  GraphicsUtil.drawRectangle("fill", consts.CANVAS_WIDTH / 2 - (textMaxWidth / 2) , y - backgroundPadding, textMaxWidth, textHeight, 0, 0, 0, 0.5)
  GraphicsUtil.printf(loadingString, x, y, consts.CANVAS_WIDTH, "center", nil, nil, 10)
end

function Game.setLanguage(lang_code)
  for i, v in ipairs(Localization.codes) do
    if v == lang_code then
      Localization.lang_index = i
      break
    end
  end
  config.language_code = Localization.codes[Localization.lang_index]

  if themes[config.theme] and themes[config.theme].font and themes[config.theme].font.path then
    GraphicsUtil.setGlobalFont(themes[config.theme].font.path, themes[config.theme].font.size)
  elseif config.language_code == "JP" then
    GraphicsUtil.setGlobalFont("client/assets/fonts/jp.ttf", 14)
  elseif config.language_code == "TH" then
    GraphicsUtil.setGlobalFont("client/assets/fonts/th.otf", 14)
  else
    GraphicsUtil.setGlobalFont(nil, 12)
  end

  Localization:refresh_global_strings()
end

return Game

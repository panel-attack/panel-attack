require("TimeQueue")
require("queue")
require("server_queue")
local Signal = require("helpers.signal")

-- The main game object for tracking everything in Panel Attack.
-- Not to be confused with "Match" which is the current battle / instance of the game.
local consts = require("consts")
local GraphicsUtil = require("graphics_util")
local class = require("class")
local logger = require("logger")
local sound = require("sound")
local analytics = require("analytics")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local save = require("save")
local fileUtils = require("FileUtils")
local handleShortcuts = require("Shortcuts")
local Player = require("Player")
local GameModes = require("GameModes")
local TcpClient = require("network.TcpClient")
local StartUp = require("scenes.StartUp")

local GFX_SCALE = consts.GFX_SCALE


require("rich_presence.RichPresence")

-- Provides a scale that is on .5 boundary to make sure it renders well.
-- Useful for creating new canvas with a solid DPI
local function newCanvasSnappedScale(self)
  local result = math.max(1, math.floor(self.canvasXScale*2)/2)
  return result
end

--- @module Game
local Game = class(
  function(self)
    self.scores = require("scores")
    self.input = input
    self.match = nil -- Match - the current match going on or nil if inbetween games
    self.battleRoom = nil -- BattleRoom - the current room being used for battles
    self.focused = true -- if the window is focused
    self.backgroundImage = nil -- the background image for the game, should always be set to something with the proper dimensions
    self.droppedFrames = 0
    self.puzzleSets = {} -- all the puzzles loaded into the game
    self.gfx_q = Queue()
    self.tcpClient = TcpClient()
    self.server_queue = ServerQueue()
    self.main_menu_screen_pos = {consts.CANVAS_WIDTH / 2 - 108 + 50, consts.CANVAS_HEIGHT / 2 - 111}
    self.config = config
    self.localization = Localization()
    self.replay = {}
    self.currently_paused_tracks = {} -- list of tracks currently paused
    self.rich_presence = nil
    self.muteSoundEffects = false
    self.canvasX = 0
    self.canvasY = 0
    self.canvasXScale = 1
    self.canvasYScale = 1
    self.backgroundColor = { 0.0, 0.0, 0.0 }

    -- depends on canvasXScale
    self.global_canvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=newCanvasSnappedScale(self)})

    self.availableScales = {1, 1.5, 2, 2.5, 3}
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

    -- coroutines
    self.setupCoroutineObject = coroutine.create(function() self:setupCoroutine() end)

    -- misc
    self.rich_presence = RichPresence()
    -- time in seconds, can be used by other elements to track the passing of time beyond dt
    self.timer = love.timer.getTime()
  end
)

Game.newCanvasSnappedScale = newCanvasSnappedScale

function Game:load(game_updater)
  -- move to constructor
  self.game_updater = game_updater
  local user_input_conf = save.read_key_file()
  if user_input_conf then
    self.input:importConfigurations(user_input_conf)
  end
  --self:createScenes()
  sceneManager.activeScene = StartUp({setupRoutine = self.setupRoutine})
end

function Game:setupRoutine()
  -- loading various assets into the game
  coroutine.yield("Loading localization...")
  Localization.init(localization)
  fileUtils.copyFile("readme_puzzles.txt", "puzzles/README.txt")
  
  coroutine.yield(loc("ld_theme"))
  theme_init()
  
  -- stages and panels before characters since they are part of their loading!
  coroutine.yield(loc("ld_stages"))
  stages_init()
  
  coroutine.yield(loc("ld_panels"))
  panels_init()
  
  coroutine.yield(loc("ld_characters"))
  CharacterLoader.initCharacters()
  
  coroutine.yield(loc("ld_analytics"))
  analytics.init()

  apply_config_volume()

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
  Signal.connectSignal(self.localPlayer, "selectedCharacterIdChanged", config, function(config, newId) config.character = newId end)
  Signal.connectSignal(self.localPlayer, "selectedStageIdChanged", config, function(config, newId) config.stage = newId end)
  Signal.connectSignal(self.localPlayer, "panelIdChanged", config, function(config, newId) config.panels = newId end)
  Signal.connectSignal(self.localPlayer, "inputMethodChanged", config, function(config, inputMethod) config.inputMethod = inputMethod end)
  Signal.connectSignal(self.localPlayer, "startingSpeedChanged", config, function(config, speed) config.endless_speed = speed end)
  Signal.connectSignal(self.localPlayer, "difficultyChanged", config, function(config, difficulty) config.endless_difficulty = difficulty end)
  Signal.connectSignal(self.localPlayer, "levelChanged", config, function(config, level) config.level = level end)
  Signal.connectSignal(self.localPlayer, "wantsRankedChanged", config, function(config, wantsRanked) config.ranked = wantsRanked end)
  Signal.connectSignal(self.localPlayer, "styleChanged", config, function(config, style)
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
    fileUtils.recursiveCopy("default_data/training", "training")
  end
  readAttackFiles("training")

  if love.system.getOS() ~= "OS X" then
    fileUtils.recursiveRemoveFiles(".", ".DS_Store")
  end
end

function Game:checkForUpdates()
  --check for game updates
  if self.game_updater and self.game_updater.check_update_ingame then
    wait_game_update = self.game_updater:async_download_latest_version()
  end
end

function Game:runUnitTests()
  coroutine.yield("Running Unit Tests")

  -- GAME.localPlayer is the standard player for battleRooms that don't get started from replays/spectate
  -- basically the player that is operating the client
  GAME.localPlayer = Player.getLocalPlayer()
  -- we need to overwrite the local player as all replay related tests need a non-local player
  GAME.localPlayer.isLocal = false

  logger.info("Running Unit Tests...")
  require("tests.Tests")
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
  if sceneManager.activeScene == nil then
    leftover_time = leftover_time + dt
  else
    leftover_time = 0
  end

  if self.battleRoom then
    self.battleRoom:update(dt)
  end

  sceneManager:update(dt)

  if self.backgroundImage then
    self.backgroundImage:update(dt)
  end

  self:updateMouseVisibility(dt)
  update_music()
  self.rich_presence:runCallbacks()
  handleShortcuts()
end

function Game:switchToStartScene()
  if themes[config.theme].images.bg_title then
    sceneManager:switchToScene(sceneManager:createScene("TitleScreen"))
  else
    sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
  end
end

function Game:draw()
  -- Setting the canvas means everything we draw is drawn to the canvas instead of the screen
  love.graphics.setCanvas(self.globalCanvas)
  love.graphics.setBackgroundColor(unpack(self.backgroundColor))
  love.graphics.clear()

  -- With this, self.globalCanvas is clear and set as our active canvas everything is being drawn to
  self.isDrawing = true
  sceneManager:draw()
  self.isDrawing = false
  self:processGraphicsQueue()

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
  if self.showGameScaleUntil > self.timer or config.debug_mode then
    local scaleString = "Scale: " .. self.canvasXScale .. " (" .. consts.CANVAS_WIDTH * self.canvasXScale .. " x " .. consts.CANVAS_HEIGHT * self.canvasYScale .. ")"
    local newPixelWidth = love.graphics.getWidth()

    if consts.CANVAS_WIDTH * self.canvasXScale > newPixelWidth then
      scaleString = scaleString .. " Clipped "
    end
    love.graphics.printf(scaleString, GraphicsUtil.getGlobalFontWithSize(30), 5, 5, 2000, "left")
  end
end

function Game:processGraphicsQueue()
  -- the isDrawing flag is important so the graphics util funcs know to call the love.graphics funcs directly instead of pushing to gfx_q
  self.isDrawing = true
  -- ideally the only things remaining in the gfx_q are text prints and Match:render
  for i = self.gfx_q.first, self.gfx_q.last do
    local func = self.gfx_q[i][1]
    local args = self.gfx_q[i][2]
    func(unpack(args))
  end
  self.gfx_q:clear()
  self.isDrawing = false
end

function Game:reset()
  self.currently_paused_tracks = {}
  self.muteSoundEffects = false
end

function Game.errorData(errorString, traceBack)
  local system_info = "OS: " .. love.system.getOS()
  local loveVersion = Game.loveVersionString() or "Unknown"
  local username = config.name or "Unknown"
  local buildVersion = GAME_UPDATER_GAME_VERSION or "Unknown"
  local systemInfo = system_info or "Unknown"

  local errorData = {
      stack = traceBack,
      name = username,
      error = errorString,
      engine_version = consts.ENGINE_VERSION,
      release_version = buildVersion,
      operating_system = systemInfo,
      love_version = loveVersion,
      theme = config.theme
    }

  if GAME.battleRoom and GAME.battleRoom.match then
    errorData.matchInfo = GAME.battleRoom.match:getInfo()
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
    "UTC Time: " .. formattedTime ..
    "Scene: " .. sceneManager.activeScene.name

    if errorData.matchInfo then
      detailedErrorLogString = detailedErrorLogString .. newLine ..
      "Match Info: " .. newLine ..
      "  Stage: " .. errorData.matchInfo.stage .. newLine ..
      "  Stack Interaction: " .. errorData.matchInfo.stackInteraction ..
      "  Time Limit: " .. errorData.matchInfo.timeLimit ..
      "  Do Countdown: " .. errorData.matchInfo.doCountdown ..
      "  Stacks: "
      for i = 1, #errorData.matchInfo.stacks do
        local stack = errorData.matchInfo.stacks[i]
        detailedErrorLogString = detailedErrorLogString .. newLine ..
        "    P" .. i .. ": " .. newLine ..
        "      Player Number: " .. stack.playerNumber .. newLine ..
        "      Character: " .. stack.character  .. newLine ..
        "      Panels: " .. stack.panels  .. newLine ..
        "      Rollback Count: " .. stack.rollbackCount .. newLine ..
        "      Rollback Frames Saved: " .. stack.rollbackCopyCount
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
    local availableScales = shallowcpy(self.availableScales)
    if config.gameScaleType == "fixed" then
      availableScales = {config.gameScaleFixedValue}
    end

    -- Handle both "auto" and a fixed scale
    -- Go from biggest to smallest and used the highest one that still fits
    for i = #availableScales, 1, -1 do
      local scale = availableScales[i]
      if config.gameScaleType ~= "auto" or 
        (newWindowWidth >= consts.CANVAS_WIDTH * scale and newWindowHeight >= consts.CANVAS_HEIGHT * scale) then
        self.canvasXScale = scale
        self.canvasYScale = scale
        self.canvasX = math.floor((newWindowWidth - (scale * consts.CANVAS_WIDTH)) / 2)
        self.canvasY = math.floor((newWindowHeight - (scale * consts.CANVAS_HEIGHT)) / 2)
        scaleIsUpdated = true
        break
      end
    end
  end

  if scaleIsUpdated == false then
    -- The only thing left to do is scale to fit the window
    local w, h
    self.canvasX, self.canvasY, w, h = scale_letterbox(newWindowWidth, newWindowHeight, 16, 9)
    self.canvasXScale = w / consts.CANVAS_WIDTH
    self.canvasYScale = h / consts.CANVAS_HEIGHT
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

  self.globalCanvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT, {dpiscale=self:newCanvasSnappedScale()})
  -- We need to reload all assets and fonts to get the new scaling info and filters

  -- Reload theme to get the new resolution assets
  themes[config.theme]:graphics_init()
  themes[config.theme]:final_init()
  -- Reload stages to get the new resolution assets
  stages_reload_graphics()
  -- Reload panels to get the new resolution assets
  panels_init()
  -- Reload characters to get the new resolution assets
  characters_reload_graphics()
  
  -- Reload loc to get the new font
  localization:set_language(config.language_code)
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
  grectangle_color("fill", (consts.CANVAS_WIDTH / 2 - (textMaxWidth/2)) / GFX_SCALE , (y - backgroundPadding) / GFX_SCALE, textMaxWidth/GFX_SCALE, textHeight/GFX_SCALE, 0, 0, 0, 0.5)
  gprintf(loadingString, x, y, consts.CANVAS_WIDTH, "center", nil, nil, 10)
end

return Game
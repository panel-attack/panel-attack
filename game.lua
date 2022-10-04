-- The main game object for tracking everything in Panel Attack.
-- Not to be confused with "Match" which is the current battle / instance of the game.
local consts = require("consts")
local class = require("class")
local logger = require("logger")
local sound = require("sound")
local analytics = require("analytics")
local sceneManager = require("scenes.sceneManager")
local scenes = nil

--- @module Game
local Game = class(
  function(self)
    self.scores = require("scores")
    self.input = require("input")
    self.match = nil -- Match - the current match going on or nil if inbetween games
    self.battleRoom = nil -- BattleRoom - the current room being used for battles
    self.focused = true -- if the window is focused
    self.backgroundImage = nil -- the background image for the game, should always be set to something with the proper dimensions
    self.foreground_overlay = nil
    self.droppedFrames = 0
    self.puzzleSets = {} -- all the puzzles loaded into the game
    self.gameIsPaused = false -- game can be paused while playing on local
    self.renderDuringPause = false -- if the game can render when you are paused
    self.global_canvas = love.graphics.newCanvas(consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
    self.gfx_q = Queue()
    self.game_updater = GAME_UPDATER
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
    self.availableScales = {1, 1.5, 2, 2.5, 3}
    self.showGameScale = false
    self.needsAssetReload = false
    self.previousWindowWidth = 0
    self.previousWindowHeight = 0
    
    -- private members
    self.pointer_hidden = false
    self.last_x = 0
    self.last_y = 0
    self.input_delta = 0.0
    self.mainloop = nil
    -- coroutines
    self.setup = coroutine.create(function() self:setupCo() end)
  end
)

function Game:setupCo()
  -- loading various assets into the game
  love.window.setPosition(config.windowX, config.windowY, config.display)
  love.window.setFullscreen(config.fullscreen)
  love.window.setVSync(config.vsync and 1 or 0)
  
  self:drawLoadingString("Loading localization...")
  coroutine.yield()
  Localization.init(localization)
  
  self:drawLoadingString(loc("ld_theme"))
  coroutine.yield()
  theme_init()
  
  -- stages and panels before characters since they are part of their loading!
  self:drawLoadingString(loc("ld_stages"))
  coroutine.yield()
  stages_init()
  
  self:drawLoadingString(loc("ld_panels"))
  coroutine.yield()
  panels_init()
  
  self:drawLoadingString(loc("ld_characters"))
  coroutine.yield()
  characters_init()
  
  self:drawLoadingString(loc("ld_analytics"))
  coroutine.yield()
  analytics.init()
  apply_config_volume()
  -- create folders in appdata for those who don't have them already
  love.filesystem.createDirectory("characters")
  love.filesystem.createDirectory("panels")
  love.filesystem.createDirectory("themes")
  love.filesystem.createDirectory("stages")
  love.filesystem.createDirectory("training")
  
  if #love.filesystem.getDirectoryItems("training") == 0 then
    recursive_copy("default_data/training", "training")
  end
  read_attack_files("training")
  
  if love.system.getOS() ~= "OS X" then
    recursiveRemoveFiles(".", ".DS_Store")
  end

  --check for game updates
  if self.game_updater and self.game_updater.check_update_ingame then
    wait_game_update = self.game_updater:async_download_latest_version()
  end
  
  -- must be here until globally initiallized structures get resolved into local requires
  scenes = {
  }
  for i, scene in ipairs(scenes) do
    scene:init()
  end
  sceneManager:switchScene(nil)
end

function Game:load(game_updater)
  -- move to constructor
  self.game_updater = game_updater
  local user_input_conf = read_key_file()
  if user_input_conf then
    self.input.inputConfigurations = user_input_conf
  end
end



-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function Game:update(dt)
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

  leftover_time = leftover_time + dt
  
  if self.backgroundImage then
    self.backgroundImage:update(dt)
  end
  
  local newPixelWidth, newPixelHeight = love.graphics.getWidth(), love.graphics.getHeight()
if GAME.previousWindowWidth ~= newPixelWidth or GAME.previousWindowHeight ~= newPixelHeight then
    GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
    if GAME.match then
      GAME.needsAssetReload = true
    else
      GAME:refreshCanvasAndImagesForNewScale()
    end
    GAME.showGameScale = true
  end
  
  local status, err = nil
  if coroutine.status(self.setup) ~= "dead" then
    status, err = coroutine.resume(self.setup)
  elseif sceneManager.active_scene then
    sceneManager.active_scene:update(dt)
    -- update transition to use draw priority queue
    if sceneManager.is_transitioning then
      sceneManager:transition()
    end
    status = true
  elseif sceneManager.is_transitioning then
    sceneManager:transition()
    status = true
  else
    status, err = coroutine.resume(mainloop)
  end
  if not status then
    local errorData = self:errorData(err, debug.traceback(mainloop))
    if GAME_UPDATER_GAME_VERSION then
      send_error_report(errorData)
    end
    error(err .. "\n\n" .. dump(errorData))
  end
  if self.server_queue and self.server_queue:size() > 0 then
    logger.trace("Queue Size: " .. self.server_queue:size() .. " Data:" .. self.server_queue:to_short_string())
  end
  this_frame_messages = {}

  update_music()
end

function Game:draw()
  -- if not main_font then
  -- main_font = love.graphics.newFont("Oswald-Light.ttf", 15)
  -- end
  -- main_font:setLineHeight(0.66)
  -- love.graphics.setFont(main_font)
  if self.foreground_overlay then
    local scale = consts.CANVAS_WIDTH / math.max(self.foreground_overlay:getWidth(), self.foreground_overlay:getHeight()) -- keep image ratio
    menu_drawf(self.foreground_overlay, consts.CANVAS_WIDTH / 2, consts.CANVAS_HEIGHT / 2, "center", "center", 0, scale, scale)
  end

  -- Clear the screen
  love.graphics.setBlendMode("alpha", "alphamultiply")
  love.graphics.setCanvas(self.globalCanvas)
  love.graphics.setBackgroundColor(unpack(global_background_color))
  love.graphics.clear()

  if STONER_MODE then
    gprintf("STONER", 1, 1 + (11 * 4))
  end

  for i = self.gfx_q.first, self.gfx_q.last do
    self.gfx_q[i][1](unpack(self.gfx_q[i][2]))
  end
  self.gfx_q:clear()
  
  -- Draw the FPS if enabled
  if self.config.show_fps then
    love.graphics.print("FPS: " .. love.timer.getFPS(), 1, 1)
  end
  
  if self.showGameScale or config.debug_mode then
    local scaleString = "Scale: " .. self.canvasXScale .. " (" .. canvas_width * self.canvasXScale .. " x " .. canvas_height * self.canvasYScale .. ")"
    local newPixelWidth = love.graphics.getWidth()

    if canvas_width * self.canvasXScale > newPixelWidth then
      scaleString = scaleString .. " Clipped "
    end
    love.graphics.printf(scaleString, get_global_font_with_size(30), 5, 5, 2000, "left")
  end

  love.graphics.setCanvas() -- render everything thats been added
  love.graphics.clear(love.graphics.getBackgroundColor()) -- clear in preperation for the next render
  
  x, y, w, h = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(self.globalCanvas, self.canvasX, self.canvasY, 0, self.canvasXScale, self.canvasYScale)

  -- draw background and its overlay
  if self.backgroundImage then
    self.backgroundImage:draw()
  end
  
  if self.background_overlay then
    local scale = consts.CANVAS_WIDTH / math.max(self.background_overlay:getWidth(), self.background_overlay:getHeight()) -- keep image ratio
    menu_drawf(self.background_overlay, consts.CANVAS_WIDTH / 2, consts.CANVAS_HEIGHT / 2, "center", "center", 0, scale, scale)
  end
end

function Game:clearMatch()
  self.match = nil
  self.gameIsPaused = false
  self.renderDuringPause = false
  self.preventSounds = false
  self.currently_paused_tracks = {}
  self.muteSoundEffects = false
  P1 = nil
  P2 = nil
end

function Game.errorData(errorString, traceBack)
  local system_info = "OS: " .. love.system.getOS()
  local loveVersion = Game.loveVersionString()
  
  local errorData = { 
      stack = traceBack,
      name = config.name or "Unknown",
      error = errorString,
      engine_version = VERSION,
      release_version = GAME_UPDATER_GAME_VERSION or "Unknown",
      operating_system = system_info or "Unknown",
      love_version = loveVersion or "Unknown"
    }

  return errorData
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
        (newWindowWidth >= canvas_width * scale and newWindowHeight >= canvas_height * scale) then
        GAME.canvasXScale = scale
        GAME.canvasYScale = scale
        GAME.canvasX = math.floor((newWindowWidth - (scale * canvas_width)) / 2)
        GAME.canvasY = math.floor((newWindowHeight - (scale * canvas_height)) / 2)
        scaleIsUpdated = true
        break
      end
    end
  end

  if scaleIsUpdated == false then
    -- The only thing left to do is scale to fit the window
    local w, h
    GAME.canvasX, GAME.canvasY, w, h = scale_letterbox(newWindowWidth, newWindowHeight, 16, 9)
    GAME.canvasXScale = w / canvas_width
    GAME.canvasYScale = h / canvas_height
  end

  GAME.previousWindowWidth = newWindowWidth
  GAME.previousWindowHeight = newWindowHeight
end

-- Provides a scale that is on .5 boundary to make sure it renders well.
-- Useful for creating new canvas with a solid DPI
function Game:newCanvasSnappedScale()
  local result = math.max(1, math.floor(self.canvasXScale*2)/2)
  return result
end

-- Reloads the canvas and all images / fonts for the new game scale
function Game:refreshCanvasAndImagesForNewScale()
  if themes == nil or themes[config.theme] == nil then
    return -- EARLY RETURN, assets haven't loaded the first time yet
    -- they will load through the normal process
  end

  GAME:drawLoadingString(loc("ld_characters"))
  coroutine.yield()

  self.globalCanvas = love.graphics.newCanvas(canvas_width, canvas_height, {dpiscale=GAME:newCanvasSnappedScale()})
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
  for _, menu in pairs(CLICK_MENUS) do
    menu:reloadGraphics()
  end
end

-- Transform from window coordinates to game coordinates
function Game:transform_coordinates(x, y)
  return (x - self.canvasX) / self.canvasXScale, (y - self.canvasY) / self.canvasYScale
end


function Game:drawLoadingString(loadingString) 
  local textMaxWidth = 300
  local textHeight = 40
  local x = 0
  local y = canvas_height/2 - textHeight/2
  local backgroundPadding = 10
  grectangle_color("fill", (canvas_width / 2 - (textMaxWidth/2)) / GFX_SCALE , (y - backgroundPadding) / GFX_SCALE, textMaxWidth/GFX_SCALE, textHeight/GFX_SCALE, 0, 0, 0, 0.5)
  gprintf(loadingString, x, y, canvas_width, "center", nil, nil, 10)
end

return Game

-- The main game object for tracking everything in Panel Attack.
-- Not to be confused with "Match" which is the current battle / instance of the game.
Game =
  class(
  function(self)
    self.scores = require("scores")
    self.match = nil -- Match - the current match going on or nil if inbetween games
    self.battleRoom = nil -- BattleRoom - the current room being used for battles
    self.focused = true -- if the window is focused
    self.backgroundImage = nil -- the background image for the game, should always be set to something with the proper dimensions
    self.droppedFrames = 0
    self.puzzleSets = {} -- all the puzzles loaded into the game
    self.gameIsPaused = false -- game can be paused while playing on local
    self.renderDuringPause = false -- if the game can render when you are paused
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
  end
)

function Game.clearMatch(self)
  if self.match then
    self.match:deinit()
    self.match = nil
  end
  self:reset()
end

function Game:reset()
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
  local loveVersion = Game.loveVersionString() or "Unknown"
  local username = config.name or "Unknown"
  local buildVersion = GAME_UPDATER_GAME_VERSION or "Unknown"
  local systemInfo = system_info or "Unknown"

  local errorData = {
      stack = traceBack,
      name = username,
      error = errorString,
      engine_version = VERSION,
      release_version = buildVersion,
      operating_system = systemInfo,
      love_version = loveVersion,
      theme = config.theme
    }

  if GAME.match then
    errorData.matchInfo = GAME.match:getInfo()
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
    "UTC Time: " .. formattedTime

    if errorData.matchInfo then
      detailedErrorLogString = detailedErrorLogString .. newLine ..
      errorData.matchInfo.mode .. " Match Info: " .. newLine ..
      "  Stage: " .. errorData.matchInfo.stage .. newLine ..
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

local game = Game()

return game

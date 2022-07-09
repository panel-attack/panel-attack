
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
    self.canvasX = 0
    self.canvasY = 0
    self.canvasXScale = 1
    self.canvasYScale = 1
    self.availableScales = {1, 1.5, 2, 2.5, 3}
    self.showGameScale = false
  end
)

function Game.clearMatch(self)
  self.match = nil
  self.gameIsPaused = false
  self.renderDuringPause = false
  self.currently_paused_tracks = {}
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

function Game:updateCanvasPositionAndScale(newWindowWidth, newWindowHeight)
  local foundFixedScale = false

  local availableScales = shallowcpy(self.availableScales)
  if config.gameScale == "scaled" then
    -- Do nothing, fall through to below
  else
    if config.gameScale ~= "auto" then
      local xScale = tonumber(config.gameScale)
      availableScales = {xScale}
    end

    -- Handle both "auto" and a fixed scale
    for i = #availableScales, 1, -1 do
      local scale = availableScales[i]
      if config.gameScale ~= "auto" or 
        (newWindowWidth >= canvas_width * scale and newWindowHeight >= canvas_height * scale) then
        GAME.canvasXScale = scale
        GAME.canvasYScale = scale
        GAME.canvasX = math.floor((newWindowWidth - (scale * canvas_width)) / 2)
        GAME.canvasY = math.floor((newWindowHeight - (scale * canvas_height)) / 2)
        foundFixedScale = true
        break
      end
    end
  end

  if foundFixedScale == false then
    -- Nothing fits, scale down
    local w, h
    GAME.canvasX, GAME.canvasY, w, h = scale_letterbox(newWindowWidth, newWindowHeight, 16, 9)
    GAME.canvasXScale = w / canvas_width
    GAME.canvasYScale = h / canvas_height
  end
end

function Game:refreshAssets()
  -- we need to reload all assets and fonts to get the new scaling info and filters
  Localization.init(localization)
  theme_init()
  panels_init()
end

local game = Game()

return game

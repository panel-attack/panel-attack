-- The main game object for tracking everything in Panel Attack.
-- Not to be confused with "Match" which is the current battle / instance of the game.

local save = require("save")
local consts = require("consts")
local graphics_util = require("graphics_util")
local Queue = require("Queue")
local class = require("class")
local ServerQueue = require("ServerQueue")
local logger = require("logger")
local sound = require("sound")
local Localization = require("Localization")
local analytics = require("analytics")
local scene_manager = require("scenes.scene_manager")
local scenes = nil

--- @module Game
local Game = class(
  function(self, game_updater)
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
    self.game_updater = game_updater
    self.server_queue = ServerQueue()
    self.main_menu_screen_pos = {consts.CANVAS_WIDTH / 2 - 108, consts.CANVAS_HEIGHT / 2 - 111}
    self.config = require("config") -- remove when done
    self.localization = Localization()
    self.replay = {}
    self.currently_paused_tracks = {} -- list of tracks currently paused
    self.rich_presence = nil
    -- private members
    self._pointer_hidden = false
    self._last_x = 0
    self._last_y = 0
    self._input_delta = 0.0
    self._mainloop = nil
    -- coroutines
    self._setup = coroutine.create(function() self:_setup_co() end)
  end
)

function Game:_setup_co()
  -- loading various assets into the game
  graphics_util.gprint("Reading config file", unpack(self.main_menu_screen_pos))
  coroutine.yield()
  self.config = save.read_conf_file()
  config = self.config
  love.window.setPosition(self.config.window_x, self.config.window_y, self.config.display)
  love.window.setFullscreen(self.config.fullscreen)
  love.window.setVSync(self.config.vsync and 1 or 0)
  
  graphics_util.gprint("Loading localization...", unpack(self.main_menu_screen_pos))
  coroutine.yield()
  self.localization:init2()
  
  graphics_util.gprint(loc("ld_puzzles"), unpack(self.main_menu_screen_pos))
  coroutine.yield()
  save.copy_file("readme_puzzles.txt", "puzzles/README.txt")
  
  graphics_util.gprint(loc("ld_replay"), unpack(self.main_menu_screen_pos))
  coroutine.yield()
  self.replay = save.read_replay_file()
  
  graphics_util.gprint(loc("ld_theme"), unpack(self.main_menu_screen_pos))
  coroutine.yield()
  theme_init()
  
  -- stages and panels before characters since they are part of their loading!
  graphics_util.gprint(loc("ld_stages"), unpack(self.main_menu_screen_pos))
  coroutine.yield()
  stages_init()
  
  graphics_util.gprint(loc("ld_panels"), unpack(self.main_menu_screen_pos))
  coroutine.yield()
  panels_init()
  
  graphics_util.gprint(loc("ld_characters"), unpack(self.main_menu_screen_pos))
  coroutine.yield()
  characters_init()
  
  graphics_util.gprint(loc("ld_analytics"), unpack(self.main_menu_screen_pos))
  coroutine.yield()
  analytics.init()
  apply_config_volume()
  -- create folders in appdata for those who don't have them already
  love.filesystem.createDirectory("characters")
  love.filesystem.createDirectory("panels")
  love.filesystem.createDirectory("themes")
  love.filesystem.createDirectory("stages")

  --check for game updates
  if self.game_updater and self.game_updater.check_update_ingame then
    wait_game_update = self.game_updater:async_download_latest_version()
  end
  
  -- move to top
  scenes = {
    require("scenes.main_menu"),
    require("scenes.endless_menu"),
    require("scenes.time_attack_menu"),
    require("scenes.vs_self_menu")
  }
  for i, scene in ipairs(scenes) do
    scene:init()
  end
  scene_manager:switchScene("main_menu")
end

function Game:load(game_updater)
  -- move to constructor
  self.game_updater = game_updater
  local user_input_conf = save.read_key_file()
  if user_input_conf then
    self.input.inputConfigurations = user_input_conf
  end
end



-- Called every few fractions of a second to update the game
-- dt is the amount of time in seconds that has passed.
function Game:update(dt)
  if love.mouse.getX() == self._last_x and love.mouse.getY() == self._last_y then
    if not self._pointer_hidden then
      if self._input_delta > consts.MOUSE_POINTER_TIMEOUT then
        self._pointer_hidden = true
        love.mouse.setVisible(false)
      else
        self._input_delta = self._input_delta + dt
      end
    end
  else
    self._last_x = love.mouse.getX()
    self._last_y = love.mouse.getY()
    self._input_delta = 0.0
    if self._pointer_hidden then
      self._pointer_hidden = false
      love.mouse.setVisible(true)
    end
  end

  leftover_time = leftover_time + dt
  
  local status, err = nil
  if coroutine.status(self._setup) ~= "dead" then
    status, err = coroutine.resume(self._setup)
  elseif scene_manager.active_scene then
    scene_manager.active_scene:update()
    -- update transition to use draw priority queue
    if scene_manager.is_transitioning then
      scene_manager:transition()
    end
    status = true
  elseif scene_manager.is_transitioning then
    scene_manager:transition()
    status = true
  else
    status, err = coroutine.resume(mainloop)
  end
  if not status then
    local system_info = "OS: " .. love.system.getOS()
    if self.game_updater then
      system_info = system_info .. "\n" .. self.game_updater.game_version
    end
    error(err .. "\n" .. debug.traceback(mainloop).. "\n" .. system_info)
  end
  if self.server_queue and self.server_queue:size() > 0 then
    logger.trace("Queue Size: " .. self.server_queue:size() .. " Data:" .. self.server_queue:to_short_string())
  end
  this_frame_messages = {}

  sound.update_music()
end

function Game:draw()
  -- if not main_font then
  -- main_font = love.graphics.newFont("Oswald-Light.ttf", 15)
  -- end
  -- main_font:setLineHeight(0.66)
  -- love.graphics.setFont(main_font)
  if self.foreground_overlay then
    local scale = consts.CANVAS_WIDTH / math.max(self.foreground_overlay:getWidth(), self.foreground_overlay:getHeight()) -- keep image ratio
    graphics_util.menu_drawf(self.foreground_overlay, consts.CANVAS_WIDTH / 2, consts.CANVAS_HEIGHT / 2, "center", "center", 0, scale, scale)
  end

  -- Clear the screen
  love.graphics.setBlendMode("alpha", "alphamultiply")
  love.graphics.setCanvas(global_canvas)
  love.graphics.setBackgroundColor(unpack(global_background_color))
  love.graphics.clear()

  for i = self.gfx_q.first, self.gfx_q.last do
    self.gfx_q[i][1](unpack(self.gfx_q[i][2]))
  end
  self.gfx_q:clear()

  -- Draw the FPS if enabled
  if self.config.show_fps then
    love.graphics.print("FPS: " .. love.timer.getFPS(), 1, 1)
  end

  love.graphics.setCanvas() -- render everything thats been added
  love.graphics.clear(love.graphics.getBackgroundColor()) -- clear in preperation for the next render
  
  x, y, w, h = graphics_util.scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(self.global_canvas, x, y, 0, w / consts.CANVAS_WIDTH, h / consts.CANVAS_HEIGHT)

  -- draw background and its overlay
  local scale = consts.CANVAS_WIDTH / math.max(self.backgroundImage:getWidth(), self.backgroundImage:getHeight()) -- keep image ratio
  graphics_util.menu_drawf(self.backgroundImage, consts.CANVAS_WIDTH / 2, consts.CANVAS_HEIGHT / 2, "center", "center", 0, scale, scale)
  if self.background_overlay then
    local scale = consts.CANVAS_WIDTH / math.max(self.background_overlay:getWidth(), self.background_overlay:getHeight()) -- keep image ratio
    graphics_util.menu_drawf(self.background_overlay, consts.CANVAS_WIDTH / 2, consts.CANVAS_HEIGHT / 2, "center", "center", 0, scale, scale)
  end
end

function Game:clearMatch()
  self.match = nil
  self.gameIsPaused = false
  self.renderDuringPause = false
  self.currently_paused_tracks = {}
  P1 = nil
  P2 = nil
end

return Game

local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local Music = require("client.src.music.Music")
local StageTrack = require("client.src.music.StageTrack")
local DynamicStageTrack = require("client.src.music.DynamicStageTrack")
local RelayStageTrack = require("client.src.music.RelayStageTrack")
local class = require("common.lib.class")
local Mod = require("client.src.mods.Mod")
local UpdatingImage = require("client.src.graphics.UpdatingImage")
local SoundController = require("client.src.music.SoundController")

-- Stuff defined in this file:
--  . the data structure that store a stage's data

local basic_images = {"thumbnail"}
local allImages = {"thumbnail", "background"}
local defaulted_images = {thumbnail = true, background = true} -- those images will be defaulted if missing
local basic_musics = {}
local other_musics = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}
local defaulted_musics = {} -- those musics will be defaulted if missing

local default_stage = nil -- holds default assets fallbacks
local randomStage = nil -- acts as the bundle stage for all theme stages

local Stage =
  class(
  function(s, full_path, folder_name)
    s.path = full_path -- string | path to the stage folder content
    s.id = folder_name -- string | id of the stage, specified in config.json
    s.display_name = s.id -- string | display name of the stage
    s.sub_stages = {} -- string | either empty or with two elements at least; holds the sub stages IDs for bundle stages
    s.images = {} -- images 
    s.musics = {} -- music
    s.fully_loaded = false
    s.is_visible = true
    s.music_style = "normal"
    s.stageTrack = nil
    s.TYPE = "stage"
  end,
  Mod
)

function Stage.json_init(self)
  local read_data = fileUtils.readJsonFile(self.path .. "/config.json")

  if read_data then
    if read_data.id and type(read_data.id) == "string" then
      self.id = read_data.id

      -- sub ids for bundles
      if read_data.sub_ids and type(read_data.sub_ids) == "table" then
        self.sub_stages = read_data.sub_ids
      end

      -- display name
      if read_data.name and type(read_data.name) == "string" then
        self.display_name = read_data.name
      end
      -- is visible
      if read_data.visible ~= nil and type(read_data.visible) == "boolean" then
        self.is_visible = read_data.visible
      elseif read_data.visible and type(read_data.visible) == "string" then
        self.is_visible = read_data.visible == "true"
      end

      --music style
      if read_data.music_style and type(read_data.music_style) == "string" then
        self.music_style = read_data.music_style
      end

      return true
    end
  end

  return false
end

-- preemptively loads a stage
function Stage.preload(self)
  logger.debug("preloading stage " .. self.id)
  self:graphics_init(false, false)
  self:sound_init(false, false)
end

-- loads a stage
function Stage.load(self, instant)
  self:graphics_init(true, (not instant))
  self:sound_init(true, (not instant))
  self.fully_loaded = true
  logger.debug("loaded stage " .. self.id)
end

-- unloads a stage
function Stage.unload(self)
  logger.debug("unloading stage " .. self.id)
  self:graphics_uninit()
  self:sound_uninit()
  self.fully_loaded = false
  logger.debug("unloaded stage " .. self.id)
end

-- for reloading the graphics if the window was resized
function stages_reload_graphics()
  -- lazy load everything
  for _, stage in pairs(stages) do
    stage:graphics_init(false, false)
  end
  require("client.src.mods.StageLoader").loadBundleThumbnails()

  -- reload the current stage graphics immediately
  local match = GAME.battleRoom and GAME.battleRoom.match
  if match and match.stageId then
    if stages[match.stageId] then
      stages[match.stageId]:graphics_init(true, false)
      -- for reasons, this is not drawn directly from the stage but from background image
      -- so override this while in a match
      GAME.backgroundImage = UpdatingImage(stages[match.stageId].images.background, false, 0, 0, consts.CANVAS_WIDTH, consts.CANVAS_HEIGHT)
    end
  end
end

-- whether or not a stage is part of a bundle or not
function Stage.is_bundle(self)
  return #self.sub_stages > 1
end

function Stage:getSubMods()
  local m = {}
  for _, id in ipairs(self.sub_stages) do
    m[#m + 1] = stages[id]
  end
end

function Stage.loadDefaultStage()
  default_stage = Stage("client/assets/stages/__default", "__default")
  default_stage:preload()
  default_stage:load(true)
end

-- initalizes stage graphics
function Stage.graphics_init(self, full, yields)
  local stage_images = full and allImages or basic_images
  for _, image_name in ipairs(stage_images) do
    self.images[image_name] = GraphicsUtil.loadImageFromSupportedExtensions(self.path .. "/" .. image_name)
    if not self.images[image_name] and defaulted_images[image_name] and not self:is_bundle() then
      self.images[image_name] = default_stage.images[image_name]
      if not self.images[image_name] then
        error("Could not find default stage image")
      end
    end
    if yields then
      coroutine.yield()
    end
  end
end

-- bundles without stage thumbnail display up to 4 thumbnails of their substages
function Stage:createThumbnail()
  local canvas = love.graphics.newCanvas(2 * 80, 2 * 45)
  canvas:renderTo(function()
    for i, substageId in ipairs(self.sub_stages) do
      if i <= 4 then
        local stage = stages[substageId]
        local x = 0
        local y = 0
        if i % 2 == 0 then
          x = 80
        end
        if i > 2 then
          y = 45
        end
        local width, height = stage.images.thumbnail:getDimensions()
        love.graphics.draw(stage.images.thumbnail, x, y, 0, 80 / width, 45 / height)
      end
    end
  end)
  return canvas
end

-- uninits stage graphics
function Stage.graphics_uninit(self)
  for imageName, _ in pairs(self.images) do
    if not tableUtils.contains(basic_images, imageName) then
      self.images[imageName] = nil
    end
  end
end

-- applies the current configuration volume to a stage
function Stage.applyConfigVolume(self)
  SoundController:applyMusicVolume(self.musics)
end

-- initializes stage music
function Stage.sound_init(self, full, yields)
  if self:is_bundle() then
    return
  end
  local stage_musics = full and other_musics or basic_musics
  for _, music in ipairs(stage_musics) do
    self.musics[music] = fileUtils.loadSoundFromSupportExtensions(self.path .. "/" .. music, true)
    -- Set looping status for music.
    -- Intros won't loop, but other parts should.
    if self.musics[music] then
      if not string.find(music, "start") then
        self.musics[music]:setLooping(true)
      else
        self.musics[music]:setLooping(false)
      end
    elseif not self.musics[music] and defaulted_musics[music] then
      self.musics[music] = default_stage.musics[music] or themes[config.theme].zero_sound
    end

    if yields then
      coroutine.yield()
    end
  end

  self:applyConfigVolume()

  if full and self.musics.normal_music then
    local normalMusic = Music(self.musics.normal_music, self.musics.normal_music_start)
    local dangerMusic
    if self.musics.danger_music then
      dangerMusic = Music(self.musics.danger_music, self.musics.danger_music_start)
    end
    if self.music_style == "normal" then
      self.stageTrack = StageTrack(normalMusic, dangerMusic)
    elseif self.music_style == "dynamic" then
      if dangerMusic then
        self.stageTrack = DynamicStageTrack(normalMusic, dangerMusic)
      else
        -- DynamicStageTrack HAVE to have danger music
        -- default back to a regular stage track if there is none
        self.stageTrack = StageTrack(normalMusic)
      end
    elseif self.music_style == "relay" then
      self.stageTrack = RelayStageTrack(normalMusic, dangerMusic)
    end
  end
end

-- uninits stage music
function Stage.sound_uninit(self)
  -- music
  for _, music in ipairs(other_musics) do
    self.musics[music] = nil
  end
end

function Stage:validate()
  -- validate that the mod has both normal and danger music if it is dynamic
  -- do this on initialization so modders get a crash on load and know immediately what to fix
  if self.music_style == "dynamic" then
    if not fileUtils.soundFileExists("normal_music", self.path) or fileUtils.soundFileExists("danger_music", self.path) then
      local err = "Error loading stage " .. self.id .. "\n at "
                  .. self.path ..
                  ":\n Stages with dynamic music must have a normal_music and danger_music file"
      return false, err
    end
  end
end

local function loadRandomStage()
  local randomStage = Stage("stages/__default", consts.RANDOM_STAGE_SPECIAL_VALUE)
  randomStage.images["thumbnail"] = themes[config.theme].images.IMG_random_stage
  randomStage.display_name = "random"
  randomStage.sub_stages = stages_ids_for_current_theme
  randomStage.preload = function() end
  return randomStage
end

function Stage.getRandomStage()
  if not randomStage then
    randomStage = loadRandomStage()
  end

  return randomStage
end

return Stage
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")

local ANIMATION_STATES = {
  "normal", "landing", "swapping",
  "flash", "face", "popping",
  "hovering", "falling",
  "dimmed", "dead",
  "danger",
  "garbageBounce",
  "garbagePop"
}
local DEFAULT_PANEL_ANIM =
{
  -- currently not animatable
	normal = {frames = {1}},
  -- doesn't loop, fixed duration of 12 frames
	landing = {frames = {4, 3, 2, 1}, durationPerFrame = 3},
  -- doesn't loop, fixed duration of 4 frames
  swapping = {frames = {1}},
  -- loops
	flash = {frames = {5, 1}},
  -- doesn't loop
  face = {frames = {6}},
  -- doesn't loop
	popping = {frames = {6}},
  -- too short to reasonably animate
	hovering = {frames = {1}},
  -- currently not animatable
	falling = {frames = {1}},
  -- currently not animatable
  dimmed = {frames = {7}},
  -- currently not animatable
	dead = {frames = {6}},
  -- loops; frames play back to front, fixed to 18 frames
  -- danger is special in that there is a frame offset depending on column offset
  -- col 1 and 2 start on frame 3, col 3 and 4 start on frame 4 and col 5 and 6 start on frame 5 of the animation
	danger = {frames = {1, 2, 3, 2, 1, 4}, durationPerFrame = 3},
  -- doesn't loop; fixed to 12 frames
	garbageBounce = {frames = {1, 4, 3, 2}, durationPerFrame = 3},
  -- currently not animatable
  garbagePop = {frames = {1}},
}

-- The class representing the panel image data
-- Not to be confused with "Panel" which is one individual panel in the game stack model
Panels =
  class(
  function(self, full_path, folder_name)
    self.path = full_path -- string | path to the panels folder content
    self.id = folder_name -- string | id of the panel set, is also the name of its folder by default, may change in json_init
    self.images = {}
    -- sprite sheets indexed by color
    self.sheets = {}
    -- mapping each animation state to a row on the sheet
    self.sheetConfig = {}
    self.batches = {}
    self.size = 16
  end
)

function Panels:json_init()
  local read_data = fileUtils.readJsonFile(self.path .. "/config.json")
  if read_data then
    if read_data.id then
      self.id = read_data.id

      self.name = read_data.name or self.id
      self.type = read_data.type or "single"
      self.animationConfig = read_data.animationConfig or DEFAULT_PANEL_ANIM

      return true
    end
  end

  return false
end

-- Recursively load all panel images from the given directory
local function add_panels_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for i, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path, "directory") then
      -- call recursively: facade folder
      add_panels_from_dir_rec(current_path)

      -- init stage: 'real' folder
      local panel_set = Panels(current_path, v)
      local success = panel_set:json_init()

      if success then
        if panels[panel_set.id] ~= nil then
          logger.trace(current_path .. " has been ignored since a panel set with this id has already been found")
        else
          panels[panel_set.id] = panel_set
          panels_ids[#panels_ids + 1] = panel_set.id
        end
      end
    end
  end
end

function panels_init()
  panels = {} -- holds all panels, all of them will be fully loaded
  panels_ids = {} -- holds all panels ids

  add_panels_from_dir_rec("panels")

  if #panels_ids == 0 or (config and not config.defaultPanelsCopied) then
    fileUtils.recursiveCopy("client/assets/panels/__default", "panels/pacci")
    fileUtils.recursiveCopy("client/assets/default_data/panels", "panels")
    config.defaultPanelsCopied = true
    add_panels_from_dir_rec("panels")
  end

  -- fix config panel set if it's missing
  if not config.panels or not panels[config.panels] then
    if panels["pacci"] then
      config.panels = "pacci"
    else
      config.panels = tableUtils.getRandomElement(panels_ids)
    end
  end

  for _, panel in pairs(panels) do
    panel:load()
  end
end

local function load_panel_img(path, name)
  local img = GraphicsUtil.loadImageFromSupportedExtensions(path .. "/" .. name)
  if not img then
    img = GraphicsUtil.loadImageFromSupportedExtensions("client/assets/panels/__default/" .. name)

    if not img then
      error("Could not find default panel image")
    end
  end

  return img
end

function Panels:loadSheets()
  for color = 1, 8 do
    self.sheets[color] = load_panel_img(self.path, "panel-" .. color)
  end
  self.sheetConfig = self.animationConfig
  for i, animationState in ipairs(ANIMATION_STATES) do
    if not self.sheetConfig[animationState].durationPerFrame then
      self.sheetConfig[animationState].durationPerFrame = 2
    end
    self.sheetConfig[animationState].totalFrames =
        self.sheetConfig[animationState].frames * self.sheetConfig[animationState].durationPerFrame
  end
end

-- 
function Panels:convertSinglesToSheetTexture(images)
  local canvas = love.graphics.newCanvas(self.size * 10, self.size * #ANIMATION_STATES)
  canvas:renderTo(function()
    local row = 1
    -- ipairs over a static table so the ordering is definitely consistent
    for _, animationState in ipairs(ANIMATION_STATES) do
      local animationConfig = self.animationConfig[animationState]
      for frameNumber, imageIndex in ipairs(animationConfig.frames) do
        love.graphics.draw(images[imageIndex], self.size * (frameNumber - 1), self.size * (row - 1))
      end
      row = row + 1
    end
  end)

  return canvas
end

function Panels:loadSingles()
  local panelFiles = fileUtils.getFilteredDirectoryItems(self.path, "file")
  panelFiles = tableUtils.filter(panelFiles, function(f)
    return string.match(f, "panel%d%d+%.")
  end)
  local images = {}
  for color = 1, 8 do
    images[color] = {}

    local files = tableUtils.filter(panelFiles, function(f)
      return string.match(f, "panel" .. color .. "%d+%.")
    end)

    for i, file in ipairs(files) do
      local index = tonumber(string.match(files[i], tostring(color) .. "%d+", 6):sub(2))
      images[color][index] = load_panel_img(self.path, fileUtils.getFileNameWithoutExtension(file))
    end
  end

  for color, panelImages in ipairs(images) do
    self.sheets[color] = self:convertSinglesToSheetTexture(panelImages)
  end

  for i, animationState in ipairs(ANIMATION_STATES) do
    self.sheetConfig[animationState] =
    {
      row = i,
      durationPerFrame = self.animationConfig[animationState].durationPerFrame or 2,
      frames = #self.animationConfig[animationState].frames
    }
    self.sheetConfig[animationState].totalFrames =
        self.sheetConfig[animationState].frames * self.sheetConfig[animationState].durationPerFrame
  end
end

function Panels:load()
  logger.debug("loading panels " .. self.id)

  self.greyPanel = load_panel_img(self.path, "panel00")
  self.size = self.greyPanel:getWidth()
  self.scale = 48 / self.size

  self.images.metals = {
    left = load_panel_img(self.path, "metalend0"),
    mid = load_panel_img(self.path, "metalmid"),
    right = load_panel_img(self.path, "metalend1"),
    flash = load_panel_img(self.path, "garbageflash")
  }

  if self.type == "single" then
    self:loadSingles()
  else
    self:loadSheets()
  end

  self.quad = love.graphics.newQuad(0, 0, self.size, self.size, self.sheets[1])
  self.displayIcons = {}
  for color = 1, 8 do
    local canvas = love.graphics.newCanvas(self.size, self.size)
    canvas:renderTo(function()
      self:drawPanelFrame(color, "normal", 0, 0)
    end)
    self.displayIcons[color] = canvas
    --fileUtils.saveTextureToFile(self.sheets[color], self.path .. "/panel-" .. color, "png")
    self.batches[color] = love.graphics.newSpriteBatch(self.sheets[color], 100, "stream")
  end
end


------------------------------------------
--[[
  Next section is only to verify 
  that the new system's default settings 
  are 100% identical with the current behaviour
--]]
------------------------------------------

local function shouldFlashForFrame(frame)
  local flashFrames = 1
  flashFrames = 2 -- add config
  return frame % (flashFrames * 2) < flashFrames
end

-- frames to use for bounce animation
local BOUNCE_TABLE = {1, 1, 1, 1,
                2, 2, 2,
                3, 3, 3,
                4, 4, 4}

-- frames to use for garbage bounce animation
local GARBAGE_BOUNCE_TABLE = {2, 2, 2,
                              3, 3, 3,
                              4, 4, 4,
                              1, 1}

-- frames to use for in danger animation
local DANGER_BOUNCE_TABLE = {1, 1, 1,
                              2, 2, 2,
                              3, 3, 3,
                              2, 2, 2,
                              1, 1, 1,
                              4, 4, 4}

local oldDrawImplementation = function(panelSet, panel, x, y, danger_col, col, dangerTimer)
  local draw_frame = 1
  if panel.isGarbage then
    if panel.state == "matched" then
      local flash_time = panel.initial_time - panel.timer
      if flash_time >= panel.frameTimes.FLASH then
        if panel.timer > panel.pop_time then
          if panel.metal then
          else
          end
        elseif panel.y_offset == -1 then
          draw_frame = 1
          -- hardcoded reference to panel 1
          -- GraphicsUtil.drawGfxScaled(panels[self.panels_dir].images.classic[panel.color][1], draw_x, draw_y, 0, 16 / p_w, 16 / p_h)
        end
      end
    end
  else
    if panel.state == "matched" then
      local flash_time = panel.frameTimes.FACE - panel.timer
      if flash_time >= 0 then
        draw_frame = 6
      elseif shouldFlashForFrame(flash_time) == false then
        draw_frame = 1
      else
        draw_frame = 5
      end
    elseif panel.state == "popping" then
      draw_frame = 6
    elseif panel.state == "landing" then
      draw_frame = BOUNCE_TABLE[panel.timer + 1]
    elseif panel.state == "swapping" then
      if panel.isSwappingFromLeft then
        x = x - panel.timer * 4
      else
        x = x + panel.timer * 4
      end
    elseif panel.state == "dead" then
      draw_frame = 6
    elseif panel.state == "dimmed" then
      draw_frame = 7
    elseif panel.fell_from_garbage then
      draw_frame = GARBAGE_BOUNCE_TABLE[panel.fell_from_garbage] or 1
    elseif danger_col[col] then
      draw_frame = DANGER_BOUNCE_TABLE[wrap(1, dangerTimer + 1 + math.floor((col - 1) / 2), #DANGER_BOUNCE_TABLE)]
    else
      draw_frame = 1
    end
  end

  return draw_frame
end

----------------------------------------

local floor = math.floor
local min = math.min

local function getGarbageBounceProps(panelSet, panel)
  local conf = panelSet.sheetConfig.garbageBounce
  -- fell_from_garbage counts down from 12 to 0
  if panel.fell_from_garbage > 0 then
    return conf, min(floor((12 - panel.fell_from_garbage) / conf.durationPerFrame) + 1, conf.frames)
  else
    return conf, 1
  end
end

local function getDangerBounceProps(panelSet, panel, dangerTimer)
  local conf = panelSet.sheetConfig.danger
  -- danger_timer counts down from 18 or 15 to 0, depending on what triggered it and then wrapping back to 18
  local frame = math.ceil(wrap(1, dangerTimer + 1 + math.floor((panel.column - 1) / 2), conf.durationPerFrame * conf.frames) / conf.durationPerFrame)
  return conf, frame
end

function Panels:getDrawProps(panel, x, y, dangerCol, dangerTimer)
  local conf
  local frame
  local animationName
  if panel.state == "normal" then
    if dangerCol[panel.column] then
      animationName = "danger"
      conf, frame = getDangerBounceProps(self, panel, dangerTimer)
    else
      animationName = "normal"
      -- normal has no timer at the moment, therefore restricted to 1 frame
      conf = self.sheetConfig.normal
      frame = 1
    end
  elseif panel.state == "matched" then
    if panel.isGarbage then
      animationName = "garbagePop"
      conf = self.sheetConfig.garbagePop
      frame = 1
    else
      -- divide between flash and face
      -- matched timer counts down to 0
      if panel.timer <= panel.frameTimes.FACE then
        animationName = "face"
        conf = self.sheetConfig.face
        local faceTime = (panel.frameTimes.FACE - panel.timer)
        -- nonlooping animation that is counting up
        if faceTime < conf.totalFrames then
          -- starting at the beginning of the timer
          -- floor and +1 because the timer starts at 0 (could instead also +1 the timer and ceil)
          frame = floor(faceTime / conf.durationPerFrame) + 1
        else
          -- and then sticking to the final frame for the remainder
          frame = conf.frames
        end
      else
        animationName = "flash"
        conf = self.sheetConfig.flash
        -- matched panels flash until they counted down to panel.frameConstants.FACE
        -- so to find out which frame of flash we're on, add face and subtract the timer
        local flashTime = panel.frameTimes.FLASH + panel.frameTimes.FACE - panel.timer
        frame = floor((flashTime % conf.totalFrames) / conf.durationPerFrame) + 1
      end
    end
  elseif panel.state == "swapping" then
    animationName = "swapping"
    conf = self.sheetConfig.swapping
    frame = 1
    if panel.isSwappingFromLeft then
      x = x - panel.timer * 12
    else
      x = x + panel.timer * 12
    end
  elseif panel.state == "popped" then
    -- draw nothing
    return
  elseif panel.state == "landing" then
    animationName = "landing"
    conf = self.sheetConfig.landing
    -- landing always counts down from 12, ending at 0
    frame = min(floor((12 - panel.timer) / conf.durationPerFrame) + 1, conf.frames)
  elseif panel.state == "hovering" then
    if panel.fell_from_garbage then
      animationName = "garbageBounce"
      conf, frame = getGarbageBounceProps(self, panel)
    elseif dangerCol[panel.column] then
      animationName = "danger"
      conf, frame = getDangerBounceProps(self, panel, dangerTimer)
    else
      animationName = "hovering"
      conf = self.sheetConfig.hovering
      frame = 1
    end
    -- hover is too short to reasonably animate (as short as 3 frames)
    -- if conf.frames == 1 then
    --   frame = 1
    -- else
    --   -- we don't really know if this started with hover or garbage hover time
    --   -- so gotta do it this way
    --   frame = ceil(panel.timer / conf.durationPerFrame)
    --   frame = math.abs(frame - conf.frames) + 1
    -- end
  elseif panel.state == "falling" then
    if panel.fell_from_garbage then
      animationName = "garbageBounce"
      conf, frame = getGarbageBounceProps(self, panel)
    elseif dangerCol[panel.column] then
      animationName = "danger"
      conf, frame = getDangerBounceProps(self, panel, dangerTimer)
    else
      animationName = "falling"
      conf = self.sheetConfig.falling
      -- falling has no timer at the moment, therefore restricted to 1 frame
      frame = 1
    end
  elseif panel.state == "popping" then
    animationName = "popping"
    -- popping runs at the end of its timer, not at the start
    -- 6 is the hard limit for when it starts to run because it is the lowest preset value for pop time
    if panel.timer > 6 or self.sheetConfig.popping.frames == 1 then
      -- before that, popping will keep rendering the final face frame
      conf = self.sheetConfig.face
      frame = conf.frames
    else
      conf = self.sheetConfig.popping
      frame = floor((6 - panel.timer) / conf.durationPerFrame) + 1
    end
  elseif panel.state == "dimmed" then
    animationName = "dimmed"
    conf = self.sheetConfig.dimmed
    frame = 1
  elseif panel.state == "dead" then
    animationName = "dead"
    conf = self.sheetConfig.dead
    frame = 1
  end

  -- verify that the default frame we get from the new config and the old frame are the same
  if conf ~= self.sheetConfig.flash then
  -- flash in particular started on a different frame depending on level
  -- on levels with FLASH % 4 == 0 it would start with frame 5
  -- on levels with FLASH % 4 == 2 it would start with frame 1
  -- new baseline will be for it to always start with frame 5 to communicate earlier that the panels matched
  -- with level 8 (FLASH % 4 == 0), this condition can removed and it all validates
  -- but with level 10 (FLASH % 4 == 2), it fails on every single flash

    -- local oldFrame = oldDrawImplementation(self, panel, x, y, dangerCol, panel.column, dangerTimer)
    -- assert(DEFAULT_PANEL_ANIM[animationName].frames[frame] == oldFrame)
  end

  return conf, frame, x, y
end

-- adds the panel to a batch for later drawing
-- x, y: relative coordinates on the stack canvas
-- clock: Stack.clock to calculate animation frames
-- danger: nil - no danger, false - regular danger, true - panic
-- dangerTimer: remaining time for which the danger animation continues 
function Panels:addToDraw(panel, x, y, danger, dangerTimer)
  if panel.color == 9 then
    love.graphics.draw(self.greyPanel, x, y, 0, self.scale)
  else
    local batch = self.batches[panel.color]
    local conf, frame
    conf, frame, x, y = self:getDrawProps(panel, x, y, danger, dangerTimer)

    self.quad:setViewport((frame - 1) * self.size, (conf.row - 1) * self.size, self.size, self.size)
    batch:add(self.quad, x, y, 0, self.scale)
  end
end

-- draws all panel draws that have been added to the batch thus far
function Panels:drawBatch()
  for color = 1, 8 do
    love.graphics.draw(self.batches[color])
  end
end

-- clears the last batch
function Panels:prepareDraw()
  for color = 1, 8 do
    self.batches[color]:clear()
  end
end

-- draws the first frame of a panel's state and color in the specified size at the passed location
function Panels:drawPanelFrame(color, state, x, y, size)
  local sheetConfig = self.sheetConfig[state]
  -- always draw the first frame
  self.quad:setViewport(0, (sheetConfig.row - 1) * self.size, self.size, self.size)
  local scale = (size or self.size) / self.size
  GraphicsUtil.drawQuad(self.sheets[color], self.quad, x, y, 0, scale)
end

return Panels

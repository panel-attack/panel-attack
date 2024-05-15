require("graphics_util")
require("graphics.animated_sprite")
local logger = require("logger")
local tableUtils = require("tableUtils")
--defaults: {frames = 1, row = 1, fps = 30, loop = true}
local DEFAULT_PANEL_ANIM =
{
	filter = false,
	size = {["width"] = 16,["height"] = 16},
	normal = {},
	swappingLeft = {},
	swappingRight = {},
	matched = {row = 4}, 
	popping = {row = 4},
	hover = {},
	falling = {frames= 2, row = 2},
	landing = {frames= 4, row = 7, fps = 20, loop = false},
	danger = {frames= 6, row = 3, fps = 20},
	panic = {row = 7},
	dead = {row = 4},
	flash = {frames= 2},
	dimmed = {row = 5}, 
	fromGarbage = {frames= 4, row = 6, fps = 20}
}
local BLANK_PANEL_ANIM =
{
	filter = false,
	size = {["width"] = 16,["height"] = 16},
	normal = {},
	swappingLeft = {},
	swappingRight = {},
	matched = {},
	popping = {},
	hover = {},
	falling = {},
	landing = {},
	danger = {},
	panic = {},
	dead = {},
	flash = {},
	dimmed = {},
	fromGarbage = {}
}
local METAL_PANEL_ANIM =
{
	filter = false,
	size = {["width"] = 8,["height"] = 16},
	normal = {},
	falling = {},
	landing = {},
	danger = {},
	panic = {},
	dead = {}
}

local METAL_FLASH_PANEL_ANIM =
{
	filter = false,
	size = {["width"] = 16,["height"] = 16},
	flash = {frames = 2},
	matched = {},
	popping = {},
}
local PANEL_ANIM_CONVERTS =
{
	{1,5},
	{2,3},
	{1,2,3,2,1,4},
	{6},
	{7},
	{2,3,4,1},
	{4,3,2,1}
}

local metal_names = {"garbage-L", "garbage-M", "garbage-R", "garbage-flash"}
-- The class representing the panel image data
-- Not to be confused with "Panel" which is one individual panel in the game stack model
Panels =
  class(
  function(self, full_path, folder_name)
    self.path = full_path -- string | path to the panels folder content
    self.id = folder_name -- string | id of the panel set, is also the name of its folder by default, may change in id_init
    self.sheet = false
    self.filter = false
    self.images = {}
    self.animations = {}
  end
)

function Panels:id_init()
  local read_data = {}
  local config_file, err = love.filesystem.newFile(self.path .. "/config.json", "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    config_file:close()
    for k, v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end

  if read_data.sheet then
    self.sheet = read_data.sheet
  end

  for i = 0, 12 do
    local name = (i < 9 and "panel-"..tostring(i) or metal_names[i-8])
    if read_data.animations and read_data.animations[name] then
      self.animations[name] = read_data.animations[name]
    else
      self.animations[name] = i ~= 0 and (i < 9 and DEFAULT_PANEL_ANIM or (i ~= 12 and METAL_PANEL_ANIM or METAL_FLASH_PANEL_ANIM)) or BLANK_PANEL_ANIM
    end
  end

  if read_data.id then
    self.id = read_data.id
    return true
  end

  return false
end

-- Recursively load all panel images from the given directory
local function add_panels_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = FileUtil.getFilteredDirectoryItems(path)
  for i, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
      -- call recursively: facade folder
      add_panels_from_dir_rec(current_path)

      -- init stage: 'real' folder
      local panel_set = Panels(current_path, v)
      local success = panel_set:id_init()

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
    recursive_copy("panels/__default", "panels/pacci")
    recursive_copy("default_data/panels", "panels")
    config.defaultPanelsCopied = true
    add_panels_from_dir_rec("panels")
  end

  -- temporary measure to deliver pacci to existing users
  if not panels["pacci"] and os.time() < os.time({year = 2024, month = 1, day = 31}) then
    recursive_copy("panels/__default", "panels/pacci")
    add_panels_from_dir_rec("panels/pacci")
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

function Panels:load()
  logger.debug("loading panels " .. self.id)
  local function load_panel_img(name)
    local img = GraphicsUtil.loadImageFromSupportedExtensions(self.path .. "/" .. name)
    if not img then
      img = GraphicsUtil.loadImageFromSupportedExtensions("panels/__default/" .. name)
      
      if not img then
        error("Could not find default panel image")
      end
    end

    return img
  end
  -- colors 1-7 are normal colors, 8 is [!], 9 is an empty panel.
  self.images.classic = {}
  local sheet = nil
  local panelSet = nil
  local panelConverts = {}
  local oldFormat = not self.sheet
  if (oldFormat) then
    if oldFormat then
      local draw = love.graphics.draw
      local newCanvas = love.graphics.newCanvas
      for i = 1, 9 do
        local img = load_panel_img("panel"..(i ~= 9 and tostring(i).."1" or "00"))
        local width, height = img:getDimensions()
        local newPanel = "panel-"..tostring(i ~= 9 and tostring(i) or "0")
        self.animations[newPanel].size = {width = width, height = width}
        if height >= 48 then
          self.animations[newPanel].filter = true
        end
        if i ~= 9 then
          local tempCanvas = newCanvas(width*6, height*8)
          tempCanvas:renderTo(function()
              for row, anim in ipairs(PANEL_ANIM_CONVERTS) do
                for count, frame in ipairs(anim) do
                  img = load_panel_img("panel" .. tostring(i) .. tostring(frame))
                  draw(img, width*(count-1), height*(row-1))
                end
              end
            end
          )
          panelConverts[newPanel] = love.graphics.newImage(tempCanvas:newImageData())
          --love.filesystem.write(self.path.."/"..newPanel..".png", tempCanvas:newImageData():encode("png"))
        else
          panelConverts[newPanel] = img
        end
      end

      local metal_oldnames = {"metalend0", "metalmid", "metalend1", "garbageflash"}

      for i = 1, 4 do
        local newPanel = metal_names[i]
        local img = load_panel_img(metal_oldnames[i])
        local width, height = img:getDimensions()
        self.animations[newPanel].size = {width = width, height = height}
        if height >= 48 then
          self.animations[newPanel].filter = true
        end
        local tempCanvas = newCanvas(i ~= 4 and width or width*2, height)
        tempCanvas:renderTo(function()
            if i ~= 4 then
              draw(img, 0, 0)   
            else
              draw(load_panel_img("metalend0"), 0, 0)
              draw(load_panel_img("metalend1"), width/2, 0)
              draw(img, width, 0)
            end
          end
        )
        panelConverts[newPanel] = love.graphics.newImage(tempCanvas:newImageData())
        --love.filesystem.write(self.path.."/"..metal_names[i]..".png", tempCanvas:newImageData():encode("png"))
      end
    end
    -- local newInfo = {
    --   ["id"] = self.id,
    --   ["sheet"] = true,
    --   ["animations"] = self.animations
    -- }
    -- love.filesystem.write(self.path.."/".."config.json", json.encode(newInfo))
  end
  for i = 1, 9 do
    local name = "panel-" .. (i ~= 9 and tostring(i) or "0")
    panelSet = self.animations[name]
    sheet = oldFormat and panelConverts[name] or load_panel_img(name)
    if panelSet.filter then
      sheet:setFilter("linear", "linear")
    end
    self.images.classic[i] = AnimatedSprite(sheet, i, panelSet, panelSet.size.width, panelSet.size.height)
  end

  self.images.metals = {}
  for i = 1, 4 do
    local name = metal_names[i]
    panelSet = self.animations[name]
    sheet = oldFormat and panelConverts[name] or load_panel_img(name)
    if panelSet.filter then
      sheet:setFilter("linear", "linear")
    end
    self.images.metals[i] = AnimatedSprite(sheet, i, panelSet, panelSet.size.width, panelSet.size.height)
  end
end
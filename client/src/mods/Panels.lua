local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- The class representing the panel image data
-- Not to be confused with "Panel" which is one individual panel in the game stack model
Panels =
  class(
  function(self, full_path, folder_name)
    self.path = full_path -- string | path to the panels folder content
    self.id = folder_name -- string | id of the panel set, is also the name of its folder by default, may change in id_init
    self.images = {}
  end
)

function Panels.id_init(self)
  local read_data = fileUtils.readJsonFile(self.path .. "/config.json")

  if read_data and read_data.id then
    self.id = read_data.id
    return true
  end

  return false
end

-- Recursively load all panel images from the given directory
local function add_panels_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
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
    fileUtils.recursiveCopy("client/assets/panels/__default", "panels/pacci")
    fileUtils.recursiveCopy("client/assets/default_data/panels", "panels")
    config.defaultPanelsCopied = true
    add_panels_from_dir_rec("panels")
  end

  -- add pacci panels if not installed
  if not panels["pacci"] then
    add_panels_from_dir_rec("client/assets/panels/__default")
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

function Panels.load(self)
  logger.debug("loading panels " .. self.id)

  local function load_panel_img(name)
    local img = GraphicsUtil.loadImageFromSupportedExtensions(self.path .. "/" .. name)
    if not img then
      img = GraphicsUtil.loadImageFromSupportedExtensions("client/assets/panels/__default/" .. name)
      if not img then
        error("Could not find default panel image")
      end
    end

    -- If height is exactly 48 for this panel image (including metal)
    -- it is a 1x asset that isn't intended to be blocky (most likely)
    -- use linear so it doesn't get jaggy
    local height = img:getHeight()*img:getDPIScale()
    if height == 48 then
      img:setFilter("linear", "linear")
    end
    return img
  end

  self.images.classic = {}
  for i = 1, 8 do
    self.images.classic[i] = {}
    for j = 1, 7 do
      self.images.classic[i][j] = load_panel_img("panel" .. tostring(i) .. tostring(j))
    end
  end
  self.images.classic[9] = {}
  for j = 1, 7 do
    self.images.classic[9][j] = load_panel_img("panel00")
  end

  self.images.metals = {
    left = load_panel_img("metalend0"),
    mid = load_panel_img("metalmid"),
    right = load_panel_img("metalend1"),
    flash = load_panel_img("garbageflash")
  }
end

return Panels
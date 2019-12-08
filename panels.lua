require("graphics_util")

Panels = class(function(self, full_path, folder_name)
    self.path = full_path -- string | path to the panels folder content
    self.id = folder_name -- string | id of the panel set, is also the name of its folder by default, may change in id_init
    self.images = {}
  end)

function Panels.id_init(self)
  local read_data = {}
  local config_file, err = love.filesystem.newFile(self.path.."/config.json", "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    for k,v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end

  if read_data.id then
    self.id = read_data.id
    return true
  end

  return false
end

local function add_panels_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = lfs.getDirectoryItems(path)
  for i,v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
    if start_of_v ~= prefix_of_ignored_dirs then
      local current_path = path.."/"..v
      if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
        -- call recursively: facade folder
        add_panels_from_dir_rec(current_path)

        -- init stage: 'real' folder
        local panel_set = Panels(current_path,v)
        local success = panel_set:id_init()

        if success then
          if panels[panel_set.id] ~= nil then
            print(current_path.." has been ignored since a panel set with this id has already been found")
          else
            panels[panel_set.id] = panel_set
            panels_ids[#panels_ids+1] = panel_set.id
            -- print(current_path.." has been added to the character list!")
          end
        end
      end
    end
  end
end

function panels_init()
  panels = {} -- holds all panels, all of them will be fully loaded
  panels_ids = {} -- holds all panels ids

  add_panels_from_dir_rec("panels")

  -- fix config panel set if it's missing
  if not config.panels or not panels[config.panels] then
    config.panels = uniformly(panels_ids)
  end

  for _,panel in pairs(panels) do
    panel:load()
  end
end

function Panels.load(self)
  print("loading panels "..self.id)

  local function load_panel_img(name)
    local img = load_img_from_supported_extensions(self.path.."/"..name)
    if not img then
      img = load_img_from_supported_extensions("panels/"..default_panels_dir.."/"..name)
    end
    return img
  end

  self.images.classic = {}
  for i=1,8 do
    self.images.classic[i] = {}
    for j=1,7 do
      self.images.classic[i][j] = load_panel_img("panel"..tostring(i)..tostring(j))
    end
  end
  self.images.classic[9] = {}
  for j=1,7 do
    self.images.classic[9][j] = load_panel_img("panel00")
  end

  self.images.metals = { left = load_panel_img("metalend0"), 
                        mid = load_panel_img("metalmid"), 
                        right = load_panel_img("metalend1"),
                        flash = load_panel_img("garbageflash") }
end
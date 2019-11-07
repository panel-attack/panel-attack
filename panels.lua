require("graphics_util")

function panels_init()
  local function load_panel_img(name)
    local img = load_img_from_supported_extensions("panels/"..config.panels.."/"..name)
    if not img then
      img = load_img_from_supported_extensions("panels/"..default_panels_dir.."/"..name)
    end
    return img
  end

  local function load_panels_dir(dir)
    IMG_panels[dir] = {}
    IMG_panels_dirs[#IMG_panels_dirs+1] = dir

    for i=1,8 do
      IMG_panels[dir][i] = {}
      for j=1,7 do
        IMG_panels[dir][i][j] = load_panel_img("panel"..tostring(i)..tostring(j).."")
      end
    end
    IMG_panels[dir][9] = {}
    for j=1,7 do
      IMG_panels[dir][9][j] = load_panel_img("panel00")
    end

    IMG_metals[dir] = { left = load_panel_img("metalend0"), 
                        mid = load_panel_img("metalmid"), 
                        right = load_panel_img("metalend1"),
                        flash = load_panel_img("garbageflash") }
  end

  IMG_panels = {}
  IMG_panels_dirs = {}
  IMG_metals = {}

  local raw_dir_list = love.filesystem.getDirectoryItems("panels")
  for k,v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
    if love.filesystem.getInfo("panels/"..v) and start_of_v ~= prefix_of_ignored_dirs then
      load_panels_dir(v, "panels/"..v)
    end
  end
end
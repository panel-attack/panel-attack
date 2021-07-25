require("stage_loader")

  -- Stuff defined in this file:
  --  . the data structure that store a stage's data

local basic_images = {"thumbnail"}
local other_images = {"background"}
local defaulted_images = { thumbnail=true, background=true } -- those images will be defaulted if missing
local basic_musics = {}
local other_musics = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}
local defaulted_musics = {} -- those musics will be defaulted if missing

local default_stage = nil -- holds default assets fallbacks

Stage = class(function(s, full_path, folder_name)
    s.path = full_path -- string | path to the stage folder content
    s.id = folder_name -- string | id of the stage, specified in config.json
    s.display_name = s.id -- string | display name of the stage
    s.sub_stages = {} -- stringS | either empty or with two elements at least; holds the sub stages IDs for bundle stages
    s.images = {}
    s.musics = {}
    s.fully_loaded = false
    s.is_visible = true
  end)

function Stage.json_init(self)
  local read_data = {}
  local config_file, err = love.filesystem.newFile(self.path.."/config.json", "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    for k,v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end

  if read_data.id and type(read_data.id) == "string" then
    self.id = read_data.id
    
    -- sub ids for bundles
    if read_data.sub_ids and type(read_data.sub_ids) == "table"then
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
      self.is_visible = read_data.visible=="true"
    end

    return true
  end

  return false
end

function Stage.stop_sounds(self)
  -- music
  for _, music in ipairs(self.musics) do
    if self.musics[music] then
      self.musics[music]:stop()
    end
  end
end

function Stage.preload(self)
  print("preloading stage "..self.id)
  self:graphics_init(false,false)
  self:sound_init(false,false)
end

function Stage.load(self,instant)
  print("loading stage "..self.id)
  self:graphics_init(true,(not instant))
  self:sound_init(true,(not instant))
  self.fully_loaded = true
  print("loaded stage "..self.id)
end

function Stage.unload(self)
  print("unloading stage "..self.id)
  self:graphics_uninit()
  self:sound_uninit()
  self.fully_loaded = false
  print("unloaded stage "..self.id)
end

local function add_stages_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = lfs.getDirectoryItems(path)
  for i,v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
    if start_of_v ~= prefix_of_ignored_dirs then
      local current_path = path.."/"..v
      if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
        -- call recursively: facade folder
        add_stages_from_dir_rec(current_path)

        -- init stage: 'real' folder
        local stage = Stage(current_path,v)
        local success = stage:json_init()

        if success then
          if stages[stage.id] ~= nil then
            print(current_path.." has been ignored since a stage with this id has already been found")
          else
            stages[stage.id] = stage
            stages_ids[#stages_ids+1] = stage.id
          end
        end
      end
    end
  end
end

local function fill_stages_ids()
  -- check validity of bundle stages
  local invalid_stages = {}
  local copy_of_stages_ids = shallowcpy(stages_ids)
  stages_ids = {} -- clean up
  for _,stage_id in ipairs(copy_of_stages_ids) do
    local stage = stages[stage_id]
    if #stage.sub_stages > 0 then -- bundle stage (needs to be filtered if invalid)
      local copy_of_sub_stages = shallowcpy(stage.sub_stages)
      stage.sub_stages = {}
      for _,sub_stage in ipairs(copy_of_sub_stages) do
        if stages[sub_stage] and #stages[sub_stage].sub_stages == 0 then -- inner bundles are prohibited
          stage.sub_stages[#stage.sub_stages+1] = sub_stage
          print(stage.id.." has "..sub_stage.." as part of its substages.")
        end
      end

      if #stage.sub_stages < 2 then
        invalid_stages[#invalid_stages+1] = stage_id -- stage is invalid
        print(stage.id.." (bundle) is being ignored since it's invalid!")
      else
        stages_ids[#stages_ids+1] = stage_id
        print(stage.id.." (bundle) has been added to the stage list!")
      end
    else -- normal stage
      stages_ids[#stages_ids+1] = stage_id
      print(stage.id.." has been added to the stage list!")
    end
  end

  -- stages are removed outside of the loop since erasing while iterating isn't working
  for _,invalid_stage in pairs(invalid_stages) do
    stages[invalid_stage] = nil
  end
end

function stages_init()
  stages = {} -- holds all stages, most of them will not be fully loaded
  stages_ids = {} -- holds all stages ids
  stages_ids_for_current_theme = {} -- holds stages ids for the current theme, those stages will appear in the selection
  default_stage = nil

  add_stages_from_dir_rec("stages")
  fill_stages_ids()

  if #stages_ids == 0 then
    recursive_copy("default_data/stages", "stages")
    add_stages_from_dir_rec("stages")
    fill_stages_ids()
  end

  if love.filesystem.getInfo("themes/"..config.theme.."/stages.txt") then
    for line in love.filesystem.lines("themes/"..config.theme.."/stages.txt") do
      line = trim(line) -- remove whitespace
      -- found at least a valid stage in a stages.txt file
      if stages[line] then
        stages_ids_for_current_theme[#stages_ids_for_current_theme+1] = line
      end
    end
  else
    for _,stage_id in ipairs(stages_ids) do
      if stages[stage_id].is_visible then
        stages_ids_for_current_theme[#stages_ids_for_current_theme+1] = stage_id
      end
    end
  end

  -- all stages case
  if #stages_ids_for_current_theme == 0 then
    stages_ids_for_current_theme = shallowcpy(stages_ids)
  end

  -- fix config stage if it's missing
  if not config.stage or ( config.stage ~= random_stage_special_value and not stages[config.stage] ) then
    config.stage = uniformly(stages_ids_for_current_theme) -- it's legal to pick a bundle here, no need to go further
  end
  
  -- actual init for all stages, starting with the default one
  default_stage = Stage("stages/__default", "__default")
  default_stage:preload()
  default_stage:load(true)

  for _,stage in pairs(stages) do
    stage:preload()
  end
end

function Stage.is_bundle(self)
  return #self.sub_stages > 1
end

function Stage.graphics_init(self,full,yields)
  local stage_images = full and other_images or basic_images
  for _,image_name in ipairs(stage_images) do
    self.images[image_name] = load_img_from_supported_extensions(self.path.."/"..image_name)
    if not self.images[image_name] and defaulted_images[image_name] and not self:is_bundle() then
      self.images[image_name] = default_stage.images[image_name]
    end
    if yields then coroutine.yield() end
  end
end

function Stage.graphics_uninit(self)
  for _,image_name in ipairs(other_images) do
    self.images[image_name] = nil
  end
end

function Stage.apply_config_volume(self)
  set_volume(self.musics, config.music_volume/100)
end

function Stage.sound_init(self,full,yields)
  if self:is_bundle() then
    return
  end
  local stage_musics = full and other_musics or basic_musics
  for _, music in ipairs(stage_musics) do
    self.musics[music] = load_sound_from_supported_extensions(self.path.."/"..music, true)
    -- Set looping status for music.
    -- Intros won't loop, but other parts should.
    if self.musics[music] then
      if not string.find(music, "start") then
        self.musics[music]:setLooping(true)
      else
        self.musics[music]:setLooping(false)
      end
    elseif not self.musics[music] and defaulted_musics[music] then
      self.musics[music] = default_stage.musics[music] or zero_sound
    end

    if yields then coroutine.yield() end
  end
  
  self:apply_config_volume()
end

function Stage.sound_uninit(self)
  -- music
  for _,music in ipairs(other_musics) do
    self.musics[music] = nil
  end
end
require("stage_loader")

  -- Stuff defined in this file:
  --  . the data structure that store a stage's data

local basic_images = {"thumbnail"}
local other_images = {"background"}
local basic_musics = {}
local other_musics = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}

Stage = class(function(s, full_path, folder_name)
    s.path = full_path -- string | path to the stage folder content
    s.id = folder_name -- string | id of the stage, is also the name of its folder by default, may change in id_init
    s.display_name = s.id -- string | display name of the stage
    s.images = {}
    s.musics = {}
    s.fully_loaded = false
  end)

function Stage.id_init(self)
  local read_data = {}
  local config_file, err = love.filesystem.newFile(self.path.."/stage.json", "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    for k,v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end

  if read_data.id then
    print("an id was found for "..self.path)
    self.id = read_data.id
  end
end

function Stage.other_data_init(self)
  -- read stage.json
  local read_data = {}
  local config_file, err = love.filesystem.newFile(self.path.."/stage.json", "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    for k,v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end

  -- id has already been handled! DO NOT handle id here!

  -- display name
  if read_data.name then
    self.display_name = read_data.name
  end

  print( self.id..(self.id ~= self.display_name and (", aka "..self.display_name..", ") or " ").."is a playable stage")
end

function Stage.assert_requirements_met(self)
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
  print("preloading "..self.id)
  self:other_data_init()
  self:graphics_init(false,false)
  self:sound_init(false,false)
end

function Stage.load(self,instant)
  print("loading "..self.id)
  self:graphics_init(true,(not instant))
  self:sound_init(true,(not instant))
  self:assert_requirements_met()
  self.fully_loaded = true
  print("loaded "..self.id)
end

function Stage.unload(self)
  print("unloading "..self.id)
  self:graphics_uninit()
  self:sound_uninit()
  self.fully_loaded = false
  print("unloaded "..self.id)
end

local function add_stages_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = lfs.getDirectoryItems(path)
  for i,v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
    if start_of_v ~= prefix_of_ignored_dirs then
      local current_path = path.."/"..v
      if lfs.isDirectory(current_path) then
        -- call recursively: facade folder
        add_stages_from_dir_rec(current_path)

        -- init stage: 'real' folder
        local stage = Stage(current_path,v)
        stage:id_init()

        if stages[stage.id] ~= nil then
          print(current_path.." has been ignored since a stage with this id has already been found")
        else
          stages[stage.id] = stage
          stages_ids[#stages_ids+1] = stage.id
          print(current_path.." has been added to the stage list!")
        end
      end
    end
  end
end

function stages_init()
  stages = {} -- holds all stages, most of them will not be fully loaded
  stages_ids = {} -- holds all stages ids
  stages_ids_for_current_theme = {} -- holds stages ids for the current theme, those stages will appear in the selection
  stages_ids_by_display_names = {} -- holds keys to array of stages ids holding that name

  add_stages_from_dir_rec("stages")

  if love.filesystem.getInfo("assets/"..config.assets_dir.."/stages.txt") then
    for line in love.filesystem.lines("assets/"..config.assets_dir.."/stages.txt") do
      line = trim(line) -- remove whitespace
      if love.filesystem.getInfo("stages/"..line) then
        -- found at least a valid stage in a stages.txt file
        if stages[line] then
          stages_ids_for_current_theme[#stages_ids_for_current_theme+1] = line
          print("found a valid stage:"..stages_ids_for_current_theme[#stages_ids_for_current_theme])
        end
      end
    end
  end

  -- all stages case
  if #stages_ids_for_current_theme == 0 then
    stages_ids_for_current_theme = shallowcpy(stages_ids)
  end

  -- fix config stage if it's missing
  if not config.stage or ( config.stage ~= random_stage_special_value and not stages[config.stage] ) then
    config.stage = uniformly(stages_ids_for_current_theme)
  end
  
  -- actual init for all stages
  for _,stage in pairs(stages) do
    stage:preload()

    if stages_ids_by_display_names[stage.display_name] then
      stages_ids_by_display_names[stage.display_name][#stages_ids_by_display_names[stage.display_name]+1] = stage.id
    else
      stages_ids_by_display_names[stage.display_name] = { stage.id }
    end
  end
end

function Stage.graphics_init(self,full,yields)
  local stage_images = full and other_images or basic_images
  for _,image_name in ipairs(stage_images) do
    self.images[image_name] = get_img_from_supported_extensions("stages/"..self.id.."/"..image_name)
    if not self.images[image_name] then
      self.images[image_name] = simple_load_img( "stages/__default/"..image_name..".png" )
    end
    if yields then coroutine.yield() end
  end
end

function Stage.graphics_uninit(self)
  for _,image_name in ipairs(other_images) do
    self.images[image_name] = nil
  end
end

local function find_music(stage_id, music_type)
  local dirs_to_check = { "stages/",
                          "sounds/"..default_sounds_dir.."/music/" }
  for _,current_dir in ipairs(dirs_to_check) do
    local path = current_dir..stage_id
    local music = get_from_supported_extensions(path.."/"..music_type, true)
    if music then
      return music
    end
  end
  return zero_sound
end

function Stage.sound_init(self,full,yields)
  -- music
  local stage_musics = full and other_musics or basic_musics
  for _, music in ipairs(stage_musics) do
    self.musics[music] = find_music(self.id, music)
    -- Set looping status for music.
    -- Intros won't loop, but other parts should.
    if self.musics[music] then
      if not string.find(music, "start") then
        self.musics[music]:setLooping(true)
      else
        self.musics[music]:setLooping(false)
      end
    end
    if yields then coroutine.yield() end
  end
end

function Stage.sound_uninit(self)
  -- music
  for _,music in ipairs(other_musics) do
    self.musics[music] = nil
  end
end
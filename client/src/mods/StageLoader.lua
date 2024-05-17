local Stage = require("client.src.mods.Stage")
local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")

local StageLoader = {}

-- adds stages from the path given
local function add_stages_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for i, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
      -- call recursively: facade folder
      add_stages_from_dir_rec(current_path)

      -- init stage: 'real' folder
      local stage = Stage(current_path, v)
      local success = stage:json_init()

      if success then
        if stages[stage.id] ~= nil then
          logger.trace(current_path .. " has been ignored since a stage with this id has already been found")
        else
          stages[stage.id] = stage
          stages_ids[#stages_ids + 1] = stage.id
        end
      end
    end
  end
end

-- get stage bundles
local function fill_stages_ids()
  -- check validity of bundle stages
  local invalid_stages = {}
  local copy_of_stages_ids = shallowcpy(stages_ids)
  stages_ids = {} -- clean up
  for _, stage_id in ipairs(copy_of_stages_ids) do
    local stage = stages[stage_id]
    if #stage.sub_stages > 0 then -- bundle stage (needs to be filtered if invalid)
      local copy_of_sub_stages = shallowcpy(stage.sub_stages)
      stage.sub_stages = {}
      for _, sub_stage in ipairs(copy_of_sub_stages) do
        if stages[sub_stage] and #stages[sub_stage].sub_stages == 0 then -- inner bundles are prohibited
          stage.sub_stages[#stage.sub_stages + 1] = sub_stage
          logger.trace(stage.id .. " has " .. sub_stage .. " as part of its substages.")
        end
      end

      if #stage.sub_stages < 2 then
        invalid_stages[#invalid_stages + 1] = stage_id -- stage is invalid
        logger.warn(stage.id .. " (bundle) is being ignored since it's invalid!")
      else
        stages_ids[#stages_ids + 1] = stage_id
        logger.debug(stage.id .. " (bundle) has been added to the stage list!")
      end
    else -- normal stage
      stages_ids[#stages_ids + 1] = stage_id
      logger.debug(stage.id .. " has been added to the stage list!")
    end
  end

  -- stages are removed outside of the loop since erasing while iterating isn't working
  for _, invalid_stage in pairs(invalid_stages) do
    stages[invalid_stage] = nil
  end
end

-- initializes the stage class
function StageLoader.initStages()
  stages = {} -- holds all stages, most of them will not be fully loaded
  stages_ids = {} -- holds all stages ids
  stages_ids_for_current_theme = {} -- holds stages ids for the current theme, those stages will appear in the selection
  default_stage = nil

  add_stages_from_dir_rec("stages")
  fill_stages_ids()

  if #stages_ids == 0 then
    fileUtils.recursiveCopy("client/assets/default_data/stages", "stages")
    add_stages_from_dir_rec("stages")
    fill_stages_ids()
  end

  if love.filesystem.getInfo(themes[config.theme].path .. "/stages.txt") then
    for line in love.filesystem.lines(themes[config.theme].path .. "/stages.txt") do
      line = trim(line) -- remove whitespace
      -- found at least a valid stage in a stages.txt file
      if stages[line] then
        stages_ids_for_current_theme[#stages_ids_for_current_theme + 1] = line
      end
    end
  else
    for _, stage_id in ipairs(stages_ids) do
      if stages[stage_id].is_visible then
        stages_ids_for_current_theme[#stages_ids_for_current_theme + 1] = stage_id
      end
    end
  end

  -- all stages case
  if #stages_ids_for_current_theme == 0 then
    stages_ids_for_current_theme = shallowcpy(stages_ids)
  end

  -- fix config stage if it's missing
  if not config.stage or (config.stage ~= consts.RANDOM_STAGE_SPECIAL_VALUE and not stages[config.stage]) then
    config.stage = tableUtils.getRandomElement(stages_ids_for_current_theme) -- it's legal to pick a bundle here, no need to go further
  end

  Stage.loadDefaultStage()

  local randomStage = Stage.getRandomStage()
  stages_ids[#stages_ids+1] = randomStage.id
  stages[randomStage.id] = randomStage

  for _, stage in pairs(stages) do
    stage:preload()
  end

  -- bundles without stage thumbnail display up to 4 thumbnails of their substages
  -- there is no guarantee the substages had been loaded previously so do it after everything got preloaded
  for _, stage in pairs(stages) do
    if stage:is_bundle() and not stage.images.thumbnail then
      stage.images.thumbnail = stage:createThumbnail()
    end
  end
end

function StageLoader.resolveStageSelection(stageId)
  if not stageId or not stages[stageId] then
    -- resolve via random selection
    stageId = tableUtils.getRandomElement(stages_ids_for_current_theme)
  end

  return stageId
end

function StageLoader.resolveBundle(stageId)
  while stages[stageId]:is_bundle() do
    stageId = tableUtils.getRandomElement(stages[stageId].sub_stages)
  end

  return stageId
end

function StageLoader.fullyResolveStageSelection(stageId)
  logger.debug("Resolving stageId " .. (stageId or ""))
  stageId = StageLoader.resolveStageSelection(stageId)
  stageId = StageLoader.resolveBundle(stageId)
  logger.debug("Resolved stageId to " .. stageId)
  return stageId
end

return StageLoader
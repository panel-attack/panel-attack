require("queue")
require("globals")
local tableUtils = require("tableUtils")

StageLoader = {}

local loading_queue = Queue() -- stages to load

local loading_stage = nil -- currently loading stage

-- loads the stages of the specified id
function StageLoader.load(stage_id)
  if stages[stage_id] and not stages[stage_id].fully_loaded then
    loading_queue:push(stage_id)
  end
end

local instant_load_enabled = false

-- return true if there is still data to load
function StageLoader.update()
  if not loading_stage and loading_queue:len() > 0 then
    local stage_id = loading_queue:pop()
    loading_stage = {
      stage_id,
      coroutine.create(
        function()
          stages[stage_id]:load(instant_load_enabled)
        end
      )
    }
  end

  if loading_stage then
    if coroutine.status(loading_stage[2]) == "suspended" then
      coroutine.resume(loading_stage[2])
      return true
    elseif coroutine.status(loading_stage[2]) == "dead" then
      loading_stage = nil
      return loading_queue:len() > 0
    -- TODO: unload stages if too much data have been loaded (be careful not to release currently-used stages)
    end
  end

  return false
end

-- waits on loading stages
function StageLoader.wait()
  instant_load_enabled = true
  while true do
    if not StageLoader.update() then
      break
    end
  end
  instant_load_enabled = false
end

-- unloads stages
function StageLoader.clear()
  local p2_local_stage = global_op_state and global_op_state.stage or nil
  for stage_id, stage in pairs(stages) do
    if stage.fully_loaded and stage_id ~= config.stage and stage_id ~= p2_local_stage then
      stage:unload()
    end
  end
end

function StageLoader.resolveStageSelection(stageId)
  if stageId and stages[stageId] then
    stageId = StageLoader.resolveBundle(stageId)
  else
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
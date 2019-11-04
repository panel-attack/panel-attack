require("queue")
require("globals")

local loading_queue = Queue()

local loading_stage = nil

function stage_loader_load(stage_id)
  if stages[stage_id] and not stages[stage_id].fully_loaded then
    loading_queue:push(stage_id)
  end
end

local instant_load_enabled = false

-- return true if there is still data to load
function stage_loader_update()
  if not loading_stage and loading_queue:len() > 0 then
    local stage_id = loading_queue:pop()
    loading_stage = { stage_id, coroutine.create( function()
      stages[stage_id]:load(instant_load_enabled)
    end) }
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

function stage_loader_wait()
  instant_load_enabled = true
  while true do
    if not stage_loader_update() then
      break
    end
  end
  instant_load_enabled = false
end

function stage_loader_clear()
  local p2_local_stage = global_op_state and global_op_state.stage or nil
  for stage_id,stage in pairs(stages) do
    if stage.fully_loaded and stage_id ~= config.stage and stage_id ~= p2_local_stage then
      stage:unload()
    end
  end
end
local Queue = require("client.src.queue")
local tableUtils = require("common.lib.tableUtils")

local ModLoader = {}

ModLoader.loading_queue = Queue() -- stages to load
ModLoader.cancellationList = {}
ModLoader.loading_mod = nil -- currently loading stage

-- loads the stages of the specified id
function ModLoader.load(mod)
  if not mod.fully_loaded then
    ModLoader.loading_queue:push(mod)
  end
end

-- return true if there is still data to load
function ModLoader.update()
  if not ModLoader.loading_mod and ModLoader.loading_queue:len() > 0 then
    local mod = ModLoader.loading_queue:pop()
    -- if the load was cancelled, just abort here
    if ModLoader.cancellationList[mod] then
      ModLoader.cancellationList[mod] = nil
      return
    end
    ModLoader.loading_mod = {
      mod,
      coroutine.create(
        function()
          mod:load()
        end
      )
    }
  end

  if ModLoader.loading_mod then
    if coroutine.status(ModLoader.loading_mod[2]) == "suspended" then
      coroutine.resume(ModLoader.loading_mod[2])
      return true
    elseif coroutine.status(ModLoader.loading_mod[2]) == "dead" then
      ModLoader.loading_mod = nil
      return ModLoader.loading_queue:len() > 0
    end
  end

  return false
end

-- finish loading all remaining mods
function ModLoader.wait()
  while ModLoader.update() do
  end
end

-- cancels loading the mod if it is currently being loaded or queued for it
function ModLoader.cancelLoad(mod)
  if ModLoader.loading_mod then
    if ModLoader.loading_mod[1] == mod then
      ModLoader.loading_mod = nil
    elseif ModLoader.loading_queue:peek() == mod then
      ModLoader.loading_queue:pop()
    elseif tableUtils.contains(ModLoader.loading_queue, mod) then
      ModLoader.cancellationList[mod] = true
    else
      -- the mod is currently not even queued to be loaded so there should be no cancel
    end
  end
end

return ModLoader
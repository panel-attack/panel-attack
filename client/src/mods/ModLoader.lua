local Queue = require("client.src.queue")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")

local ModLoader = {}

ModLoader.loading_queue = Queue() -- stages to load
ModLoader.cancellationList = {}
ModLoader.loading_mod = nil -- currently loading stage

-- loads the stages of the specified id
function ModLoader.load(mod)
  logger.debug("Queueing mod " .. mod.id .. ", fully_loaded: " .. tostring(mod.fully_loaded))
  if not mod.fully_loaded then
    ModLoader.loading_queue:push(mod)
  end
end

-- return true if there is still data to load
function ModLoader.update()
  if not ModLoader.loading_mod and ModLoader.loading_queue:len() > 0 then
    local mod = ModLoader.loading_queue:pop()
    logger.debug("Preparing to load mod " .. mod.id)
    -- if the load was cancelled, just abort here
    if ModLoader.cancellationList[mod] then
      logger.debug("Mod " .. mod.id .. " was in the cancellation list and has been cancelled")
      ModLoader.cancellationList[mod] = nil
      return true
    end
    logger.debug("Loading mod " .. mod.id)
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
      logger.debug("finished loading mod " .. ModLoader.loading_mod.id)
      ModLoader.loading_mod = nil
      return ModLoader.loading_queue:len() > 0
    end
  end

  return false
end

-- finish loading all remaining mods
function ModLoader.wait()
  logger.debug("finish all mod updates")
  while ModLoader.update() do
  end
end

-- cancels loading the mod if it is currently being loaded or queued for it
function ModLoader.cancelLoad(mod)
  logger.debug("cancelling load for mod " .. mod.id)
  if ModLoader.loading_mod then
    if ModLoader.loading_mod == mod then
      ModLoader.loading_mod = nil
      logger.debug("Mod was currently being loaded, directly cancelled")
    elseif ModLoader.loading_queue:peek() == mod then
      ModLoader.loading_queue:pop()
      logger.debug("Mod was next in queue and got removed")
    elseif tableUtils.contains(ModLoader.loading_queue, mod) then
      logger.debug("Mod is somewhere in the loading queue, adding to cancellationList")
      ModLoader.cancellationList[mod] = true
    else
      logger.debug("Mod is not in the process of being loaded")
      -- the mod is currently not even queued to be loaded so there should be no cancel
    end
  end
end

return ModLoader
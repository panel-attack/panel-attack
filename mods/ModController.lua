local tableUtils = require("tableUtils")
local ModLoader = require("mods.ModLoader")

-- the mod controller is a global accessor for loading mods
-- internally it keeps tabs on who uses which mod
-- that way it will also internally unload mods once they are no longer in use
local ModController = {
  -- the users table is keyed via an abstracted notion of who uses a mod
  -- each mod user can hold only onto a single mod per type (which can be a bundle)
  -- when mod users request a different mod the old one will get unloaded
  users = {
    --[[ 
    user = {
      character = modObject
      stage = modObject
    }
    ]]
  },

  loaded = {
    character = {
      --[[
      modId1 = { user1, user2 },
      modId2 = {}
      ]]
    },
    stage = {},
    theme = {}
  },
}

-- unloads the mod and any of its subMods that are not currently in use
local function unloadMod(modController, mod)
  ModLoader.cancelLoad(mod)
  mod:unload()
  local subMods = mod:getSubMods()
  if subMods then
    for _, subMod in ipairs(subMods) do
      local loadedForUsers = modController.loaded[mod.TYPE][subMod.id]
      if subMod.fully_loaded and (not loadedForUsers or #loadedForUsers == 0) then
        -- we need to crosscheck:
        -- if multiple players have picked different bundles that have an intersection in subMods,
        --  we don't want to unload the mod in use by both bundles just because one got unselected
        --  this is a bit ugly but the alternative would be to allow users to track more than one mod per type
        --  and that would be ugly in a different way
        if tableUtils.trueForAll(modController.users, function(user)
            local m = user[mod.TYPE]
            return m == mod or not tableUtils.contains(m:getSubMods(), function(sm) return sm.id == subMod.id end)
          end) then
          subMod:unload()
        end
      end
    end
  end
end

local function clearModForUser(modController, user, mod)
  if modController.users[user] and modController.users[user][mod.TYPE] then
    local previousMod = modController.users[user][mod.TYPE]
    if previousMod then
      local index = tableUtils.indexOf(modController.loaded[mod.TYPE][previousMod.id], user)
      table.remove(modController.loaded[mod.TYPE][previousMod.id], index)
      -- if no one else is still using the mod, unload it
      if #modController.loaded[mod.TYPE][previousMod.id] == 0 then
        unloadMod(modController, previousMod)
      end
    end
    modController.users[user][mod.TYPE] = nil
  end
end

local function registerModForUser(modController, user, mod)
  if not modController.users[user] then
    modController.users[user] = {}
  end
  modController.users[user][mod.TYPE] = mod
  local loadedForUsers
  if not modController.loaded[mod.TYPE][mod.id] then
    modController.loaded[mod.TYPE][mod.id] = {}
  end
  loadedForUsers = modController.loaded[mod.TYPE][mod.id]
  loadedForUsers[#loadedForUsers+1] = user
end

-- loads the mod for a string representation of a user
-- recommended values for user: "local" for the local player
--  , a running integer or public player id for players in a match
--  "match" for properties belonging to the match rather than player settings (usually only the stage)
-- that way the local config always stays loaded but remote mods unload the moment they are unselected
-- pass instantly = true to disregard responsiveness and finish loading all remaining mods on the same frame
function ModController:loadModFor(mod, user, instantly)
  if not self.users[user] or self.users[user][mod.TYPE] ~= mod then
    clearModForUser(self, user, mod)
    registerModForUser(self, user, mod)

    ModLoader.load(mod)
    if instantly then
      ModLoader.wait()
    end
  end
end

function ModController:update()
  ModLoader.update()
end

return ModController
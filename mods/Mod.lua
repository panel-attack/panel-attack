local class = require("class")

local Mod = class(function(mod, fullPath, folderName)
  mod.path = fullPath -- string | path to the mod folder content
  mod.fully_loaded = false

  -- every mod needs to be assigned an id
  mod.id = nil

  -- mods should declare what type of mod they are
  mod.TYPE = nil
end)

function Mod:json_init()
  error("All mods need to implement the function json_init()")
end

function Mod:load(instant)
  error("All mods need to implement a load function")
end

function Mod:unload()
  error("All mods need to implement an unload function")
end

function Mod:is_bundle()
  error("All mods need to implement an is_bundle function")
end

function Mod:getSubMods()
  if self:is_bundle() then
    error("All mods that support bundles need to implement a getSubMods function, even if it just returns nil")
  end
end

return Mod
local util = require("util")

local use_music_from_values = {stage = true, often_stage = true, either = true, often_characters = true, characters = true}
local save_replays_values = {["with my name"] = true, anonymously = true, ["not at all"] = true}

--@module config_metadata
local config_metadata = {
  isValid = {
    theme = function(value) return love.filesystem.getInfo("themes/" .. value .. "/config.json") end,
    use_music_from = function(value) return use_music_from_values[value] end,
    save_replays_publicly = function(value) return save_replays_values[value] end
  },
  processValue = {
    level = function(value) return util.bound(1, value, 10) end,
    endless_speed = function(value) return util.bound(1, value, 99) end,
    endless_difficulty = function(value) return util.bound(1, value, 3) end,
    master_volume = function(value) return util.bound(0, value, 100) end,
    SFX_volume = function(value) return util.bound(0, value, 100) end,
    music_volume = function(value) return util.bound(0, value, 100) end,
    input_repeat_delay = function(value) return util.bound(1, value, 50) end,
    portrait_darkness = function(value) return util.bound(1, value, 50) end,
    cardfx_scale = function(value) return util.bound(1, value, 200) end
  }
}

return config_metadata
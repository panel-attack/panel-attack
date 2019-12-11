require("queue")
require("globals")

local loading_queue = Queue()

local loading_character = nil

function character_loader_load(character_id)
  if characters[character_id] and not characters[character_id].fully_loaded then
    loading_queue:push(character_id)
  end
end

local instant_load_enabled = false

-- return true if there is still data to load
function character_loader_update()
  if not loading_character and loading_queue:len() > 0 then
    local character_name = loading_queue:pop()
    loading_character = { character_name, coroutine.create( function()
      characters[character_name]:load(instant_load_enabled)
    end) }
  end

  if loading_character then
    if coroutine.status(loading_character[2]) == "suspended" then
      coroutine.resume(loading_character[2])
      return true
    elseif coroutine.status(loading_character[2]) == "dead" then
      loading_character = nil
      return loading_queue:len() > 0
      -- TODO: unload characters if too much data have been loaded (be careful not to release currently-used characters)
    end
  end

  return false
end

function character_loader_wait()
  instant_load_enabled = true
  while true do
    if not character_loader_update() then
      break
    end
  end
  instant_load_enabled = false
end

function character_loader_clear()
  local p2_local_character = global_op_state and global_op_state.character or nil
  for character_id,character in pairs(characters) do
    if character.fully_loaded and character_id ~= config.character and character_id ~= p2_local_character then
      character:unload()
    end
  end
end
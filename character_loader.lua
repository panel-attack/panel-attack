require("queue")
require("globals")

local loading_queue = Queue()

local loading_character = nil

function character_loader_load(character_id)
  if not fully_loaded_characters[character_id] then
    loading_queue:push(character_id)
  end
end

-- return true if there is still data to load
function character_loader_update()
  if not loaded_character and loading_queue:len() > 0 then
    local character_name = loading_queue:pop()
    loading_character = { character_name, coroutine.create( function()
      characters[character_name]:load()
    end) }
  end

  if loading_character then
    if coroutine.status(loading_character[2]) == "suspended" then
      coroutine.resume(loading_character[2])
      return true
    elseif coroutine.status(loading_character[2]) == "dead" then
      fully_loaded_characters[loading_character[1]] = true
      loading_character = nil
      return loading_queue:len() > 0
      -- TODO: unload characters if too much data have been loaded (be careful not to release currently-used characters)
    end
  end

  return false
end

function character_loader_wait()
  while true do
    if not character_loader_update() then
      break
    end
  end
end
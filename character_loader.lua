require("queue")
require("globals")
require("character")
local logger = require("logger")

local loading_queue = Queue()

local loading_character = nil

characters = {} -- holds all characters, most of them will not be fully loaded
characters_ids = {} -- holds all characters ids
characters_ids_for_current_theme = {} -- holds characters ids for the current theme, those characters will appear in the lobby
characters_ids_by_display_names = {} -- holds keys to array of character ids holding that name

-- queues a character to be loaded
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
    loading_character = {
      character_name,
      coroutine.create(
        function()
          characters[character_name]:load(instant_load_enabled)
        end
      )
    }
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

-- Waits for all characters to be loaded
function character_loader_wait()
  instant_load_enabled = true
  while true do
    if not character_loader_update() then
      break
    end
  end
  instant_load_enabled = false
end

-- Unloads all characters not in use by config or player 2
function character_loader_clear()
  local p2_local_character = global_op_state and global_op_state.character or nil
  for character_id, character in pairs(characters) do
    if character.fully_loaded and character_id ~= config.character and character_id ~= p2_local_character then
      character:unload()
    end
  end
end

-- Adds all the characters recursively in a folder to the global characters variable
local function add_characters_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = FileUtil.getFilteredDirectoryItems(path)
  for i, v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v, 0, string.len(prefix_of_ignored_dirs))
    if start_of_v ~= prefix_of_ignored_dirs then
      local current_path = path .. "/" .. v
      if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
        -- call recursively: facade folder
        add_characters_from_dir_rec(current_path)

        -- init stage: 'real' folder
        local character = Character(current_path, v)
        local success = character:json_init()

        if success then
          if characters[character.id] ~= nil then
            logger.trace(current_path .. " has been ignored since a character with this id has already been found")
          else
            -- logger.trace(current_path.." has been added to the character list!")
            characters[character.id] = character
            characters_ids[#characters_ids + 1] = character.id
          end
        end
      end
    end
  end
end

-- Loads all character IDs into the characters_ids global
local function fill_characters_ids()
  -- check validity of bundle characters
  local invalid = {}
  local copy_of_characters_ids = shallowcpy(characters_ids)
  characters_ids = {} -- clean up
  for _, character_id in ipairs(copy_of_characters_ids) do
    local character = characters[character_id]
    if #character.sub_characters > 0 then -- bundle character (needs to be filtered if invalid)
      local copy_of_sub_characters = shallowcpy(character.sub_characters)
      character.sub_characters = {}
      for _, sub_character in ipairs(copy_of_sub_characters) do
        if characters[sub_character] and #characters[sub_character].sub_characters == 0 then -- inner bundles are prohibited
          character.sub_characters[#character.sub_characters + 1] = sub_character
          logger.trace(character.id .. " has " .. sub_character .. " as part of its subcharacters.")
        end
      end

      if #character.sub_characters < 2 then
        invalid[#invalid + 1] = character_id -- character is invalid
        logger.warn(character.id .. " (bundle) is being ignored since it's invalid!")
      else
        characters_ids[#characters_ids + 1] = character_id
        logger.debug(character.id .. " (bundle) has been added to the character list!")
      end
    else -- normal character
      characters_ids[#characters_ids + 1] = character_id
      logger.debug(character.id .. " has been added to the character list!")
    end
  end

  -- characters are removed outside of the loop since erasing while iterating isn't working
  for _, invalid_character in pairs(invalid) do
    characters[invalid_character] = nil
  end
end

-- Initializes the characters globals with data
function characters_init()
  add_characters_from_dir_rec("characters")
  fill_characters_ids()

  if #characters_ids == 0 then
    recursive_copy("default_data/characters", "characters")
    add_characters_from_dir_rec("characters")
    fill_characters_ids()
  end

  if love.filesystem.getInfo(Theme.themeDirectoryPath .. config.theme .. "/characters.txt") then
    for line in love.filesystem.lines(Theme.themeDirectoryPath .. config.theme .. "/characters.txt") do
      line = trim(line) -- remove whitespace
      if characters[line] then
        -- found at least a valid character in a characters.txt file
        characters_ids_for_current_theme[#characters_ids_for_current_theme + 1] = line
      end
    end
  else
    for _, character_id in ipairs(characters_ids) do
      if characters[character_id].is_visible then
        characters_ids_for_current_theme[#characters_ids_for_current_theme + 1] = character_id
      end
    end
  end

  -- all characters case
  if #characters_ids_for_current_theme == 0 then
    characters_ids_for_current_theme = shallowcpy(characters_ids)
  end

  -- fix config character if it's missing
  if not config.character or (config.character ~= random_character_special_value and not characters[config.character]) then
    config.character = table.getRandomElement(characters_ids_for_current_theme)
  end

  -- actual init for all characters, starting with the default one
  Character.loadDefaultCharacter()

  for _, character in pairs(characters) do
    character:preload()

    if characters_ids_by_display_names[character.display_name] then
      characters_ids_by_display_names[character.display_name][#characters_ids_by_display_names[character.display_name] + 1] = character.id
    else
      characters_ids_by_display_names[character.display_name] = {character.id}
    end
  end

  if config.character ~= random_character_special_value and not characters[config.character]:is_bundle() then
    character_loader_load(config.character)
    character_loader_wait()
  end
end
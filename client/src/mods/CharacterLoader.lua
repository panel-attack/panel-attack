local Character = require("client.src.mods.Character")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")

local CharacterLoader = {}

-- Adds all the characters recursively in a folder to the global characters variable
function CharacterLoader.addCharactersFromDirectoryRecursively(path)
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for _, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
      -- call recursively: facade folder
      CharacterLoader.addCharactersFromDirectoryRecursively(current_path)

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

-- Loads all character IDs into the characters_ids global
function CharacterLoader.fillCharactersIds()
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

-- (re)Initializes the characters globals with data
function CharacterLoader.initCharacters()
  characters = {} -- holds all characters, most of them will not be fully loaded
  characters_ids = {} -- holds all characters ids
  characters_ids_for_current_theme = {} -- holds characters ids for the current theme, those characters will appear in the lobby
  characters_ids_by_display_names = {} -- holds keys to array of character ids holding that name
  CharacterLoader.addCharactersFromDirectoryRecursively("characters")
  CharacterLoader.fillCharactersIds()

  if #characters_ids == 0 then
    fileUtils.recursiveCopy("client/assets/default_data/characters", "characters")
    CharacterLoader.addCharactersFromDirectoryRecursively("characters")
    CharacterLoader.fillCharactersIds()
  end

  if love.filesystem.getInfo(themes[config.theme].path .. "/characters.txt") then
    for line in love.filesystem.lines(themes[config.theme].path .. "/characters.txt") do
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
  if not config.character or (config.character ~= consts.RANDOM_CHARACTER_SPECIAL_VALUE and not characters[config.character]) then
    config.character = tableUtils.getRandomElement(characters_ids_for_current_theme)
  end

  -- actual init for all characters, starting with the default one
  Character.loadDefaultCharacter()
  -- add the random character as a character that acts as a bundle for all theme characters
  local randomCharacter = Character.getRandomCharacter()
  characters_ids[#characters_ids + 1] = randomCharacter.id
  characters[randomCharacter.id] = randomCharacter

  for _, character in pairs(characters) do
    character:preload()

    if characters_ids_by_display_names[character.display_name] then
      characters_ids_by_display_names[character.display_name][#characters_ids_by_display_names[character.display_name] + 1] = character.id
    else
      characters_ids_by_display_names[character.display_name] = {character.id}
    end
  end
end

function CharacterLoader.resolveCharacterSelection(characterId)
  if not characterId or not characters[characterId] then
    -- resolve via random selection
    characterId = tableUtils.getRandomElement(characters_ids_for_current_theme)
  end

  return characterId
end

function CharacterLoader.resolveBundle(characterId)
  while characters[characterId]:is_bundle() do
    characterId = tableUtils.getRandomElement(characters[characterId].sub_characters)
  end

  return characterId
end

function CharacterLoader.fullyResolveCharacterSelection(characterId)
  characterId = CharacterLoader.resolveCharacterSelection(characterId)
  return CharacterLoader.resolveBundle(characterId)
end

return CharacterLoader
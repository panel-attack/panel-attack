--[[ for readability purposes this file is structured in 3 parts:
General character informating, loading and unloading
Graphics
Sound
]]--
local logger = require("logger")

local default_character = nil -- holds default assets fallbacks

local chainStyle = {classic = 0, per_chain = 1}
local comboStyle = {classic = 0, per_combo = 1}

Character =
  class(
  function(self, full_path, folder_name)
    self.path = full_path -- string | path to the character folder content
    self.id = folder_name -- string | id of the character, specified in config.json
    self.display_name = self.id -- string | display name of the stage
    self.stage = nil -- string | stage that get selected upon doing the super selection of that character
    self.panels = nil -- string | panels that get selected upon doing the super selection of that character
    self.sub_characters = {} -- stringS | either empty or with two elements at least; holds the sub characters IDs for bundle characters
    self.images = {}
    self.sounds = {}
    self.musics = {}
    self.flag = nil -- string | flag to be displayed in the select screen
    self.fully_loaded = false
    self.is_visible = true
    self.chain_style = chainStyle.classic
    self.combo_style = comboStyle.classic
    self.popfx_style = "burst"
    self.popfx_burstRotate = false
    self.popfx_burstScale = 1
    self.popfx_fadeScale = 1
    self.music_style = "normal"
    self.files = table.map(love.filesystem.getDirectoryItems(self.path), function(file) return FileUtil.getFileNameWithoutExtension(file) end)
  end
)

function Character.json_init(self)
  local read_data = {}
  local config_file, err = love.filesystem.newFile(self.path .. "/config.json", "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    config_file:close()
    for k, v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end

  if read_data.id and type(read_data.id) == "string" then
    self.id = read_data.id

    -- sub ids for bundles
    if read_data.sub_ids and type(read_data.sub_ids) == "table" then
      self.sub_characters = read_data.sub_ids
    end
    -- display name
    if read_data.name and type(read_data.name) == "string" then
      self.display_name = read_data.name
    end
    -- is visible
    if read_data.visible ~= nil and type(read_data.visible) == "boolean" then
      self.is_visible = read_data.visible
    elseif read_data.visible and type(read_data.visible) == "string" then
      self.is_visible = read_data.visible == "true"
    end

    -- chain_style
    if read_data.chain_style and type(read_data.chain_style) == "string" then
      self.chain_style = read_data.chain_style == "per_chain" and chainStyle.per_chain or chainStyle.classic
    end

    -- combo_style
    if read_data.combo_style and type(read_data.combo_style) == "string" then
      self.combo_style = read_data.combo_style == "per_combo" and comboStyle.per_combo or comboStyle.classic
    end

    --popfx_burstRotate
    if read_data.popfx_burstRotate and type(read_data.popfx_burstRotate) == "boolean" then
      self.popfx_burstRrotate = read_data.popfx_burstRotate
    end

    --popfx_type
    if read_data.popfx_style and type(read_data.popfx_style) == "string" then
      self.popfx_style = read_data.popfx_style
    end

    --popfx_burstScale
    if read_data.popfx_burstScale and type(read_data.popfx_burstScale) == "number" then
      self.popfx_burstScale = read_data.popfx_burstScale
    end

    --popfx_fadeScale
    if read_data.popfx_fadeScale and type(read_data.popfx_fadeScale) == "number" then
      self.popfx_fadeScale = read_data.popfx_fadeScale
    end

    --music style
    if read_data.music_style and type(read_data.music_style) == "string" then
      self.music_style = read_data.music_style
    end

    -- associated stage
    if read_data.stage and type(read_data.stage) == "string" and stages[read_data.stage] and not stages[read_data.stage]:is_bundle() then
      self.stage = read_data.stage
    end
    -- associated panel
    if read_data.panels and type(read_data.panels) == "string" and panels[read_data.panels] then
      self.panels = read_data.panels
    end

    -- flag
    if read_data.flag and type(read_data.flag) == "string" then
      self.flag = read_data.flag
    end

    return true
  end

  return false
end

function Character.preload(self)
  logger.trace("preloading character " .. self.id)
  self:graphics_init(false, false)
  self:sound_init(false, false)
end

-- Loads all the sounds and graphics
function Character.load(self, instant)
  logger.trace("loading character " .. self.id)
  self:graphics_init(true, (not instant))
  self:sound_init(true, (not instant))
  self.fully_loaded = true
  logger.trace("loaded character " .. self.id)
end

-- Unloads the sounds and graphics
function Character.unload(self)
  logger.trace("unloading character " .. self.id)
  self:graphics_uninit()
  self:sound_uninit()
  self.fully_loaded = false
  logger.trace("unloaded character " .. self.id)
end

function Character.loadDefaultCharacter()
  default_character = Character("characters/__default", "__default")
  default_character:preload()
  default_character:load(true)
end

function Character.is_bundle(self)
  return #self.sub_characters > 1
end


-- GRAPHICS

local basic_images = {"icon"}
local other_images = {
  "topleft",
  "botleft",
  "topright",
  "botright",
  "top",
  "bot",
  "left",
  "right",
  "face",
  "face2",
  "pop",
  "doubleface",
  "filler1",
  "filler2",
  "flash",
  "portrait",
  "portrait2",
  "burst",
  "fade"
}
local defaulted_images = {
  icon = true,
  topleft = true,
  botleft = true,
  topright = true,
  botright = true,
  top = true,
  bot = true,
  left = true,
  right = true,
  face = true,
  -- used for garbage blocks of odd-numbered widths if available, face otherwise
  face2 = false,
  pop = true,
  doubleface = true,
  filler1 = true,
  filler2 = true,
  flash = true,
  portrait = true,
  portrait2 = false,
  burst = true,
  fade = true
} -- those images will be defaulted if missing

-- for reloading the graphics if the window was resized
function characters_reload_graphics()
  local characterIds = shallowcpy(characters_ids_for_current_theme)
  for i = 1, #characterIds do
    local character = characterIds[i]
    local fullLoad = false
    if character == config.character or (P1 and character == P1.character) or (P2 and character == P2.character) then
      fullLoad = true
    end
    characters[character]:graphics_init(fullLoad, false)
  end
end

function Character.graphics_init(self, full, yields)
  local character_images = full and other_images or basic_images
  for _, image_name in ipairs(character_images) do
    self.images[image_name] = GraphicsUtil.loadImageFromSupportedExtensions(self.path .. "/" .. image_name)
    if not self.images[image_name] and defaulted_images[image_name] and not self:is_bundle() then
      if image_name == "burst" or image_name == "fade" then
        self.images[image_name] = themes[config.theme].images[image_name]
      else
        self.images[image_name] = default_character.images[image_name]
        if not self.images[image_name] then
          error("Could not find default character image")
        end
      end
    end
    if yields then
      coroutine.yield()
    end
  end
  if full then
    self.telegraph_garbage_images = {}
    for garbage_h=1,14 do
      self.telegraph_garbage_images[garbage_h] = {}
      logger.debug("telegraph/"..garbage_h.."-tall")
      self.telegraph_garbage_images[garbage_h][6] = GraphicsUtil.loadImageFromSupportedExtensions(self.path.."/telegraph/"..garbage_h.."-tall")
      if not self.telegraph_garbage_images[garbage_h][6] and default_character.telegraph_garbage_images[garbage_h][6] then
        self.telegraph_garbage_images[garbage_h][6] = default_character.telegraph_garbage_images[garbage_h][6]
        logger.debug("DEFAULT used for telegraph/"..garbage_h.."-tall")
      elseif not self.telegraph_garbage_images[garbage_h][6] then
        logger.debug("FAILED TO LOAD: telegraph/"..garbage_h.."-tall")
      end
    end
    for garbage_w=1,6 do
      logger.debug("telegraph/"..garbage_w.."-wide")
      self.telegraph_garbage_images[1][garbage_w] = GraphicsUtil.loadImageFromSupportedExtensions(self.path.."/telegraph/"..garbage_w.."-wide")
      if not self.telegraph_garbage_images[1][garbage_w] and default_character.telegraph_garbage_images[1][garbage_w] then
        self.telegraph_garbage_images[1][garbage_w] = default_character.telegraph_garbage_images[1][garbage_w]
        logger.debug("DEFAULT used for telegraph/"..garbage_w.."-wide")
      elseif not self.telegraph_garbage_images[1][garbage_w] then
        logger.debug("FAILED TO LOAD: telegraph/"..garbage_w.."-wide")
      end
    end
    logger.debug("telegraph/6-wide-metal")
    self.telegraph_garbage_images["metal"] = GraphicsUtil.loadImageFromSupportedExtensions(self.path.."/telegraph/6-wide-metal")
    if not self.telegraph_garbage_images["metal"] and default_character.telegraph_garbage_images["metal"] then
      self.telegraph_garbage_images["metal"] = default_character.telegraph_garbage_images["metal"]
      logger.debug("DEFAULT used for telegraph/6-wide-metal")
    elseif not self.telegraph_garbage_images["metal"] then
      logger.debug("FAILED TO LOAD: telegraph/6-wide-metal")
    end
    logger.debug("telegraph/attack")
    self.telegraph_garbage_images["attack"] = GraphicsUtil.loadImageFromSupportedExtensions(self.path.."/telegraph/attack")
    if not self.telegraph_garbage_images["attack"] and default_character.telegraph_garbage_images["attack"] then
      self.telegraph_garbage_images["attack"] = default_character.telegraph_garbage_images["attack"]
      logger.debug("DEFAULT used for telegraph/attack")
    elseif not self.telegraph_garbage_images["attack"] then
      logger.debug("FAILED TO LOAD: telegraph/attack")
    end
  end
end

function Character.graphics_uninit(self)
  for _, image_name in ipairs(other_images) do
    self.images[image_name] = nil
  end
  self.telegraph_garbage_images = {}
end



-- SOUND

local basic_sfx = {"selection"}
local other_sfx = {
  "chain",
  "combo",
  -- legacy +6/+7 shock, to be used if shock is not present
  "combo_echo",
  "shock",
  -- for classic style chains
  "chain_echo",
  "chain2_echo",

  "garbage_match",
  "garbage_land",
  "win",
  "taunt_up",
  "taunt_down"}
local basic_musics = {}
local other_musics = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}
local defaulted_musics = {} -- those musics will be defaulted if missing

function Character.sound_init(self, full, yields)
  -- SFX
  local character_sfx = full and other_sfx or basic_sfx
  for _, sfx in ipairs(character_sfx) do
    self.sounds[sfx] = self:loadSfx(sfx, yields)
  end

  -- music
  local character_musics = full and other_musics or basic_musics
  for _, music in ipairs(character_musics) do
    self.musics[music] = load_sound_from_supported_extensions(self.path .. "/" .. music, true)
    -- Set looping status for music.
    -- Intros won't loop, but other parts should.
    if self.musics[music] then
      if not string.find(music, "start") then
        self.musics[music]:setLooping(true)
      else
        self.musics[music]:setLooping(false)
      end
    elseif not self.musics[music] and defaulted_musics[music] and not self:is_bundle() then
      self.musics[music] = default_character.musics[music] or zero_sound
    end

    if yields then
      coroutine.yield()
    end
  end

  self:apply_config_volume()
end

function Character.sound_uninit(self)
  -- SFX
  for _, sound in ipairs(other_sfx) do
    self.sounds[sound] = nil
  end

  -- music
  for _, music in ipairs(other_musics) do
    self.musics[music] = nil
  end
end

--[[
Explanation for sound loading process

Standard expected structure for sound files is as follows:
self.sounds holds a dictionary with the keys in basic_sfx and other_sfx
The values of that dictionary are tables that contain integer numbered sfx, e.g.
self.sounds["combo"] = {}
For some sfx types, sfx can possibly contain sub sfx. That is selected via randomization upon being played.
For that reason each index in that table holds another table with possible sounds for that selection value:
self.sounds["combo"][4] = { standardsfx, alternativesfx, alternativesfx2}
self.sounds["combo"][5] = { standardsfx}
For most sounds that aren't divided by size one level is omitted and they don't load the variations as subSfx:
self.sounds["win"] = { win, win2, win3}
The level of sound loading is determined via "mayHaveSubSfx"
]]--

local perSizeSfxStart = { chain = 2, combo = 4, shock = 3}

function Character.loadSfx(self, name, yields)
  local sfx = {}

  local stringLen = string.len(name)
  local files = table.filter(self.files, function(file) return string.find(file, name, nil, true) end)

  local maxIndex = 0
  -- load sounds
  for i = 1, #files do
    stringLen = string.len(name)
    local index = tonumber(string.match(files[i], "%d+", stringLen + 1))
    if index == nil then
      -- indicates that there is no index, implicit 1
      index = 1
    end

    if perSizeSfxStart[name] then
      if sfx[index] == nil then
        sfx[index] = self:loadSubSfx(name, index)
      end
    else
      local sound = load_sound_from_supported_extensions(self.path .. "/" .. files[i], false)
      if sound ~= nil then
        sfx[index] = sound
      end

      if yields then
        coroutine.yield()
      end
    end

    if sfx[index] then
      maxIndex = math.max(maxIndex, index)
    end
  end

  if perSizeSfxStart[name] then
    self:fillInMissingSounds(sfx, name, maxIndex)
  end

  return sfx
end

-- loads all variations for the sfx with the base name sfxName and returns them in a continuous integer key'd table
function Character.loadSubSfx(self, name, index, yields)
  local sfxTable = {}

  if index == 1 then
    -- index 1 is implicit, e.g. chain, chain_2, chain2, chain2_2
    -- so change it to an empty string so it isn't counted towards string length when searching variations
    index = ""
  end
  local stringLen = string.len(name..index)
  local subfiles = table.filter(self.files,
                    function(file)
                      return file == name..index or
                            (string.find(file, name .. index) and
                            -- exclude chain22 while searching for chain2
                            tonumber(string.sub(file, stringLen + 1, stringLen + 1)) == nil and
                            -- exclude combo_echo / chain_echo, only take comboN_M/chainN_M
                            tonumber(string.sub(file, stringLen + 2, stringLen + 2)) ~= nil)
                    end)

  if #subfiles > 0 then
    for j = 1, #subfiles do
      local subSound = load_sound_from_supported_extensions(self.path .. "/" .. subfiles[j], false)
      if subSound ~= nil then
        sfxTable[#sfxTable+1] = subSound
      end
      if yields then
        coroutine.yield()
      end
    end
  end

  if #sfxTable > 0 then
    return sfxTable
  else
    return nil
  end
end

function Character.fillInMissingSounds(self, sfxTable,  name, maxIndex)
  local fillUpSound = nil
  if maxIndex > 0 then
    -- fallback sound for combos/chains higher than the highest available file is the file with the maximum index
    -- unless set differently (such as for chains via the chain0 file)
    sfxTable[0] = sfxTable[maxIndex]
  end
  -- fill up missing indexes up to the highest recorded one
  for i = 0, maxIndex do
    if sfxTable and sfxTable[i] then
      fillUpSound = sfxTable[i]
    else
      if i >= perSizeSfxStart[name] then
        sfxTable[i] = fillUpSound
      else
        sfxTable[i] = {}
      end
    end
  end

  if sfxTable[0] == nil then
    if default_character.sounds[name] and default_character.sounds[name][0] then
      sfxTable[0] = default_character.sounds[name][0]
    end
  else
    -- shock falls back to combo if nil
    -- combo falls back to chain if nil
    -- chain is bundled with the default character and should never be nil
  end
end

-- sound playing / sound control

function Character.play_selection_sfx(self)
  if not GAME.muteSoundEffects and #self.sounds.selection ~= 0 then
    self.sounds.selection[math.random(#self.sounds.selection)]:play()
    return true
  end
  return false
end

local function defaultChainPlayback(character)
  character.sounds.chain[0][math.random(#character.sounds.chain[0])]:play()
end

function Character.playComboSfx(self, size)
  -- self.sounds.combo[0] is the fallback combo sound which is guaranteed to be set if there is a combo sfx
  if self.sounds.combo[0] == nil then
    -- no combos loaded, try to fallback to the fallback chain sound
    if self.sounds.chain[0] == nil then
      -- technically we should always have a default chain sound from the default_character
      -- so if this error ever occurs, something is seriously cursed
      error("Found neither chain nor combo sfx upon trying to play combo sfx")
    else
      defaultChainPlayback(self)
    end
  else
    -- combo sfx available!
    if self.combo_style == comboStyle.classic then
      -- roll among all combos in case a per_combo style character had its combostyle changed to classic
      local rolledIndex = math.random(#self.sounds.combo)
      self.sounds.combo[rolledIndex][math.random(#self.sounds.combo[rolledIndex])]:play()
    else
      if self.sounds.combo[size] then
        self.sounds.combo[size][math.random(#self.sounds.combo[size])]:play()
      else
        -- use fallback sound if the combo size is higher than the highest combo sfx
        self.sounds.combo[0][math.random(#self.sounds.combo[0])]:play()
      end
    end
  end
end

function Character.playChainSfx(self, length)
  if self.chain_style == chainStyle.classic then
    if length < 4 then
      -- chain needs special indexing as it shares its table with per_chain style chain sfx
      if self.sounds.chain[1] then
        self.sounds.chain[1][math.random(#self.sounds.chain[1])]:play()
      else
        defaultChainPlayback(self)
      end
    elseif length == 4 then
      -- chain needs special indexing as it shares its table with per_chain style chain sfx
      if self.sounds.chain[2] then
        self.sounds.chain[2][math.random(#self.sounds.chain[2])]:play()
      else
        defaultChainPlayback(self)
      end
    elseif length == 5 then
      if #self.sounds.chain_echo > 0 then
        self.sounds.chain_echo[math.random(#self.sounds.chain_echo)]:play()
      else
        -- fallback to chain instead of its own fallback
        defaultChainPlayback(self)
      end
    elseif length >= 6 then
      if #self.sounds.chain2_echo > 0 then
        self.sounds.chain2_echo[math.random(#self.sounds.chain2_echo)]:play()
      else
        -- fallback to chain instead of its own fallback
        defaultChainPlayback(self)
      end
    end
  else --elseif self.chain_style == chainStyle.per_chain then
    length = math.max(length, 2)
    if self.sounds.chain[length] then
      self.sounds.chain[length][math.random(#self.sounds.chain[length])]:play()
    else
      defaultChainPlayback(self)
    end
  end
end

function Character.playShockSfx(self, size)
  if #self.sounds.shock > 0 then
    if self.sounds.shock[size] then
      self.sounds.shock[size][math.random(#self.sounds.shock[size])]:play()
    else
      self.sounds.shock[0][math.random(#self.sounds.shock[0])]:play()
    end
  else
    if size >= 6 and #self.sounds.combo_echo > 0 then
      self.sounds.combo_echo[math.random(#self.sounds.combo_echo)]:play()
    else
      self:playComboSfx(size)
    end
  end
end

-- Stops old combo / chaing sounds and plays the appropriate chain or combo sound
function Character.playAttackSfx(self, attack)
  local function stopPreviousSounds()
    local function stopIfPlaying(audioSource)
      if audioSource:isPlaying() then
        audioSource:stop()
      end
    end
    -- stop previous sounds if any
    for _, sfxForIndex in pairs(self.sounds.combo) do
      for _, sound in pairs(sfxForIndex) do
        stopIfPlaying(sound)
      end
    end
    for _, sound in pairs(self.sounds.combo_echo) do
      stopIfPlaying(sound)
    end
    for _, sfxForIndex in pairs(self.sounds.shock) do
      for _, sound in pairs(sfxForIndex) do
        stopIfPlaying(sound)
      end
    end
    for _, sfxForIndex in pairs(self.sounds.chain) do
      for _, sound in pairs(sfxForIndex) do
        stopIfPlaying(sound)
      end
    end
    if self.chain_style == chainStyle.classic then
      for _, sound in pairs(self.sounds.chain_echo) do
        stopIfPlaying(sound)
      end
      for _, sound in pairs(self.sounds.chain2_echo) do
        stopIfPlaying(sound)
      end
    end
  end

  if not GAME.muteSoundEffects then
    stopPreviousSounds()

    -- play combos or chains
    if attack.type == e_chain_or_combo.combo then
      self:playComboSfx(attack.size)
    elseif attack.type == e_chain_or_combo.shock then
      self:playShockSfx(attack.size)
    else --elseif chain_combo.type == e_chain_or_combo.chain then
      self:playChainSfx(attack.size)
    end
  end
end

function Character.playGarbageMatchSfx(self)
  for _, v in pairs(self.sounds.garbage_match) do
    v:stop()
  end
  if #self.sounds.garbage_match ~= 0 then
    self.sounds.garbage_match[math.random(#self.sounds.garbage_match)]:play()
  end
end

function Character.playGarbageLandSfx(self)
  if #self.sounds.garbage_land ~= 0 then
    for _, v in pairs(self.sounds.garbage_land) do
      v:stop()
    end
    self.sounds.garbage_land[math.random(#self.sounds.garbage_land)]:play()
  end
end

-- tauntUp is rolled by the stack in order to send the exact same taunt index to the enemy as plays locally
function Character.playTauntUpSfx(self, tauntUp)
  for _, t in ipairs(self.sounds.taunt_up) do
    t:stop()
  end
  if self.sounds.taunt_up[tauntUp] then
    self.sounds.taunt_up[tauntUp]:play()
  else
    self.sounds.taunt_up[math.random(#self.sounds.taunt_up)]:play()
  end
end

-- tauntDown is rolled by the stack in order to send the exact same taunt index to the enemy as plays locally
function Character.playTauntDownSfx(self, tauntDown)
  for _, t in ipairs(self.sounds.taunt_down) do
    t:stop()
  end
  if self.sounds.taunt_down[tauntDown] then
    self.sounds.taunt_down[tauntDown]:play()
  else
    self.sounds.taunt_down[math.random(#self.sounds.taunt_down)]:play()
  end
end

function Character.apply_config_volume(self)
  set_volume(self.sounds, config.SFX_volume / 100)
  set_volume(self.musics, config.music_volume / 100)
end
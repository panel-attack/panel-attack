require("util")

-- The class that holds all input mappings and state
-- TODO: move all state variables in here
Input =
  class(
  function(self)
    self.inputConfigurations = {} -- a table of all valid input configurations, each configuration is a map of input type to the mapped key
    self.maxConfigurations = 8
    for i = 1, self.maxConfigurations do
      self.inputConfigurations[#self.inputConfigurations+1] = {}
    end
    self.inputConfigurations[1] = {up="up", down="down", left="left", right="right", swap1="z", swap2="x", taunt_up="y", taunt_down="u", raise1="c", raise2="v", pause="p"}
    self.playerInputConfigurationsMap = {} -- playerNumber -> table of all inputConfigurations assigned to that player
    self.acceptingPlayerInputConfigurationAssignments = false -- If true the next inputs that come in will assign to the next player that doesn't have assignments
    self.availableInputConfigurationsToAssign = nil -- the list of available input configurations to assign, only valid while acceptingPlayerInputConfigurationAssignments is set
    self.numberOfPlayersAcceptingInputConfiguration = 0 -- the number of players we want assigned input configurations, only valid while acceptingPlayerInputConfigurationAssignments is set
  end
)

local input = Input()

local jpexists, jpname, jrname
for k, v in pairs(love.handlers) do
  if k == "jp" then
    jpexists = true
  end
end
if jpexists then
  jpname = "jp"
  jrname = "jr"
else
  jpname = "joystickpressed"
  jrname = "joystickreleased"
end
local __old_jp_handler = love.handlers[jpname]
local __old_jr_handler = love.handlers[jrname]
love.handlers[jpname] = function(a, b)
  __old_jp_handler(a, b)
  local joystickID = input:getJoystickGUID(a)
  if joystickID then
    love.keypressed(joystickID .. "-" .. b)
  end
end
love.handlers[jrname] = function(a, b)
  __old_jr_handler(a, b)
  local joystickID = input:getJoystickGUID(a)
  if joystickID then
    love.keyreleased(joystickID .. "-" .. b)
  end
end

local prev_ax = {}
local axis_to_button = function(idx, axis, value)
  local axisName = idx .. "-axis" .. axis
  local prev = prev_ax[axisName] or 0
  prev_ax[axisName] = value
  if value <= .5 and not (prev <= .5) then
    love.keyreleased(axisName .. "+")
  end
  if value >= -.5 and not (prev >= -.5) then
    love.keyreleased(axisName .. "-")
  end
  if value > .5 and not (prev > .5) then
    love.keypressed(axisName .. "+")
  end
  if value < -.5 and not (prev < -.5) then
    love.keypressed(axisName .. "-")
  end
end

local prev_hat = {{}, {}}
local hat_to_button = function(idx, hatIndex, value)

  local hatName = idx .. "-hat" .. hatIndex .. "-"

  if string.len(value) == 1 then
    if value == "l" or value == "r" then
      value = value .. "c"
    else
      value = "c" .. value
    end
  end
  value = procat(value)
  for i = 1, 2 do
    local prev = prev_hat[i][hatName] or "c"
    if value[i] ~= prev and value[i] ~= "c" then
      love.keypressed(hatName .. value[i])
    end
    if prev ~= value[i] and prev ~= "c" then
      love.keyreleased(hatName .. prev)
    end
    prev_hat[i][hatName] = value[i]
  end
end


--[[
  -- Current System
  K[player] -> map of key names to current button configured
  keys[] map of raw key value to if it was pressed and not released yet
  keys[k.pause] 
  this_frame_keys[] same as keys but cleared at end of frame regardless of release

  -- New System
  1. Allow multiple configs per player that can change
  Set current configs active for each player
  Just loop through an array of mappings instead of just one

  keyMaps[player] -> K[1-n]

  allConfigs[1-n] -> guid -> keyboard or controller GUID mapped to K
  availableConfigs same but unused

  controller 1 -> GUID
  controller 2 of same -> GUID2

  on input, if first of controller -> GUID
else GUID2

  2. Make joystick buttons stable
  On configure record joystick GUID and connected index
  save both into key file

  When connected use first index thats unused

]]

function Input.cleanNameForButton(self, buttonString)

  if not buttonString then
    return buttonString
  end

  local result = nil

  --local searchString = "^(%w+%-)"
  --result = string.gsub(buttonString, searchString, "Controller ")

  for index, joystick in ipairs(love.joystick.getJoysticks()) do
    local joystickID = self:getJoystickGUID(joystick)
    if joystickID then
      local joystickConnectedIndex = joystick:getID()
      local resultString, count = string.gsub(buttonString, "^(" .. joystickID .. "%-)(.*)$", "Controller " .. joystickConnectedIndex .. " %2")
      if count > 0 then
        result = resultString
        break
      end
    end
  end

  if not result then
    -- Match any number of letters, numbers, and # followed by a dash and replace with "Unplogged Controller"
    local resultString, count = string.gsub(buttonString, "^([%w%d%#]+%-)(.*)$", "Unplugged Controller %2")
    if count > 0 then
      result = resultString
    else
      result = buttonString
    end
  end

  return result
end


function Input.getJoystickGUID(self, joystick)
  if not joystick then
    error("Expected to be passed in joystick")
  end

  local connectedIndex = joystick:getID()
  local searchGUID = joystick:getGUID()
  local numberOfMatchingJoysticks = 0
  local isFirst = true
  local joysticks = love.joystick.getJoysticks()
  for k, v in ipairs(joysticks) do
    if v:getGUID() == searchGUID then
      numberOfMatchingJoysticks = numberOfMatchingJoysticks + 1
      if connectedIndex == v:getID() then
        if numberOfMatchingJoysticks == 1 then
          return searchGUID
        else
          return searchGUID .. "#" .. numberOfMatchingJoysticks
        end
      end
    end
  end
  return nil
end

function love.joystick.getHats(joystick)
  local n = joystick:getHatCount()
  local ret = {}
  for i = 1, n do
    ret[i] = joystick:getHat(i)
  end
  return unpack(ret)
end

function joystick_ax()
  local joysticks = love.joystick.getJoysticks()
  for k, v in ipairs(joysticks) do
    local joystickID = input:getJoystickGUID(v)
    if joystickID then
      local axes = {v:getAxes()}
      for idx, value in ipairs(axes) do
        axis_to_button(joystickID, idx, value)
      end

      local hats = {love.joystick.getHats(v)}
      for idx, value in ipairs(hats) do
        hat_to_button(joystickID, idx, value)
      end
    end
  end
end

function love.keypressed(key, scancode, rep)
  if key == "return" and not rep and love.keyboard.isDown("lalt") then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    return
  end
  if not rep then
    keys[key] = 0
  end
  this_frame_keys[key] = true

  if input.acceptingPlayerInputConfigurationAssignments then
    for index, inputConfiguration in ipairs(input.availableInputConfigurationsToAssign) do
      for rawKey, keyName in pairs(inputConfiguration) do
        if keyName == key then
          input.playerInputConfigurationsMap[#input.playerInputConfigurationsMap+1] = {inputConfiguration}
          table.remove(input.availableInputConfigurationsToAssign, index)
          goto done
        end
      end
    end

    ::done::

    if #input.playerInputConfigurationsMap >= input.numberOfPlayersAcceptingInputConfiguration then
      input.acceptingPlayerInputConfigurationAssignments = false
    end
  end
end

function love.textinput(text)
  this_frame_unicodes[#this_frame_unicodes + 1] = text
end

function love.keyreleased(key, unicode)
  this_frame_released_keys[key] = keys[key] -- retains state in this_frame_released_keys
  keys[key] = nil
end

function key_counts()
  for key, value in pairs(keys) do
    keys[key] = value + 1
  end
end

-- Keys that have a fixed function in menus can be bound to other
-- meanings, but should continue working the same way in menus.
local menu_reserved_keys = {}

function repeating_key(key)
  local key_time = keys[key]
  return this_frame_keys[key] or (key_time and key_time > default_input_repeat_delay and key_time % 2 == 0) -- menues key repeat delay 20 frames then every 2 frames
end

local function key_is_down(key)
  return keys[key] or this_frame_keys[key]
end

local function normal_key(key)
  return this_frame_keys[key]
end

local function released_key_before_time(key, time)
  return this_frame_released_keys[key] and this_frame_released_keys[key] < time
end

local function released_key_after_time(key, time)
  return this_frame_released_keys[key] and this_frame_released_keys[key] >= time
end

function Input.clearInputConfigurationsForPlayers(self)
  self.playerInputConfigurationsMap = {}
  self.acceptingPlayerInputConfigurationAssignments = false
  self.availableInputConfigurationsToAssign = nil
end

function Input.requestPlayerInputConfigurationAssignments(self, numberOfPlayers)
  if numberOfPlayers == 1 then
    self.playerInputConfigurationsMap[1] = self.inputConfigurations
  else
    if #input.playerInputConfigurationsMap < numberOfPlayers then
      self.acceptingPlayerInputConfigurationAssignments = true
      self.availableInputConfigurationsToAssign = deepcpy(self.inputConfigurations)
      self.numberOfPlayersAcceptingInputConfiguration = numberOfPlayers
    end
  end
end

function Input.playerNumberWaitingForInputConfiguration(self)
  if not input.acceptingPlayerInputConfigurationAssignments then
    return nil
  end

  if #input.playerInputConfigurationsMap < input.numberOfPlayersAcceptingInputConfiguration then
    return #input.playerInputConfigurationsMap + 1
  end

  return nil
end

function Input.getInputConfigurationsForPlayerNumber(self, playerNumber)

  local results = {}

  if not playerNumber then
    results = self.inputConfigurations
  elseif self.playerInputConfigurationsMap[playerNumber] then
    results = self.playerInputConfigurationsMap[playerNumber]
  end

  return results
end

-- Makes a function that will return true if one of the fixed keys or configurable keys was pressed for the passed in player.
-- Also returns the sound effect callback function
-- fixed -- the set of key names that always work
-- configurable -- the set of keys that work if the user has configured them
-- query -- the function that tests if the key was pressed usually normal key or repeating_key
-- sound -- the sound to play or nil
-- ... -- other args to pass to the returned function
local function input_key_func(fixed, configurable, query, sound, ...)
  sound = sound or nil
  local other_args = ...

  -- playerNumber -- the player number or nil if you want all inputs to work.
  -- silent -- set to true if you don't want the sound effect
  return function(playerNumber, silent)
    
    silent = silent or false
    local res = false

    if not playerNumber then
      for i = 1, #fixed do
        res = res or query(fixed[i], other_args)
      end
    end

    for i = 1, #configurable do
      for index, inputConfiguration in ipairs(input:getInputConfigurationsForPlayerNumber(playerNumber)) do
        local keyname = inputConfiguration[configurable[i]]
        if keyname then
          res = res or query(keyname, other_args) and not menu_reserved_keys[keyname]
        end
      end
    end

    local sfx_callback = function()
      if sound ~= nil then
        play_optional_sfx(sound())
      end
    end
    if res and not silent then
      sfx_callback()
    end
    return res, sfx_callback
  end
end

local function get_pressed_ratio(key, time)
  return keys[key] and keys[key] / time or (this_frame_released_keys[key] and this_frame_released_keys[key] / time or 0)
end

local function get_being_pressed_for_duration_ratio(fixed, configurable, time)
  return function(playerNumber)
    local res = 0
    for i = 1, #fixed do
      res = math.max(get_pressed_ratio(fixed[i], time), res)
    end
    for i = 1, #configurable do
      for _, inputConfiguration in ipairs(input:getInputConfigurationsForPlayerNumber(playerNumber)) do
        local keyname = inputConfiguration[configurable[i]]
        if not menu_reserved_keys[keyname] then
          res = math.max(get_pressed_ratio(keyname, time), res)
        end
      end
    end
    return bound(0, res, 1)
  end
end

menu_reserved_keys = {"up", "down", "left", "right", "escape", "x", "pageup", "pagedown", "backspace", "return", "kenter", "z"}
menu_up =
  input_key_func(
  {"up"},
  {"up"},
  repeating_key,
  function()
    return themes[config.theme].sounds.menu_move
  end
)
menu_down =
  input_key_func(
  {"down"},
  {"down"},
  repeating_key,
  function()
    return themes[config.theme].sounds.menu_move
  end
)
menu_left =
  input_key_func(
  {"left"},
  {"left"},
  repeating_key,
  function()
    return themes[config.theme].sounds.menu_move
  end
)
menu_right =
  input_key_func(
  {"right"},
  {"right"},
  repeating_key,
  function()
    return themes[config.theme].sounds.menu_move
  end
)
menu_escape =
  input_key_func(
  {"escape", "x"},
  {"swap2"},
  normal_key,
  function()
    return themes[config.theme].sounds.menu_cancel
  end
)
menu_prev_page =
  input_key_func(
  {"pageup"},
  {"raise1"},
  repeating_key,
  function()
    return themes[config.theme].sounds.menu_move
  end
)
menu_next_page =
  input_key_func(
  {"pagedown"},
  {"raise2"},
  repeating_key,
  function()
    return themes[config.theme].sounds.menu_move
  end
)
menu_backspace = input_key_func({"backspace"}, {"backspace"}, repeating_key)
menu_long_enter =
  input_key_func(
  {"return", "kenter", "z"},
  {"swap1"},
  released_key_after_time,
  function()
    return themes[config.theme].sounds.menu_validate
  end,
  super_selection_duration
)
menu_enter =
  input_key_func(
  {"return", "kenter", "z"},
  {"swap1"},
  released_key_before_time,
  function()
    return themes[config.theme].sounds.menu_validate
  end,
  super_selection_duration
)
menu_enter_one_press =
  input_key_func(
  {"return", "kenter", "z"},
  {"swap1"},
  normal_key,
  function()
    return themes[config.theme].sounds.menu_validate
  end,
  super_selection_duration
)
menu_pause =
  input_key_func(
  {"return", "kenter"},
  {"pause"},
  normal_key,
  function()
    return themes[config.theme].sounds.menu_validate
  end
)

player_reset =
  input_key_func(
  {},
  {"taunt_down", "taunt_up"},
  normal_key,
  function()
    return themes[config.theme].sounds.menu_cancel
  end
)

player_taunt_up =
  input_key_func(
  {},
  {"taunt_up"},
  normal_key,
  nil
)
player_taunt_down =
  input_key_func(
  {},
  {"taunt_down"},
  normal_key,
  nil
)
player_raise =
  input_key_func(
  {},
  {"raise1", "raise2"},
  key_is_down,
  nil
)
player_swap =
  input_key_func(
  {},
  {"swap1", "swap2"},
  normal_key,
  nil
)
player_up =
  input_key_func(
  {},
  {"up"},
  key_is_down,
  nil
)
player_down =
  input_key_func(
  {},
  {"down"},
  key_is_down,
  nil
)
player_left =
  input_key_func(
  {},
  {"left"},
  key_is_down,
  nil
)
player_right =
  input_key_func(
  {},
  {"right"},
  key_is_down,
  nil
)

select_being_pressed_ratio = get_being_pressed_for_duration_ratio({"return", "kenter", "z"}, {"swap1"}, super_selection_duration)

return input
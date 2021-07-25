require("util")

local jpexists, jpname, jrname
for k,v in pairs(love.handlers) do
  if k=="jp" then
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
  __old_jp_handler(a,b)
  love.keypressed("j"..a:getID()..b)
end
love.handlers[jrname] = function(a,b)
  __old_jr_handler(a,b)
  love.keyreleased("j"..a:getID()..b)
end

local prev_ax = {}
local axis_to_button = function(idx, value)
  local prev = prev_ax[idx] or 0
  prev_ax[idx] = value
  if value <= .5 and not (prev <= .5) then
    love.keyreleased("ja"..idx.."+")
  end
  if value >= -.5 and not (prev >= -.5) then
    love.keyreleased("ja"..idx.."-")
  end
  if value > .5 and not (prev > .5) then
    love.keypressed("ja"..idx.."+")
  end
  if value < -.5 and not (prev < -.5) then
    love.keypressed("ja"..idx.."-")
  end
end

local prev_hat = {{},{}}
local hat_to_button = function(idx, value)
  if string.len(value) == 1 then
    if value == "l" or value == "r" then
      value = value .. "c"
    else
      value = "c" .. value
    end
  end
  value = procat(value)
  for i=1,2 do
    local prev = prev_hat[i][idx] or "c"
    if value[i] ~= prev and value[i] ~= "c" then
      love.keypressed("jh"..idx..value[i])
    end
    if prev ~= value[i] and prev ~= "c" then
      love.keyreleased("jh"..idx..prev)
    end
    prev_hat[i][idx] = value[i]
  end
end

function love.joystick.getHats(joystick)
  local n = joystick:getHatCount()
  local ret = {}
  for i=1,n do
    ret[i] = joystick:getHat(i)
  end
  return unpack(ret)
end

function joystick_ax()
  local joysticks = love.joystick.getJoysticks()
  for k,v in ipairs(joysticks) do
    local axes = {v:getAxes()}
    for idx,value in ipairs(axes) do
      axis_to_button(k..idx, value)
    end

    local hats = {love.joystick.getHats(v)}
    for idx,value in ipairs(hats) do
      hat_to_button(k..idx, value)
    end
  end
end

function love.keypressed(key, scancode, rep)
  if key == "return" and not rep and love.keyboard.isDown("lalt") and love.graphics.getSupported("canvas") then
    love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    return
  end
  if not rep then
    keys[key] = 0
  end
  this_frame_keys[key] = true
end

function love.textinput(text)
  this_frame_unicodes[#this_frame_unicodes+1] = text
end

function love.keyreleased(key, unicode)
  this_frame_released_keys[key] = keys[key] -- retains state in this_frame_released_keys
  keys[key] = nil
end

function key_counts()
  for key,value in pairs(keys) do
    keys[key] = value + 1
  end
end

-- Keys that have a fixed function in menus can be bound to other
-- meanings, but should continue working the same way in menus.
local menu_reserved_keys = {}

-- Changes the behavior of menu_foo functions.
-- In a menu that doesn't specifically pertain to multiple players,
-- up, down, left, right should always work.  But in a multiplayer
-- menu, those keys should definitely not move many cursors each.
local multi = false
local function multi_func(func)
  return function(...)
    multi = true
    local res = {func(...)}
    multi = false
    return unpack(res)
  end
end

local function repeating_key(key)
  local key_time = keys[key]
  return this_frame_keys[key] or (key_time and key_time > default_input_repeat_delay and key_time % 2 == 0) -- menues key repeat delay 20 frames then every 2 frames
end

local function normal_key(key) return this_frame_keys[key] end

local function released_key_before_time(key, time) 
  return this_frame_released_keys[key] and this_frame_released_keys[key] < time
end

local function released_key_after_time(key, time)  
  return this_frame_released_keys[key] and this_frame_released_keys[key] >= time
end

local function menu_key_func(fixed, configurable, query, sound, ...)
  sound = sound or nil
  local other_args = ...
  return function(k, silent)
    silent = silent or false
    local res = false
    if multi then
      for i=1,#configurable do
        res = res or query(k[configurable[i]], other_args)
      end
    else
      for i=1,#fixed do
        res = res or query(fixed[i], other_args)
      end
      for i=1,#configurable do
        local keyname = k[configurable[i]]
        res = res or query(keyname, other_args) and
            not menu_reserved_keys[keyname]
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

local function get_pressed_ratio(key,time)
  return keys[key] and keys[key]/time or (this_frame_released_keys[key] and this_frame_released_keys[key]/time or 0)
end

local function get_being_pressed_for_duration_ratio(fixed, configurable, time)
  return function(k)
    local res = 0
    if multi then
      for i=1,#configurable do
        res = math.max(get_pressed_ratio(k[configurable[i]], time),res)
      end
    else
      for i=1,#fixed do
        res = math.max(get_pressed_ratio(fixed[i], time),res)
      end
      for i=1,#configurable do
        local keyname = k[configurable[i]]
        if not menu_reserved_keys[keyname] then
          res = math.max(get_pressed_ratio(k[configurable[i]], time),res)
        end
      end
    end
    return bound(0,res,1)
  end
end

menu_reserved_keys = {"up", "down", "left", "right", "escape","x", "pageup", "pagedown", "backspace", "return","kenter","z"}
menu_up = menu_key_func({"up"}, {"up"}, repeating_key, function() return themes[config.theme].sounds.menu_move end )
menu_down = menu_key_func({"down"}, {"down"}, repeating_key, function() return themes[config.theme].sounds.menu_move end)
menu_left = menu_key_func({"left"}, {"left"}, repeating_key, function() return themes[config.theme].sounds.menu_move end)
menu_right = menu_key_func({"right"}, {"right"}, repeating_key, function() return themes[config.theme].sounds.menu_move end)
menu_escape = menu_key_func({"escape","x"}, {"swap2"}, normal_key, function() return themes[config.theme].sounds.menu_cancel end)
menu_prev_page = menu_key_func({"pageup"}, {"raise1"}, repeating_key, function() return themes[config.theme].sounds.menu_move end)
menu_next_page = menu_key_func({"pagedown"}, {"raise2"}, repeating_key, function() return themes[config.theme].sounds.menu_move end)
menu_backspace = menu_key_func({"backspace"}, {"backspace"}, repeating_key)
menu_long_enter = menu_key_func({"return","kenter","z"}, {"swap1"}, released_key_after_time, function() return themes[config.theme].sounds.menu_validate end, super_selection_duration)
menu_enter = menu_key_func({"return","kenter","z"}, {"swap1"}, released_key_before_time, function() return themes[config.theme].sounds.menu_validate end, super_selection_duration)
menu_enter_one_press = menu_key_func({"return","kenter","z"}, {"swap1"}, normal_key, function() return themes[config.theme].sounds.menu_validate end, super_selection_duration)
menu_pressing_enter = get_being_pressed_for_duration_ratio({"return","kenter","z"}, {"swap1"}, super_selection_duration)

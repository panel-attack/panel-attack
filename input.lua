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
  return this_frame_keys[key] or
    (key_time and key_time > 25 and key_time % 3 ~= 0)
end

local function normal_key(key) return this_frame_keys[key] end

local function menu_key_func(fixed, configurable, rept, sound)
  sound = sound or nil
  local query = normal_key
  if rept then
    query = repeating_key
  end
  for i=1,#fixed do
    menu_reserved_keys[#menu_reserved_keys+1] = fixed[i]
  end
  return function(k)
    local res = false
    if multi then
      for i=1,#configurable do
        res = res or query(k[configurable[i]])
      end
    else
      for i=1,#fixed do
        res = res or query(fixed[i])
      end
      for i=1,#configurable do
        local keyname = k[configurable[i]]
        res = res or query(keyname) and
            not menu_reserved_keys[keyname]
      end
    end
    if res and sound ~= nil then
      play_optional_sfx(sound())
    end
    return res
  end
end

menu_up = menu_key_func({"up"}, {"up"}, true, function() return themes[config.theme].sounds.menu_move end )
menu_down = menu_key_func({"down"}, {"down"}, true, function() return themes[config.theme].sounds.menu_move end)
menu_left = menu_key_func({"left"}, {"left"}, true, function() return themes[config.theme].sounds.menu_move end)
menu_right = menu_key_func({"right"}, {"right"}, true, function() return themes[config.theme].sounds.menu_move end)
menu_super_select = menu_key_func({"y","u"}, {"taunt_up","taunt_down"}, false, function() return themes[config.theme].sounds.menu_validate end)
menu_enter = menu_key_func({"return","kenter","z"}, {"swap1"}, false, function() return themes[config.theme].sounds.menu_validate end)
menu_escape = menu_key_func({"escape","x"}, {"swap2"}, false, function() return themes[config.theme].sounds.menu_cancel end)
menu_prev_page = menu_key_func({"pageup"}, {"raise1"}, true, function() return themes[config.theme].sounds.menu_move end)
menu_next_page = menu_key_func({"pagedown"}, {"raise2"}, true, function() return themes[config.theme].sounds.menu_move end)
menu_backspace = menu_key_func({"backspace"}, {"backspace"}, true)
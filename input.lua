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
love.handlers[jpname] = function(a, b, c)
  __old_jp_handler(a,b,c)
  love.keypressed("j"..a..b)
end
love.handlers[jrname] = function(a,b,c)
  __old_jr_handler(a,b,c)
  love.keyreleased("j"..a..b)
end

local prev_ax = {}
local axis_to_button = function(idx, value)
  local prev = prev_ax[idx] or 0
  if value > .5 then
    if prev < .5 then
      love.keypressed("ja"..idx.."+")
    end
  elseif value < -.5 then
    if prev > -.5 then
      love.keypressed("ja"..idx.."-")
    end
  else
    if prev > .5 then
      love.keyreleased("ja"..idx.."+")
    elseif prev < -.5 then
      love.keyreleased("ja"..idx.."-")
    end
  end
  prev_ax[idx] = value
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

function love.joystick.getHats(which)
  local n = love.joystick.getNumHats(which)
  local ret = {}
  for i=0,n-1 do
    ret[i+1] = love.joystick.getHat(which, i)
  end
  return unpack(ret)
end

function joystick_ax()
  for i=0,love.joystick.getNumJoysticks()-1 do
    local axes = {love.joystick.getAxes(i)}
    for idx,value in ipairs(axes) do
      axis_to_button(i..idx, value)
    end

    local hats = {love.joystick.getHats(i)}
    for idx,value in ipairs(hats) do
      hat_to_button(i..idx, value)
    end
  end
end

function love.keypressed(key, unicode)
  keys[key] = 0
  this_frame_keys[key] = true
  if unicode >= 32 and unicode < 126 then
    this_frame_unicodes[#this_frame_unicodes+1] = string.char(unicode)
  end
end

function love.keyreleased(key, unicode)
  keys[key] = nil
end

function key_counts()
  for key,value in pairs(keys) do
    keys[key] = value + 1
  end
end

function Stack.controls(self)
  local new_dir = nil
  local sdata = self.input_state
  local raise, swap, up, down, left, right = unpack(base64decode[sdata])
  if (raise) and (not self.prevent_manual_raise) then
    self.manual_raise = true
    self.manual_raise_yet = false
  end

  self.swap_1 = swap
  self.swap_2 = swap

  if up then
    new_dir = "up"
  elseif down then
    new_dir = "down"
  elseif left then
    new_dir = "left"
  elseif right then
    new_dir = "right"
  end

  if new_dir == self.cur_dir then
    if self.cur_timer ~= self.cur_wait_time then
      self.cur_timer = self.cur_timer + 1
    end
  else
    self.cur_dir = new_dir
    self.cur_timer = 0
  end
end

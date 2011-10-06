local __old_jp_handler = love.handlers.jp
local __old_jr_handler = love.handlers.jr
function love.handlers.jp(a, b, c)
  __old_jp_handler(a,b,c)
  love.keypressed("j"..a..b)
end
function love.handlers.jr(a,b,c)
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

function joystick_ax()
  for i=0,love.joystick.getNumJoysticks()-1 do
    local axes = {love.joystick.getAxes(i)}
    for idx,value in ipairs(axes) do
      axis_to_button(i..idx, value)
    end
  end
end

function love.keypressed(key, unicode)
  keys[key] = 0
  this_frame_keys[key] = true
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

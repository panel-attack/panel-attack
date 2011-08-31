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

function controls(stack)
  local new_dir = nil
  if (keys[k_raise1] or keys[k_raise2] or this_frame_keys[k_raise1] or
      this_frame_keys[k_raise2]) and (not stack.prevent_manual_raise) then
    stack.manual_raise = true
    stack.manual_raise_yet = false
  end

  stack.swap_1 = this_frame_keys[k_swap1]
  stack.swap_2 = this_frame_keys[k_swap2]

  if keys[k_up] or this_frame_keys[k_up] then
    new_dir = "up"
  elseif keys[k_down] or this_frame_keys[k_down] then
    new_dir = "down"
  elseif keys[k_left] or this_frame_keys[k_left] then
    new_dir = "left"
  elseif keys[k_right] or this_frame_keys[k_right] then
    new_dir = "right"
  end

  if new_dir == stack.cur_dir then
    if stack.cur_timer ~= stack.cur_wait_time then
      stack.cur_timer = stack.cur_timer + 1
    end
  else
    stack.cur_dir = new_dir
    stack.cur_timer = 0
  end
end

function fake_controls(stack, sdata)
  local new_dir = nil
  local raise, swap, up, down, left, right = unpack(base64decode[sdata])
  if (raise) and (not stack.prevent_manual_raise) then
    stack.manual_raise = true
    stack.manual_raise_yet = false
  end

  stack.swap_1 = swap
  stack.swap_2 = swap

  if up then
    new_dir = "up"
  elseif down then
    new_dir = "down"
  elseif left then
    new_dir = "left"
  elseif right then
    new_dir = "right"
  end

  if new_dir == stack.cur_dir then
    if stack.cur_timer ~= stack.cur_wait_time then
      stack.cur_timer = stack.cur_timer + 1
    end
  else
    stack.cur_dir = new_dir
    stack.cur_timer = 0
  end
end

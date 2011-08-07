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
      love.keypressed("ja"..idx.."1")
    end
  elseif value < -.5 then
    if prev > -.5 then
      love.keypressed("ja"..idx.."0")
    end
  else
    if prev > .5 then
      love.keyreleased("ja"..idx.."1")
    elseif prev < -.5 then
      love.keyreleased("ja"..idx.."0")
    end
  end
  prev_ax[idx] = prev
end

function joystick_ax()
  if love.joystick.getNumJoysticks() < 1 then
    return
  end
  local axes = {love.joystick.getAxes(0)}
  for idx,value in ipairs(axes) do
    axis_to_button(idx, value)
  end
end

function love.keypressed(key, unicode)
  keys[key] = true
  this_frame_keys[key] = true
end

function love.keyreleased(key, unicode)
  keys[key] = false
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
  local data = {}
  for i=1,16 do
    data[i] = string.sub(sdata,i,i) ~= "0"
  end
  local new_dir = nil
  if (data[7] or data[8] or data[15] or data[16]) and (not stack.prevent_manual_raise) then
    stack.manual_raise = true
    stack.manual_raise_yet = false
  end

  stack.swap_1 = data[13]
  stack.swap_2 = data[14]

  if data[1] or data[9] then
    new_dir = "up"
  elseif data[2] or data[10] then
    new_dir = "down"
  elseif data[3] or data[11] then
    new_dir = "left"
  elseif data[4] or data[12] then
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

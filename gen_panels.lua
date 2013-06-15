require("util")
local random = math.random

-- stuff should have first_seven, metal, vs_mode, metal_col, prev_metal_col
function make_panels(ncolors, prev_panels, stuff)
  local ret = prev_panels
  local rows_to_make = 20
  if ncolors < 2 then return end
  local cut_panels = false

  if prev_panels == "000000" then
    if stuff.first_seven then
      ret = stuff.first_seven
      rows_to_make = rows_to_make - 7
    else
      cut_panels = true
    end
  end

  for x=0,rows_to_make-1 do
    if stuff.metal then
      local nogood = true
      while nogood do
        stuff.metal_col = random(0,5)
        nogood = stuff.metal_col == stuff.prev_metal_col
      end
    end
    for y=0,5 do
      local prevtwo = y>1 and string.sub(ret,-1,-1) == string.sub(ret,-2,-2)
      local nogood,color = true
      while nogood do
        color = (y==stuff.metal_col) and 8 or tostring(math.random(1,ncolors))
        nogood = (prevtwo and color == string.sub(ret,-1,-1)) or
          color == string.sub(ret,-6,-6)
      end
      ret = ret..color
    end
    stuff.prev_metal_col = stuff.metal_col
    stuff.metal_col = nil
    stuff.rows_left = stuff.rows_left - 1
    if stuff.rows_left == 0 then
      if stuff.vs_mode then
        stuff.metal = not stuff.metal
      end
      if stuff.metal then
        stuff.rows_left = random(3,4)
      else
        stuff.rows_left = random(7,10)
      end
    end
  end
  if cut_panels then
    ret = procat(ret)
    local height = {7,7,7,7,7,7}
    local to_remove = 12
    while to_remove > 0 do
      idx = random(1,6)
      if height[idx] > 0 then
        ret[idx+6*(-height[idx]+8)] = "0"
        height[idx] = height[idx] - 1
        to_remove = to_remove - 1
      end
    end
    ret = table.concat(ret)
    stuff.first_seven = string.sub(ret,1,48)
  end
  return string.sub(ret,7,-1)
end

function make_gpanels(ncolors, prev_panels)
  local ret = prev_panels
  for x=0,19 do
    for y=0,5 do
      local nogood,color = true
      while nogood do
        color = tostring(math.random(1,ncolors))
        nogood = (y>0 and color == string.sub(ret,-1,-1)) or
          color == string.sub(ret,-6,-6)
      end
      ret = ret..color
    end
  end
  return string.sub(ret,7,-1)
end

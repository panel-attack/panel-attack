require("util")
require("server_globals")
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
  end
  print("panels before potential metal panel position assignments:")
  print(ret)
    --assign potential metal panel placements
  local row_width = 6 --this may belong in globals if we were to ever make a game mode with a different width
  local new_ret = "000000"
  local prev_row
  for i=2,rows_to_make+1 do
    prev_row = string.sub(new_ret,0-row_width,-1)
    local first, second --locations of potential metal panels
    --while panel vertically adjacent is not numeric, so can be a metal panel 
    while not first or not tonumber(string.sub(prev_row, first, first)) do 
      first = math.random(1,row_width)
    end
    while not second or second==first or not tonumber(string.sub(prev_row, second, second)) do 
      second = math.random(1,row_width)
    end
    local new_row = ""
    for j=1, row_width do
      num_from_ret = tonumber(string.sub(ret,(i-1)*row_width+j, (i-1)*row_width+j)) or 0
      if j==first then
        print(num_from_ret)
        new_row = new_row..(panel_color_number_to_upper[num_from_ret] or "0")
      elseif j==second then
        new_row = new_row..(panel_color_number_to_lower[num_from_ret] or "0")
      else
        new_row = new_row..num_from_ret
      end
    end
    new_ret = new_ret..new_row
  end
  ret = new_ret
  print("panels after potential metal panel position assignments:")
  print(ret)
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

local sort, pairs, select, unpack, error = table.sort, pairs, select, unpack, error
local type, setmetatable, getmetatable = type, setmetatable, getmetatable
local random = math.random

-- returns the number of entries in a table
function tableLength(T)
  local count = 0
  for _ in pairs(T) do
    count = count + 1
  end
  return count
end

-- bounds b so a<=b<=c
function bound(a, b, c)
  if b < a then
    return a
  elseif b > c then
    return c
  else
    return b
  end
end

-- returns the percentage of value between min and max
function linear_smooth(value, min, max)
  return (value - min) / (max - min)
end

-- mods b so a<=b<=c
function wrap(a, b, c)
  return (b - a) % (c - a + 1) + a
end

-- map for numeric tables
function map(func, tab)
  local ret = {}
  for i = 1, #tab do
    ret[i] = func(tab[i])
  end
  return ret
end

-- map for dicts
function map_dict(func, tab)
  local ret = {}
  for key, val in pairs(tab) do
    ret[key] = func(val)
  end
  return ret
end

-- applies the function to each item in tab and replaces
function map_inplace(func, tab)
  for i = 1, #tab do
    tab[i] = func(tab[i])
  end
  return tab
end

-- applies the function to each item in tab and replaces
function map_dict_inplace(func, tab)
  for key, val in pairs(tab) do
    tab[key] = func(val)
  end
  return tab
end

-- reduce for numeric tables
function reduce(func, tab, ...)
  local idx, value = 2, nil
  if select("#", ...) ~= 0 then
    value = select(1, ...)
    idx = 1
  elseif #tab == 0 then
    error("Tried to reduce empty table with no initial value")
  else
    value = tab[1]
  end
  for i = idx, #tab do
    value = func(value, tab[i])
  end
  return value
end

-- TODO delete
function car(tab)
  return tab[1]
end

-- This sucks lol
-- TODO delete
function cdr(tab)
  return {select(2, unpack(tab))}
end

-- a useful right inverse of table.concat
function procat(str)
  local ret = {}
  for i = 1, #str do
    ret[i] = str:sub(i, i)
  end
  return ret
end

-- iterate over frozen pairs in sorted order
function spairs(tab)
  local keys, vals, idx = {}, {}, 0
  for k in pairs(tab) do
    keys[#keys + 1] = k
  end
  sort(keys)
  for i = 1, #keys do
    vals[i] = tab[keys[i]]
  end
  return function()
    idx = idx + 1
    return keys[idx], vals[idx]
  end
end

-- Randomly grabs a value from t
function uniformly(t)
  return t[random(#t)]
end

-- Returns true if a and b have equal content
function content_equal(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return a == b
  end
  for i = 1, 2 do
    for k, v in pairs(a) do
      if b[k] ~= v then
        return false
      end
    end
    a, b = b, a
  end
  return true
end

-- does not perform deep comparisons of keys which are tables.
function deep_content_equal(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return a == b
  end
  for i = 1, 2 do
    for k, v in pairs(a) do
      if not deep_content_equal(v, b[k]) then
        return false
      end
    end
    a, b = b, a
  end
  return true
end

-- copy the table one key deep
function shallowcpy(tab)
  local ret = {}
  for k, v in pairs(tab) do
    ret[k] = v
  end
  return ret
end

local deepcpy_mapping = {}
local real_deepcpy
function real_deepcpy(tab)
  if deepcpy_mapping[tab] ~= nil then
    return deepcpy_mapping[tab]
  end
  local ret = {}
  deepcpy_mapping[tab] = ret
  deepcpy_mapping[ret] = ret
  for k, v in pairs(tab) do
    if type(k) == "table" then
      k = real_deepcpy(k)
    end
    if type(v) == "table" then
      v = real_deepcpy(v)
    end
    ret[k] = v
  end
  return setmetatable(ret, getmetatable(tab))
end

-- copys the full variable deeply
function deepcpy(tab)
  if type(tab) ~= "table" then
    return tab
  end
  local ret = real_deepcpy(tab)
  deepcpy_mapping = {}
  return ret
end

--Note: this round() doesn't work with negative numbers
function round(positive_decimal_number, number_of_decimal_places)
  if not number_of_decimal_places then
    number_of_decimal_places = 0
  end
  return math.floor(positive_decimal_number * 10 ^ number_of_decimal_places + 0.5) / 10 ^ number_of_decimal_places
end

-- Returns a time string for the number of frames
function frames_to_time_string(frame_count, include_60ths_of_secs)
  local hour_min_sep = ":"
  local min_sec_sep = ":"
  local sec_60th_sep = "'"
  local ret = ""
  if frame_count >= 216000 then
    --enough to include hours
    ret = ret .. math.floor(frame_count / 216000)
    --minutes with 2 digits (like 05 instead of 5)
    ret = ret .. hour_min_sep .. string.format("%02d", math.floor(frame_count / 3600 % 3600))
  else
    --minutes with only one digit if only one digit if needed
    ret = ret .. math.floor(frame_count / 3600 % 3600)
  end
  --seconds
  ret = ret .. min_sec_sep .. string.format("%02d", math.floor(frame_count / 60 % 60))
  if include_60ths_of_secs then
    --also include 60ths of a second
    ret = ret .. sec_60th_sep .. string.format("%02d", frame_count % 60)
  end
  return ret
end

-- Not actually for encoding/decoding byte streams as base64.
-- Rather, it's for encoding streams of 6-bit symbols in printable characters.
base64encode = procat("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890+/")
base64decode = {}
for i = 1, 64 do
  local val = i - 1
  base64decode[base64encode[i]] = {}
  local bit = 32
  for j = 1, 6 do
    base64decode[base64encode[i]][j] = (val >= bit)
    val = val % bit
    bit = bit / 2
  end
end

-- split the input string on some separator, returns table
function split(inputstr, sep)
  sep = sep or "%s"
  local t = {}
  for field, s in string.gmatch(inputstr, "([^" .. sep .. "]*)(" .. sep .. "?)") do
    table.insert(t, field)
    if s == "" then
      return t
    end
  end
end

-- Remove white space from the ends of a string
function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Gets all the contents of a directory
function get_directory_contents(path)
  local path = (path and path or "")
  local results = love.filesystem.getDirectoryItems(path)
  return results
end

function compress_input_string(inputs)
  -- Check for a digit enclosed in parentheses in the inputs to ensure the inputs aren't already compressed.
  if not inputs:match("%(%d+%)") or inputs:match("[%a%+%/][%a%+%/]") then
    local compressed_inputs = "" -- Actual compressed input string
    local buff = inputs:sub(1, 1) -- Current section inputs to compress
    local prev_char, next_char = inputs:sub(1, 1)
    -- We start at the second input because there is nothing to compare the first input to
    for pos = 2, #inputs do
      -- Assign the next input
      next_char = inputs:sub(pos, pos)
      -- Check if the input is different from the previous one
      if next_char ~= prev_char then
        if buff:match("%d+") then
          -- Found one or more digit to enclose in parentheses, to show they are actual inputs
          compressed_inputs = compressed_inputs .. "(" .. buff .. ")"
        else
          -- Add a single char, preceded by a digit representing the amount of that char
          compressed_inputs = compressed_inputs .. buff:sub(1, 1) .. #buff
        end
        -- Since the next char is not the same as the previous, clear the buffer
        buff = ""
      end
      -- Add the char to the buffer
      buff = buff .. next_char
      -- Set the next char as the previous char (the next assignment will be updating the next char)
      prev_char = next_char
    end
    if buff:match("%d+") then
      compressed_inputs = compressed_inputs .. "(" .. buff .. ")"
    else
      compressed_inputs = compressed_inputs .. buff:sub(1, 1) .. #buff
    end
    -- If there are parentheses that close and open immediately after, get rid of them.
    compressed_inputs = compressed_inputs:gsub("%)%(", "")
    -- Confirm that the compressed version is smaller than the initial size
    if #compressed_inputs < #inputs then
      return compressed_inputs
    end
  end
  return inputs
end

function uncompress_input_string(inputs)
  -- If there are two consecutive letters or symbols in the inputs, do nothing, as inputs are not compressed.
  if not inputs:match("[%a%+%/][%a%+%/]") then
    local uncompressed_inputs = "" -- Actual uncompressed inputs
    --[[For every base64encode char that is followed by at least one digit,
    with an optional left parenthesis immediately after the aforementioned digit,
    followed by any amount of digits (including zero digits whatsoever),
    with an optional right parenthesis afterwards]]
    for w in inputs:gmatch("[%a%+%/]%d+%(?%d*%)?") do
      -- repeat the char the amount of times that the digit afterwards indicates
      uncompressed_inputs = uncompressed_inputs .. string.rep(w:sub(1, 1), w:match("%d+"))
      local input_value = w:match("%(%d+%)") -- Assign digits enclosed in parentheses, if any
      if input_value then
        -- If there are digits in parentheses, add them to the string without the parentheses
        uncompressed_inputs = uncompressed_inputs .. input_value:match("%d+")
      end
    end
    return uncompressed_inputs
  end
  return inputs
end

function dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then
        k = '"' .. k .. '"'
      end
      s = s .. "[" .. k .. "] = " .. dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

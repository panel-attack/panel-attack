local sort, pairs = table.sort, pairs
local type, setmetatable, getmetatable = type, setmetatable, getmetatable

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

-- a useful right inverse of table.concat
function procat(str)
  local ret = {}
  for i = 1, #str do
    ret[i] = str:sub(i, i)
  end
  return ret
end

-- iterate over a dictionary sorted by keys

-- this is a dedicated method to use for dictionaries for technical reasons
function pairsSortedByKeys(tab)
  -- these are already sorted
  local keys = table.getKeys(tab)
  local vals = {}
  -- and then assign the values with the corresponding indexes
  for i = 1, #keys do
    vals[i] = tab[keys[i]]
  end

  local idx = 0
  -- the key and value table are kept separately instead of being rearranged into a "sorted dictionary"
  -- this is because pairs always returns them in an arbitrary order even after they have been sorted in advance
  return function()
    idx = idx + 1
    return keys[idx], vals[idx]
  end
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
function frames_to_time_string(frame_count, include_milliseconds)
  local min_sec_sep = ":"
  local sec_60th_sep = "'"
  local ret = ""

  --minutes with only one digit if only one digit if needed
  ret = ret .. math.floor(frame_count / 3600 % 3600)

  --seconds
  ret = ret .. min_sec_sep .. string.format("%02d", math.floor(frame_count / 60 % 60))
  
  if include_milliseconds then
    --also include milliseconds
    ret = ret .. sec_60th_sep .. string.format("%03d", ((1000 / 60) * (frame_count % 60)))
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
  if inputs:match("%(%d+%)") or not inputs:match("[%a%+%/][%a%+%/]") then
    -- Detected a digit enclosed in parentheses in the inputs, the inputs are already compressed.
    return inputs
  else
    local compressed_inputs = ""
    local buff = inputs:sub(1, 1)
    local out_str, next_char = inputs:sub(1, 1)
    for pos = 2, #inputs do
      next_char = inputs:sub(pos, pos)
      if next_char ~= out_str:sub(#out_str, #out_str) then
        if buff:match("%d+") then
          compressed_inputs = compressed_inputs .. "(" .. buff .. ")"
        else
          compressed_inputs = compressed_inputs .. buff:sub(1, 1) .. buff:len()
        end
        buff = ""
      end
      buff = buff .. inputs:sub(pos, pos)
      out_str = out_str .. next_char
    end
    if buff:match("%d+") then
      compressed_inputs = compressed_inputs .. "(" .. buff .. ")"
    else
      compressed_inputs = compressed_inputs .. buff:sub(1, 1) .. buff:len()
    end
    compressed_inputs = compressed_inputs:gsub("%)%(", "")
    return compressed_inputs
  end
end

function uncompress_input_string(inputs)
  if inputs:match("[%a%+%/][%a%+%/]") then
    -- Detected two consecutive letters or symbols in the inputs, the inputs are not compressed.
    return inputs
  else
    local uncompressed_inputs = ""
    for w in inputs:gmatch("[%a%+%/]%d+%(?%d*%)?") do
      uncompressed_inputs = uncompressed_inputs .. string.rep(w:sub(1, 1), w:match("%d+"))
      input_value = w:match("%(%d+%)")
      if input_value then
        uncompressed_inputs = uncompressed_inputs .. input_value:match("%d+")
      end
    end
    return uncompressed_inputs
  end
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

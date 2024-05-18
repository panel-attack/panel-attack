local tableUtils = require("common.lib.tableUtils")
local pairs, type, setmetatable, getmetatable = pairs, type, setmetatable, getmetatable

local util = {}

-- bounds b so a<=b<=c
function util.bound(a, b, c)
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
  local keys = tableUtils.getKeys(tab)
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
  else
    if a == b then
      -- two tables can still be the same by reference which also makes them === exactly equal
      return true
    else
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
  end
end

-- copy the table one key deep
function shallowcpy(tab)
  assert(tab ~= nil)
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

function table_to_string(tab)
  local ret = ""
  for k,v in pairs(tab) do
    if type(v) == "table" then
      ret = ret..k.." table:\n"..table_to_string(v).."\n"
    else
      local keyString = k
      if type(k) == "function" then
        keyString = "Function"
      end
      ret = ret .. keyString .. " " .. tostring(v) .. "\n"
    end
  end
  return ret
end

-- DEPRECATED, use non global math.round
function round(positive_decimal_number, number_of_decimal_places)
  return math.round(positive_decimal_number, number_of_decimal_places)
end

-- Returns a time string for the number of frames
function frames_to_time_string(frame_count, include_centiseconds)
  local min_sec_sep = ":"
  local sec_60th_sep = "'"
  local ret = ""

  --minutes with only one digit if only one digit is needed
  ret = ret .. math.floor(frame_count / 3600 % 3600)

  --seconds
  ret = ret .. min_sec_sep .. string.format("%02d", math.floor(frame_count / 60 % 60))
  
  if include_centiseconds then
    --also include milliseconds
    ret = ret .. sec_60th_sep .. string.format("%02d", ((100 / 60) * (frame_count % 60)))
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
function util.split(inputstr, sep)
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

function dump(o, includeNewLines)
  includeNewLines = includeNewLines or false
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then
        k = '"' .. k .. '"'
      end
      s = s .. "[" .. k .. "] = " .. dump(v) .. ","
      if includeNewLines then
        s = s .. "\n"
      end
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

local metaTableForWeakKeys = { __mode = "k"}
local metaTableForWeakValues = { __mode = "v"}
local metaTableForWeakKeysAndValues = { __mode = "kv" }
-- a table having weak keys means 
--  that references to a table in the key portion of that table are ignored for the purpose of garbage collection
--  that these tables will get collected if the reference in the key portion of the table is the only remaining reference
--  that the key value pair this key belongs to will automatically get removed from its table
-- this is mostly useful to prevent memory leaks and keeping references to objects that are technically dead
function util.getWeaklyKeyedTable()
  local t = {}
  setmetatable(t, metaTableForWeakKeys)
  return t
end

function util.getWeaklyValuedTable()
  local t = {}
  setmetatable(t, metaTableForWeakValues)
  return t
end

function util.getWeakTable()
  local t = {}
  setmetatable(t, metaTableForWeakKeysAndValues)
  return t
end

-- Returns if two floats are equal within a certain number of decimal places
-- @param decimalPrecision the number of decimal places to compare
function math.floatsEqualWithPrecision(a, b, decimalPrecision)
  assert(type(a) == "number", "floatsEqualWithPrecision expects a number argument for the first argument")
  assert(type(b) == "number", "floatsEqualWithPrecision expects a number argument for the second argument")
  assert(type(decimalPrecision) == "number", "floatsEqualWithPrecision expects a number argument for the third argument")

  local threshold = math.pow(0.1, decimalPrecision)
  local diff = math.abs(a - b) -- Absolute value of difference
  return diff < threshold
end

function assertEqual(a, b)
  assert(a == b, "Expected " .. a .. " to be equal to " .. b)
end

-- adds a path to lua's CPath for loading C libraries
-- the ?? placeholder will get resolved to ?.so or ?.dll depending on what the first entry in the cPath uses
function util.addToCPath(path)
  assert(path:sub(1, 1) == ".", "extra CPaths should always be defined relative to the main directory")
  -- why do we need to add things to the cpath?
  -- c libraries for lua define an entry point function that is typically called
  --  luaopen_libName
  -- when requiring a file via a path such as require("pathA.pathB.libName") this translates to lua trying to open the library with
  --  luaopen_pathA_pathB_libName
  -- which is not the entry point function
  -- by calling util.addToCPath("pathA/pathB/??") the path is searched directly
  -- this means we can require the lib just via require("libName")
  -- due to it being in the cpath it will get found while the entry point function is invoked as luaopen_libName
  -- note that libraries don't have to adhere to that pattern and can also demand to be placed in subdirectory
  -- Example: luasocket's dynamic core library's entry point is
  --  luaopen_socket_core
  -- meaning it has to be required as "socket.core", otherwise it cannot be opened
  local cPathDirs = util.split(package.cpath, ";")
  local fileExtension = string.sub(cPathDirs[1], -4)
  if fileExtension == "?.so" then
    path = path:gsub("%?%?", "?.so")
  else
    path = path:gsub("%?%?", "?.dll")
  end
  if not tableUtils.contains(cPathDirs, path) then
    package.cpath = package.cpath .. ";" .. path
  end
end

return util
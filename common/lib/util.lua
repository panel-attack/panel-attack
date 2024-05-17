local tableUtils = require("common.lib.tableUtils")
local utf8 = require("common.lib.utf8Additions")
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

function math.sign(v)
	return (v >= 0 and 1) or -1
end

function math.round(number, numberOfDecimalPlaces)
  if number == 0 then
    return number
  end
  local multiplier = 10^(numberOfDecimalPlaces or 0)
  if number > 0 then
    return math.floor(number * multiplier + 0.5) / multiplier
  else 
    return math.ceil(number * multiplier - 0.5) / multiplier 
  end
end

function math.integerAwayFromZero(number)
  if number == 0 then
    return number
  end
  if number > 0 then
    return math.ceil(number)
  else 
    return math.floor(number)
  end
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

-- Returns if the unicode codepoint (representative number) is either the left or right parenthesis
local function codePointIsParenthesis(codePoint)
  if codePoint >= 40 and codePoint <= 41 then
    return true
  end
  return false
end

-- Returns if the unicode codepoint (representative number) is a digit from 0-9
local function codePointIsDigit(codePoint)
  if codePoint >= 48 and codePoint <= 57 then
    return true
  end
  return false
end

function compress_input_string(inputs)
  assert(inputs ~= nil, "string must be provided for compression")
  assert(type(inputs) == "string", "input to be compressed must be a string")
  if string.len(inputs) == 0 then
    return inputs
  end
  
  local compressedTable = {}
  local function addToTable(codePoint, repeatCount)
    local currentInput = utf8.char(codePoint)
    -- write the input
    if tonumber(currentInput) == nil then
      compressedTable[#compressedTable+1] = currentInput .. repeatCount
    else
      local completeInput = "(" .. currentInput
      for j = 2, repeatCount do
        completeInput = completeInput .. currentInput
      end
      compressedTable[#compressedTable+1] = completeInput .. ")"
    end
  end

  local previousCodePoint = nil
  local repeatCount = 1
  for p, codePoint in utf8.codes(inputs) do
    if codePointIsDigit(codePoint) and codePointIsParenthesis(previousCodePoint) == true then
      -- Detected a digit enclosed in parentheses in the inputs, the inputs are already compressed.
      return inputs
    end
    if p > 1 then
      if previousCodePoint ~= codePoint then
        addToTable(previousCodePoint, repeatCount)
        repeatCount = 1
      else
        repeatCount = repeatCount + 1
      end
    end
    previousCodePoint = codePoint
  end
  -- add the final entry without having to check for table length in every iteration
  addToTable(previousCodePoint, repeatCount)

  return table.concat(compressedTable)
end

function uncompress_input_string(inputs)

  local previousCodePoint = nil
  local inputChunks = {}
  local numberString = nil
  local characterCodePoint = nil
  -- Go through the characters one by one, saving character and then the number sequence and after passing it writing out that many characters
  for p, codePoint in utf8.codes(inputs) do
    if p > 1 then
      if codePointIsDigit(codePoint) then 
        local number = utf8.char(codePoint)
        if numberString == nil then
          characterCodePoint = previousCodePoint
          numberString = ""
        end
        numberString = numberString .. number
      else
        if numberString ~= nil then
          if codePointIsParenthesis(characterCodePoint) then
            inputChunks[#inputChunks+1] = numberString
          else
            local character = utf8.char(characterCodePoint)
            local repeatCount = tonumber(numberString)
            inputChunks[#inputChunks+1] = string.rep(character, repeatCount)
          end
          numberString = nil
        end
        if previousCodePoint == codePoint then
          -- Detected two consecutive letters or symbols in the inputs, the inputs are not compressed.
          return inputs
        else
          -- Nothing to do yet
        end
      end
    end
    previousCodePoint = codePoint
  end

  local result
  if numberString ~= nil then
    local character = utf8.char(characterCodePoint)
    local repeatCount = tonumber(numberString)
    inputChunks[#inputChunks+1] = string.rep(character, repeatCount)
    result = table.concat(inputChunks)
  else
    -- We never encountered a single number, this string wasn't compressed
    result = inputs
  end
  return result
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

function json.isValid(str)
  local content = trim(str)
  local length = utf8.len(content)
  local firstChar = utf8.sub(content, 1, 1)
  local lastChar = utf8.sub(content, length, length)
  -- early quit condition for clearly non-matching files
  if not tableUtils.contains({"{", "["}, firstChar) or not tableUtils.contains({"}", "]"}, lastChar) then
    return false
  end

  -- for every { there needs to be a }
  -- for every [ there needs to be a ]
  -- for every : there needs to be either , or a new line (cause we use a fake/old json spec that is somewhat akin to YAML)
  -- all of these 3 character typs need to respect sequence
  -- {{[:,:,[]:,]}} 
  -- track the expected closure characters based on openers from front to back:
  -- }}],],,

  -- any content inside "" is excluded from search
  content = string.gsub(content, "\".-\"", "")

  -- any comments are excluded from search
  content = string.gsub(content, "/%*.-%*/", "")
  content = string.gsub(content, "//.-\n", "")

  -- any other content aside from key characters is getting purged for better overview
  content = string.gsub(content, "[^%{%}%[%]:,\n]", "")

  -- \n and , are interchangeable but there may be more \n for formatting purposes
  -- replace all occurences of , with \n
  content = string.gsub(content, ",", "\n")

  local searchBackLog = {}
  
  for match in string.gmatch(content, ".") do
    -- for each find, put the inverse character at the end of the table
    -- search the table from end to start later (better performance compared to table.insert(table, value, 1)
    if match == "{" then
      searchBackLog[#searchBackLog+1] = "}"
    elseif match == "[" then
      searchBackLog[#searchBackLog+1] = "]"
    elseif match == ":" then
      searchBackLog[#searchBackLog+1] = "\n"
    else
      if searchBackLog[#searchBackLog] == match then
        searchBackLog[#searchBackLog] = nil
      elseif match == "\n" then
        -- could be extra whitespace, skip
      elseif searchBackLog[#searchBackLog] == "\n" then
        -- the final attribute of a level does not need to be closed with a , or new line
        searchBackLog[#searchBackLog] = nil
        -- confirm that the next expected character matches
        if searchBackLog[#searchBackLog] == match then
          searchBackLog[#searchBackLog] = nil
        else
          -- not a json if it doesn't
          return false
        end
      else
        -- mismatch
        return false
      end
    end
  end

  -- if there is still backlog remaining, it means that some stuff didn't get closed
  return #searchBackLog == 0
end

function string.toCharTable(self)
  local t = {}
  for _, codePoint in utf8.codes(self) do
    local character = utf8.char(codePoint)
    t[#t+1] = character
  end
  return t
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

return util
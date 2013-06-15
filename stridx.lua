local stringmt = getmetatable("")
local stringmt_idx = stringmt.__index
local type = type
assert(type(stringmt_idx) == "table")
stringmt.__index = function(t,k)
  if type(k) == "number" then
    local ret = t:sub(k,k)
    if #ret == 0 then
      return nil
    end
    return ret
  end
  return stringmt_idx[k]
end


function string:split(sep)
  local sep, fields = sep or " ", {}
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

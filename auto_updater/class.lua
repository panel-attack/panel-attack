function class(init)
  local c,mt = {},{}
  c.__index = c
  mt.__call = function(class_tbl, ...)
    local obj = {}
    setmetatable(obj,c)
    init(obj,...)
    return obj
  end
  setmetatable(c, mt)
  return c
end

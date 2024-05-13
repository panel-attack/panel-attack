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

--@module class
local class = function(init, parent)
  local class_tbl = {}
  local metatable = {
    __index = parent,
    __call = function(_, ...)
      local self = {}
      local index = class_tbl
      if parent then
        self = parent(...)
        index = {}
        -- must deep copy the __index table (aka the parent class itself) otherwise this will modify it
        for k, v in pairs(getmetatable(self).__index) do
          index[k] = v
        end
        for k, v in pairs(class_tbl) do
          index[k] = v
        end
      end
      setmetatable(self, { __index = index })
      init(self, ...)
      return self
    end
  }
  setmetatable(class_tbl, metatable)
  return class_tbl
end

return class
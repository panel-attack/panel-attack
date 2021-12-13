function class(init, baseClass)
  local instance,metatable = {},{}
  -- copy attributes and values of the base class
  if baseClass then   
    for k,v in pairs(baseClass) do
      print("creating attribute " .. k .. " from baseclass")
      instance[k] = v
    end
  end
  instance.__index = instance
  metatable.__call = function(class_tbl, ...)
    local obj = {}
    setmetatable(obj,instance)
    init(obj,...)
    return obj
  end
  instance.init = init
  setmetatable(instance, metatable)
  return instance
end
-- all objects are initialized the same way
-- the class we initialize with is passed with ct
local newTable = function(ct, ...)
  local new = setmetatable({}, ct)
  new:initializeObject(nil, ...)
  return new
end

local classMetaTable = {__call = newTable}

local class = function(init, parent)
  local classTable = {}
  -- class table acts as the metatable for new tables
  -- all function calls on the table should find the functions on the class table, so set __index
  classTable.__index = classTable
  -- as far as I'm aware, __call is not getting bubbled through metatables in case of inheritance
  -- so set the call metatable for every class table to make it easy for inheritance
  classTable.__call = newTable
  -- make parent functions accessible, even if they may be shadowed
  classTable.super = parent
  classTable.initializeObject = function(new, super, ...)
    if new.super then
      if not super then
        -- we want to call recursively in order
        -- if we only pass new, we'll get the same super every time
        -- so add super as the argument so it can actually bubble up the inheritance tree recursively
        new.super.initializeObject(new, new.super, ...)
      else
        -- a reference to a super class got passed in!
        -- so check if that super has its own super and initialize that first if so
        if super.super then
          super.super.initializeObject(new, super.super, ...)
        end
      end
    end

    -- the init is a closure so every part of the inheritance tree will still call its correct init
    -- after the classes above have run their init
    init(new, ...)
  end

  if parent then
    setmetatable(classTable, parent)
  else
    setmetatable(classTable, classMetaTable)
  end

  return classTable
end

return class
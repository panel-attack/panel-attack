-- more performant table for sparsely indexed list
-- every time an index gets added, it is added to a separate table `indices`
-- to measure length, just ask the field list.length
-- iteration is not supposed to happen, just index directly the value you want
-- direct index access returns the value with the same or next lower index plus the frame diff

local newIndexMetatable = function(table, key, value)
  if not table[key] then
    table.length = table.length + 1
    table.indices[#table.indices+1] = key
    rawset(table, key, value)
  end
end

-- index returns the value with the time diff for the value as a second return value
-- returns nil, -1 if no fitting value is found
local function getValueAtFrame(table, key)
  if table[key] ~= nil then
    return table[key], 0
  else
    for i = table.length, 1, -1 do
      if table.indices[i] < key then
        return table[table.indices[i]], key - table.indices[i]
      end
    end
    return nil, -1
  end
end

local function clearFromFrame(table, frame)
  for i = table.length, 1, -1 do
    if table.indices[i] > frame then
      table[table.indices[i]] = nil
      table.indices[i] = nil
      table.length = table.length - 1
    else
      return
    end
  end
end

-- more of a fake clear
-- it doesn't really matter if the values stay in the table
-- but it would cause work clearing them up or giving them up for garbage collection
-- clear is called when stacks are sufficiently close to each other again that rollback doesn't happen
-- so any new values will have higher indices anyway
-- old values will get garbage collected after the game with the owner's death
-- tl;dr, we don't wanna drop frames just because we caught up!
local function clear(table)
  table.indices = {}
  table.length = 0
end

local function lastValue(table)
  if table.length > 0 then
    return table[table.indices[table.length]]
  -- else
  --   return nil
  end
end

local function NewSparseRollbackFrameList()
  local sparselyIndexedList = { indices = {}, length = 0 }
  sparselyIndexedList.clearFromFrame = clearFromFrame
  sparselyIndexedList.clear = clear
  sparselyIndexedList.lastValue = lastValue
  sparselyIndexedList.getValueAtFrame = getValueAtFrame
  local metatable = {}
  metatable.__newindex = newIndexMetatable
  setmetatable(sparselyIndexedList, metatable)
  return sparselyIndexedList
end

return NewSparseRollbackFrameList